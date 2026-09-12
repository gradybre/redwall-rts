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
## that table, TEN are dispatched here (ARCH-SYS-008 only in part). ARCH-SYS-017 is deliberately
## NOT counted among the ten: it is not a separate call, and three earlier revisions of this
## header disagreed about whether to include it -- one said THREE while listing four, another said
## FIVE and SIX for the same milestone under different conventions, and the third ended "That is
## the sixth" after excluding 017 from a list of six, which named nothing at all. The count below
## is of DISPATCHED CALL SITES, and the list IS the count. `tick_stage_count()` publishes the EIGHT
## of them that are on the per-tick path, so the list and the code cannot drift apart silently:
##
##   ARCH-SYS-002 CommandCommit      -> `command_dispatch.commit_tick_into()` every tick, FIRST
##   ARCH-SYS-003 IntervalIntegrator -> `needs.tick_all()`         every tick, after commit
##   ARCH-SYS-004 StockAge           -> `stock_age.run_hour_into()` EVERY HOUR CROSSING, on the
##                                     tick path, and REQ-SET-007's FIRST daily leg at midnight
##   ARCH-SYS-005 Ecology            -> `ecology.run_day_into()`   MIDNIGHT ONLY, never per tick
##   ARCH-SYS-006 CropWeather        -> `crop_weather.run_hour_into()` EVERY HOUR CROSSING, on
##                                     the tick path, AND `run_day_into()` at MIDNIGHT after 005
##   ARCH-SYS-009 JobPlanner         -> `job_planner.run_tick_into()` every tick, AND
##                                     `run_day_boundary()` at MIDNIGHT after 006
##   ARCH-SYS-008 NeedIntent (PART)  -> `schedule.resolve_into()`  activity resolution only
##   ARCH-SYS-010 JobSelector        -> `jobs.evaluate()`/`assign_worker()`
##   ARCH-SYS-013 ProductiveWork     -> `work.tick_solo_into()` / `tick_party_into()`
##   ARCH-SYS-023 PresentationExtract-> `presentation.capture()`  every tick, LAST
##
## TWO OF THOSE NINE ARE OUT OF THE TABLE'S ORDER, AND BOTH ARE SAID SO RATHER THAN GLOSSED:
##
##   * ARCH-SYS-009 RUNS BEFORE ARCH-SYS-008, not after it. The table reads 008, 009, 010; this
##     node runs 009, then a FUSED 008/010 pass in which each resident's activity is resolved
##     immediately before that resident is offered a job. The fusion is what stops eligibility
##     step 2 reading a stale hour, and the two stages have NO DATA DEPENDENCY -- the planner reads
##     FarmPlot rows and HarvestZone designations, resolution reads needs and the calendar hour.
##     What the table's order is actually FOR is satisfied exactly: R06-JOB-008 requires demand to
##     be reconciled "before selection", and it is.
##   * ARCH-SYS-017 CareHealth RUNS IN ARCH-SYS-003's SLOT, WHICH IS FOURTEEN PLACES EARLY. THIS
##     IS AN ORDERING DEBT, not a naming convenience, and it is stated here in full because the
##     previous revision left it implicit. `needs.gd` integrates health, cold exposure and the
##     incapacitation/death transitions INSIDE `tick_all()`, so they are computed at position 3
##     rather than at the table's position 17. The table's own stated constraint -- "before
##     lifecycle and progression" -- still holds, because neither ARCH-SYS-019 nor ARCH-SYS-020
##     exists. WHAT IS ACTUALLY LOST is everything between the two positions: cold exposure cannot
##     see THIS tick's ARCH-SYS-016 RoomHeat result (no Room store), and injury care cannot see
##     THIS tick's ARCH-SYS-013 care work (no care request store). Both inputs are absent today,
##     so the debt is currently unobservable -- and it becomes a real one-tick lag the moment
##     either store lands. Repaying it means a separate CareHealth call, which is a change to
##     `needs.gd`, a file this task does not own.
##
## ARCH-SYS-006 IS ONE STAGE WITH TWO CADENCES, not two stages: its §5 row reads "Hourly crop
## integration; midnight after Ecology" and both halves belong to `crop_weather.gd`. The hourly
## half sits in the table's own position, after ARCH-SYS-003 and before the selectors; the daily
## half is REQ-SET-007's third leg and runs after ARCH-SYS-005's, never before it.
##
## ARCH-SYS-017 CareHealth is therefore not a tenth entry in the list above; it is run, not
## skipped, and the paragraph above states exactly what running it early does and does not cost.
##
## ARCH-SYS-002 IS FIRST BECAUSE §5 SAYS "after snapshot, before selectors", and ARCH-SYS-001
## TransformSnapshot does not exist -- there is no Transform store -- so nothing precedes it here.
## A player edit committed at the top of tick k is therefore visible to the SAME tick's selection
## and work stages, which is what "before selectors" buys.
##
## WHAT ARCH-SYS-002 NOW DOES, AND WHAT IT STILL DOES NOT. It drains `commands.gd`'s ordered
## next-tick queue and commits each drained record through `command_dispatch.gd`. In THIS node's
## composition that now reaches ALL SIX implemented kinds. Four of them -- CANCEL_JOB,
## NAME_RESIDENT, SET_ACTIVITY_SCHEDULE and SET_JOB_PRIORITIES -- always did, because this node
## composes the resident-side stores. DESIGNATE_ZONE and SET_POLICY refused COMMAND_STORE_NOT_BOUND
## until task 04.4, because they need `forage.gd` and `job_planner.gd`; `_bind_ecology_to_commands()`
## is the named handoff task 04.2 reserved for it and it runs during composition, so a player's
## zone and policy edits now reach real stores in the running game. The remaining eighteen
## ARCH-CMD-003 kinds refuse COMMAND_UNSUPPORTED_FEATURE and name their missing owner.
##
## ONE PLAYER COMMAND CANNOT PRODUCE TWO DESIGNATIONS. `command_dispatch.gd` records
## ARCH-CMD-001's `(player_id, sequence_high, sequence_low)` on the zone each DESIGNATE_ZONE
## creates and refuses COMMAND_DUPLICATE_INTENT for a repeat of the same identity. That guard is
## in the dispatcher rather than here, and its header records the measurement that motivated it.
##
## ARCH-CMD-002's SPEED/PAUSE SCHEDULER EVENTS NOW EXIST, IN THEIR OWN QUEUE, AND ARE NOT
## COMMITTED BY THIS STAGE. `scripts/core/scheduler_events.gd` implements R07-SCHED-001 under
## decision 0054, and it applies its events at the BOUNDARY PUMP between ticks -- not inside a
## tick, and not through `command_dispatch.gd`. That is the whole point: an economic command is
## due at `completed_tick + 1`, so routing a pause through this stage would make the unpause wait
## for the very tick the pause prevents. The pump's owner is whoever drives the host frame; this
## node drives a single simulation tick and must not pump inside one. Blocker U2 is closed in
## process; what remains open is persistence, which is task 09's save module, not this file's.
##
## EVERY OTHER STAGE IS ABSENT BECAUSE ITS OWNING STORE DOES NOT EXIST, and none of them is
## faked here:
##   ARCH-SYS-001 TransformSnapshot   no Transform store; no position, no movement.
##   ARCH-SYS-004 StockAge            RUNS NOW -- see the dispatched list above and decision
##                                    0085. It is not in this absent list any more. What is
##                                    still missing is WHICH STORE a container is: GDD §5.8's
##                                    four store factors belong to §5.9 buildings and furniture,
##                                    and no Building store exists, so `stock_age.gd` holds an
##                                    explicit declaration the building layer will write and
##                                    counts every undeclared container every hour.
##   ARCH-SYS-006 CropWeather         RUNS NOW -- see the dispatched list above and decision
##                                    0047. It is not in this absent list any more.
##   ARCH-SYS-007 ImmigrationDeparture no candidate store; `needs.gd` leaves `departure_days`
##                                    explicitly unwritten pending a complete mood.
##   ARCH-SYS-009 JobPlanner          RUNS NOW -- see the dispatched list above. It is not in
##                                    this absent list any more.
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
##                                    world-and-cohort creation below, which is not a per-tick
##                                    intent.
##   ARCH-SYS-020 Progression         no Progress store and no completed recipes or feasts.
##   ARCH-SYS-021 ForecastNotice      `economy_system.gd` recomputes its summary synchronously on
##                                    every committed change; its hourly half has nothing to
##                                    change while no lot ages and no policy exists.
##   ARCH-SYS-022 CheckpointHash      no save stream and no canonical digest yet.
##   ARCH-SYS-023 PresentationExtract RUNS NOW -- see the dispatched list above and the float
##                                    paragraph below. It is not in this absent list any more.
##
## REQ-SET-007's daily order is "age stocks, update ecology, advance crops/weather, process
## immigration/departures, then evaluate progression IN THAT ORDER", and `run_day_boundary()`
## runs exactly ONE of those five legs plus the season handover between the first two. What it
## does, in the requirement's order:
##
##   age stocks              RUN, and this is what decision 0085 added: `scripts/core/stock_age.gd`
##                           (ARCH-SYS-004) folds GDD §5.8's effective storage age into every lot
##                           in every DECLARED container, and expires the lots whose shelf life
##                           is over. Its cadence is the HOUR crossing, not the day, so at
##                           midnight this leg has usually already run on the tick path and the
##                           boundary records it rather than aging a second time (ARCH-TICK-002).
##                           It reads the ELAPSED interval's season, which is the first half of
##                           ARCH-TICK-003 and the reason it must precede the handover below.
##   [season handover]       RUN. ARCH-TICK-003 places it exactly between aging and ecology
##                           ("aging uses the season in the elapsed interval; ecology uses the
##                           new calendar day's season"), and REQ-SET-143's x1.20 winter hunger
##                           multiplier lives in `needs.gd` with the calendar season as its
##                           only input.
##   update ecology          RUN, and this is what task 03 increment 9 added:
##                           `scripts/core/ecology.gd` (ARCH-SYS-005) advances the fish stocks,
##                           the forage patches and their ruled quota midnight, every live hive
##                           and the exhausted resource nodes whose regrowth date has arrived.
##   advance crops/weather   RUN, and this is what task 03 increment 10 added:
##                           `scripts/core/crop_weather.gd` (ARCH-SYS-006) settles the completed
##                           day's REQ-SET-087 blight, advances every orchard block by that
##                           completed day, schedules and discloses §5.10's weather for the day
##                           now beginning, applies REQ-SET-086's evaporate-then-rain moisture,
##                           clears the tending flags, and makes decision 0044's FARM-side
##                           pollination refresh for any hive eligibility crossing the ecology
##                           leg above just committed. Its HOURLY half is on the tick path.
##   immigration/departures  NOT RUN. ARCH-SYS-007 has no candidate store.
##   evaluate progression    NOT RUN. ARCH-SYS-020 has no Progress store.
##
## THE LEG THAT DOES NOT RUN IS NOT FAKED AND THE ORDER IS NOT ASSUMED. `daily_leg_at()` and
## `daily_leg_count()` publish the legs the most recent boundary ACTUALLY EXECUTED, in the order
## it executed them, so "ecology runs after the season handover and nothing else runs" is a test
## rather than a comment. NO CONSTANT IS INVENTED: the season comes from `sim_clock.gd`'s offset
## calendar, the multiplier from `needs.gd`, and every ecology number from the four stores.
##
## ---------------------------------------------------------------------------------------
## ARCH-SYS-023 IS WHERE A `float` BECOMES LEGAL, AND NOWHERE ELSE IN THIS LOOP. AGENTS.md fixes
## integer arithmetic for all authoritative state; `presentation_extract.gd` is the presentation
## side of that boundary and is the ONLY module this node composes that produces a float at all.
## It captures fourteen COMMITTED INTEGERS once per tick and interpolates between the last two
## captures for a renderer, at an integer alpha the renderer supplies. Three properties this node
## depends on, each enforced there and each tested:
##   * IT WRITES NO STORE. Its only inputs are readers; it holds no reference this node's stores
##     can be reached through, and it is dispatched LAST so it never photographs a half-run tick.
##   * NO MUTABLE HANDLE ESCAPES IT. `presentation()` hands out an object whose every read fills
##     a record the CALLER owns. A UI holding it holds fourteen numbers and cannot edit one.
##   * HIDING A LAYER CHANGES WHAT IS REPORTED, NOT WHAT IS TRUE. A hidden layer's fields refuse;
##     the captured value, the next capture and every authoritative column are untouched.
## A refused capture is COUNTED in `refused_extract_count()` and never fatal: a missed frame is a
## presentation fault, and the simulation it failed to photograph is still correct.
##
## ---------------------------------------------------------------------------------------
## THE JOB QUEUE IS EMPTY IN AN *UNGENERATED, UNCOMMANDED* SETTLEMENT, AND THAT IS NOW THE WHOLE
## OF THE CLAIM. `job_planner.gd` (ARCH-SYS-009, decisions 0039/0040/0041/0051) IS COMPOSED HERE and
## runs every tick. What it creates, exactly:
##
##   WHAT NOW CREATES WORK IN THE RUNNING GAME:
##     * R06-JOB-001/002 REPEAT FORAGE HARVEST, from a PLAYER COMMAND. A committed DESIGNATE_ZONE
##       over a generated ecology basin creates the designation and enables its standing demand,
##       and the very next planner tick publishes a QUEUED FORAGE Job against real stock. That is
##       the whole intent-to-job path task 04.4 exists to close, and it is now one call chain.
##     * R06-JOB-007's daily 1-WU FARM tending service for each GROWING FarmPlot.
##     * R06-JOB-004's sowing first-plant, once something confirms a planting.
##     * R06-JOB-006's daily 20-WU KEEP hive service, for each operational, non-abandoned Hive on
##       a spring/summer/autumn service day (decision 0051). It needs NO player command: it is
##       condition-driven, so a colonised apiary produces work on the very next planner tick. The
##       planner is given ARCH-SYS-005's OWN hive store, asserted above, so the rows it services
##       are the rows `ecology.gd` advances. WINTER CREATES NO TENDING-LABOR JOB; it records a
##       feed-delivery demand as state, and no delivery job exists for it.
##   WHAT STILL CREATES NONE: REQ-SET-073 ripe harvest and REQ-SET-085 withered clearing (both
##     keep their own route and are NOT rerouted through the planner); fishing cycles
##     (R06-JOB-003, no Expedition store); rotation advance (R06-JOB-005, `field_policy.gd`
##     requests a crop and creates no Job, nothing delivers that request, and NOTHING COMPLETES
##     THE HARVEST OR CLEARING JOBS THAT WOULD CLOSE A CYCLE -- decision 0051 §5); the hive's
##     winter FEED DELIVERY (no hive-owned destination container and no hauling producer; the
##     container store itself exists); and every production order, recipe, construction, care
##     request and hauling policy, none of which has a store.
##
## AN *UNGENERATED* SETTLEMENT'S QUEUE IS STILL 0, AND `world_init.gd` IS NOW COMPOSED HERE.
## `create_generated_settlement()` (decision 0071, reordered by R-INIT-ID-001 / decision 0075) runs
## §5.1's cohort and REQ-SET-009's world as one transaction -- the twelve residents first, on
## persistent ids 1-12, and the world from 13 -- so the running game has trees, ore, four forage
## basins, the estuary, a seeded RNG AND twelve residents whose ids are the GDD's own.
## The two blockers that kept the generator out of this node are both gone:
## decision 0052 gave its seventeen item ids an authored source (resolved by key from the compiled
## catalog, so this node still invents none of them), and this node is now the caller. A queue of
## 0 after generation means no player command has arrived, which is the honest remaining reason.
##
## NOTHING HERE WRITES JOB_STATE_WORK. A planner-published job is QUEUED; ARCH-SYS-010 may bind a
## worker and make it RESERVED; RESERVED -> TRAVEL -> WORK is ARCH-SYS-011/012's and does not
## exist. Task 04.4 says in terms that no delivered output is expected before task 05.
##
## `job_queue_length()` reports the real number, and the selection and work stages run over it
## honestly. A fabricated job would make the loop look busy and would measure a fiction; that has
## not changed.
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
## THE ECOLOGY IS OWNED, DRIVEN AND -- ONCE GENERATED -- FULL. `ecology.gd` composes the four
## ecology stores over THIS settlement's directory, and `run_day_boundary()` drives it at every
## real midnight. Until `create_generated_settlement()` runs, `count()`, `zone_count()`,
## `habitat_count()` and `hive_count()` are all 0 and the stage honestly does nothing; after it
## runs they hold §5.1's tree cover, both ore deposits, the four forage basins and the estuary's
## three habitats, and the midnight leg advances real stock. Nothing is placed here to make the
## day look busy: every row comes from `world_init.gd`, which owns the geometry and the counts.
## `ecology()` is the accessor the generator and the tests reach the stores through, and
## ARCH-SYS-006 and ARCH-SYS-009 borrow the same object rather than a copy.
##
## THE CROP LAYER IS OWNED, DRIVEN AND EMPTY IN THE SAME THREE SENSES. `crop_weather.gd` composes
## the FarmPlot store and the single Weather row over this settlement's directory, `run_tick()`
## drives its hourly leg at every hour crossing and `run_day_boundary()` drives its daily leg at
## every real midnight. THE WEATHER IS REAL FROM DAY 1 -- `create_initial_settlement()` opens the
## opening day's baseline, which the offset calendar's first midnight (day 2) would otherwise
## leave 18 hours late -- and THE FIELDS STAY EMPTY EVEN AFTER GENERATION, because §5.1 lists no
## starter FarmPlot and `world_init.gd` therefore creates none: a plot arrives with a player FARM
## designation. `farming().count()` is 0, so the hourly leg honestly integrates nothing.
## `crop_weather()`, `farming()` and `weather()` are the accessors the generator and tests use.
##
## THE WORLD SEED IS NO LONGER MISSING. `rng()` is composed here UNSEEDED and stays that way in a
## settlement nobody generated; `create_generated_settlement()` seeds it, because `world_init.gd`
## owns REQ-SET-009's `World.seed` and seeds all nine streams as part of publishing. §5.10's
## forced first spring consumes zero draws, so even an ungenerated settlement's first season runs
## and only its SECOND season's first midnight refuses `RNG_NOT_SEEDED`. A GENERATED settlement
## does not: it runs a full simulated year of weather. No seed is defaulted or invented here.
##
## ---------------------------------------------------------------------------------------
## THE STOCK LAYER IS OWNED, DRIVEN AND EMPTY, in the same three senses as the crop layer.
## `inventory.gd` is composed here with the §4.3 catalog registered into it, `stock_age.gd`
## (ARCH-SYS-004) is composed over it, and `run_tick()` drives its hourly leg at every hour
## crossing. IT HOLDS NO LOTS, because nothing in this node creates one: §5.1's starter stock is
## placed by `economy_system.gd`, which owns a SEPARATE `inventory.gd` instance of its own, and
## `world_init.gd` creates no lot in this one. THAT DUPLICATION IS REAL AND IS REPORTED RATHER
## THAN PAPERED OVER: two inventories are two authorities, and merging them means editing
## `economy_system.gd` and `world_init.gd`, neither of which this work owns. Until they are one
## store, `stock_age()` ages this settlement's lots and the autoload's food does not age.
##
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
##   * `stock_age.run_hour_into()` ZERO on 23 ticks in 24, for the same reason as the crop hour
##     below, and zero on the 24th unless a lot ACTUALLY EXPIRES -- the sweep walks packed
##     columns and writes through `inventory.gd`'s `_into` forms into instance scratch. An
##     expiring lot costs four OpResults inside `inventory.gd`, once in that lot's life.
##   * `crop_weather.run_hour_into()` ZERO on 23 ticks in 24, because `is_hour_boundary()` is a
##     modulo and returns before anything else runs. On the 24th it allocates nothing either,
##     unless a plot actually takes frost or actually withers; `crop_weather.gd`'s own header
##     itemises which store calls allocate on which hour and why.
##   * `job_planner.run_tick_into()` ZERO of its own (that file's header states it): the drain,
##     the 1/30 owner slice and the 1/30 designation slice all run through `_reconcile_owner()`,
##     which returns an int. A tick on which it actually PUBLISHES a job allocates inside
##     `jobs.gd` and `forage.gd`, per job, which is their published contract.
##   * `presentation.capture()` ZERO. Both frames and both flag columns are sized once, the
##     calendar is instance scratch, and every field is a scalar read.
##
## ARCH-SYS-005 IS NOT ON THE TICK PATH AT ALL, AND ARCH-SYS-006 IS ON IT ONLY HOURLY.
## `ecology.gd` is called from `run_day_boundary()` and never from `run_tick()`, so its per-day
## cost -- one OpResult per store sweep, plus one per resource node actually regrown, all named in
## that file's header -- lands once per SIMULATED DAY, which at 1x is once per 18000 ticks.
## `crop_weather.gd`'s DAILY leg lands there too. Its HOURLY leg is the only thing this milestone
## adds to the per-tick path, and on a non-crossing tick that is one addition and one modulo.
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
const EcologyScript := preload("res://scripts/core/ecology.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")
const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
## Reached for `season_of_day()` alone: ARCH-SYS-005 owns the §5.6 calendar and the cohort
## preflight asks it which season the opening day is in rather than deriving a second answer.
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")

## Index of winter in `sim_clock.gd`'s SEASON_NAMES. `_assert_shared_contracts()` proves it names
## winter rather than trusting the ordering, because REQ-SET-143's multiplier hangs off it.
const SEASON_WINTER: int = 3
const SEASON_COUNT: int = 4

## REQ-SET-007's five daily legs, in the requirement's own order, plus ARCH-TICK-003's season
## handover between the first two. `daily_leg_at()` publishes the ones a boundary ACTUALLY ran,
## so a leg this system does not own cannot be quietly slipped in and cannot be assumed absent.
const LEG_STOCK_AGE: int = 0
const LEG_SEASON_HANDOVER: int = 1
const LEG_ECOLOGY: int = 2
const LEG_CROP_WEATHER: int = 3
const LEG_IMMIGRATION_DEPARTURE: int = 4
const LEG_PROGRESSION: int = 5
const DAILY_LEG_CAPACITY: int = 6

## The §5 stages this node dispatches ON THE TICK PATH, in dispatch order. `tick_stage_usec_at()`
## publishes what each one COST on the most recent tick, so "which stage is expensive" is a
## measurement rather than an opinion. NO BUDGET IS ASSERTED AGAINST THEM: REQ-SET-163's figures
## are for 256 residents on a stated machine, and nothing here qualifies against them.
const TICK_STAGE_COMMAND_COMMIT: int = 0
const TICK_STAGE_INTERVAL: int = 1
const TICK_STAGE_STOCK_AGE: int = 2
const TICK_STAGE_CROP_HOUR: int = 3
const TICK_STAGE_JOB_PLANNER: int = 4
const TICK_STAGE_SELECTION: int = 5
const TICK_STAGE_WORK: int = 6
const TICK_STAGE_PRESENTATION: int = 7
const TICK_STAGE_COUNT: int = 8

## The ARCH-SYS id each measured stage is, so a reader cannot mistake the selection stage's
## fused pair for one system. ARCH-SYS-008 appears as a PART: only activity resolution runs.
const TICK_STAGE_KEYS: Array[StringName] = [
	&"ARCH-SYS-002 CommandCommit",
	&"ARCH-SYS-003 IntervalIntegrator (ARCH-SYS-017 CareHealth inside it)",
	&"ARCH-SYS-004 StockAge hourly",
	&"ARCH-SYS-006 CropWeather hourly",
	&"ARCH-SYS-009 JobPlanner",
	&"ARCH-SYS-008 NeedIntent (activity resolution only) + ARCH-SYS-010 JobSelector",
	&"ARCH-SYS-013 ProductiveWork",
	&"ARCH-SYS-023 PresentationExtract",
]

## REQ-SET-012's "a prepared meal is reachable and unreserved", answered false and NOT guessed.
## Two separate things are missing: §5.7's recipe/portion model, so no prepared MEAL exists as an
## entity at all (a `ration` lot in the pantry is stock, not a served portion nobody has claimed),
## and §5.11's pathfinder, so REACHABLE has no oracle. False therefore says "no reachable prepared
## meal", which is the true state of a settlement with no kitchen and no routes. Its only effect
## is that REQ-SET-013's raw-edible threshold (hunger<=1500) governs the eat interrupt instead of
## REQ-SET-012's 3500 -- and today not even that is observable, because both WORK and ANYTHING
## permit work and no job exists to be interrupted.
const PREPARED_MEAL_REACHABLE: bool = false

## GDD §5.1: the settlement opens on absolute day 1, at tick 0, which is 06:00 and no crossing.
const OPENING_CALENDAR_DAY: int = 1

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_DAY: StringName = &"INVALID_ABSOLUTE_DAY"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_NO_TICK_MEASURED: StringName = &"NO_TICK_MEASURED"
const REFUSE_CLOCK_BIND: StringName = &"SIMULATION_CLOCK_BIND_REFUSED"
const REFUSE_CALENDAR_MISMATCH: StringName = &"DAY_BOUNDARY_CALENDAR_MISMATCH"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_INDEX"
const REFUSE_ECOLOGY_BIND: StringName = &"COMMAND_ECOLOGY_BIND_REFUSED"
const REFUSE_PLANNER_DAY: StringName = &"JOB_PLANNER_DAY_REFUSED"

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
var _ecology: EcologyScript = null
var _rng: RngScript = null
var _crop_weather: CropWeatherScript = null
var _planner: JobPlannerScript = null
var _presentation: PresentationExtractScript = null
var _world: WorldInitScript = null
var _inventory: InventoryScript = null
var _item_definitions: ItemDefinitionsScript = null
var _stock_age: StockAgeScript = null

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
var _ecology_day: EcologyScript.DayResult = EcologyScript.DayResult.new()
var _crop_day: CropWeatherScript.DayResult = CropWeatherScript.DayResult.new()
var _crop_hour: CropWeatherScript.HourResult = CropWeatherScript.HourResult.new()
var _stock_hour: StockAgeScript.HourResult = StockAgeScript.HourResult.new()
var _planner_result: IntMath.IntResult = IntMath.IntResult.new()
var _planner_day: JobPlannerScript.OpResult = null
## The 00:00 tick of the day boundary being run, located and PROVED once per boundary.
var _boundary_tick: int = 0
## REQ-SET-007 legs the most recent boundary executed, in execution order. Sized once in _init().
var _daily_legs: PackedInt32Array = PackedInt32Array()
var _daily_leg_count: int = 0
var _tick_timer: PerfTimerScript = PerfTimerScript.new()
## One reused stopwatch for every stage: each stage opens and closes it, so the cost is two
## `Time.get_ticks_usec()` calls per stage and no allocation at all.
var _stage_timer: PerfTimerScript = PerfTimerScript.new()
## Microseconds the most recent tick spent in each dispatched stage, and the running totals the
## means are taken over. Both sized once in _init(); neither is simulation state.
var _stage_usec: PackedInt64Array = PackedInt64Array()
var _stage_usec_total: PackedInt64Array = PackedInt64Array()
## How many times each stage has been MEASURED since the last reset(). One per tick per stage, so
## a stage that stopped being dispatched -- or whose window was closed against the wrong stage --
## is visible as a count that no longer matches `ticks_run()`.
var _stage_measured: PackedInt64Array = PackedInt64Array()

# --- observable counters ----------------------------------------------------------------------

var _ticks_run: int = 0
var _refused_tick_count: int = 0
var _refused_crop_hour_count: int = 0
var _refused_stock_hour_count: int = 0
var _refused_extract_count: int = 0
var _refused_planner_day_count: int = 0
var _planner_day_count: int = 0
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

	Every store is built here rather than at declaration because five of them borrow another:
	the residents store owns the directory and needs rows, the schedule reads those same needs,
	jobs read residents/priorities/schedule, work reads jobs, and the ecology stores take this
	settlement's directory and Job store so a forage claim validates its owning Job in the one
	directory every other settlement reference already lives in.
	"""
	_directory = _residents.directory()
	_needs = _residents.needs()
	_schedule = ScheduleScript.new(_needs)
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_work = WorkScript.new(_jobs)
	_commands = CommandsScript.new(SimClockScript.new(), _directory)
	_dispatch = CommandDispatchScript.new(_commands, _residents, _priorities, _schedule, _jobs)
	_ecology = EcologyScript.new(_directory, _jobs)
	_rng = RngScript.new()
	_crop_weather = CropWeatherScript.new(_ecology, _rng)
	_planner = JobPlannerScript.new(_crop_weather.farming(), _jobs, _ecology.forage(),
		_ecology.orchard_hive())
	_presentation = PresentationExtractScript.new(_residents, _jobs, _dispatch,
		_ecology.forage(), _planner, _crop_weather.weather())
	_world = WorldInitScript.new(_directory, _ecology.resource_nodes(), _ecology.forage(),
		_ecology.fishing(), _rng, _crop_weather.farming(), _ecology.orchard_hive(), _jobs,
		_commands)
	_compose_stock_layer()
	_bind_ecology_to_commands()
	_live_slots.resize(ResidentsScript.RESIDENT_CAPACITY)
	_live_slots.fill(EntityDirectoryScript.NULL_SLOT)
	_daily_legs.resize(DAILY_LEG_CAPACITY)
	_daily_legs.fill(LEG_STOCK_AGE)
	_stage_usec.resize(TICK_STAGE_COUNT)
	_stage_usec_total.resize(TICK_STAGE_COUNT)
	_stage_measured.resize(TICK_STAGE_COUNT)
	_assert_shared_contracts()


func _compose_stock_layer() -> void:
	"""Build the InventoryLot store, load its item catalog, and give ARCH-SYS-004 both.

	The catalog is loaded INTO this settlement's own inventory because `register_item()` is what
	gives a lot row a mass and a category; ARCH-SYS-004 then reads the same catalog for GDD
	§5.8's shelf lives. A catalog that fails to load leaves the stage refusing
	ITEM_CATALOG_NOT_BOUND by its own rule, which is visible in `stock_hour()`, rather than
	leaving this node to invent a shelf life.
	"""
	_inventory = InventoryScript.new()
	_item_definitions = ItemDefinitionsScript.new()
	_item_definitions.load_default(_inventory)
	_stock_age = StockAgeScript.new(_inventory, _item_definitions)


func _bind_ecology_to_commands() -> void:
	"""Task 04.2's NAMED RUNTIME HANDOFF: give ARCH-SYS-002 the ecology stores it commits into.

	This one call is what stops DESIGNATE_ZONE and SET_POLICY refusing COMMAND_STORE_NOT_BOUND in
	the real game. It was deliberately absent while the ecology had nothing to advance and the
	world had no content; ARCH-SYS-005/006 now run and `world_init.gd` fills the world, so both
	reasons are gone. A refused bind is fatal rather than silent: the settlement would otherwise
	go on refusing every zone and policy edit while the HUD showed a running game.
	"""
	if _dispatch.bind_ecology(_ecology.forage(), _planner):
		return
	_last_refusal = REFUSE_ECOLOGY_BIND
	push_error("SettlementSystem could not bind the ecology to ARCH-SYS-002: %s"
		% _dispatch.last_refusal())


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
	assert(_ecology.directory() == _directory,
		"the ecology stores must validate references through this settlement's one directory")
	assert(_crop_weather.directory() == _directory,
		"the crop and weather stores must validate references through that same directory")
	assert(_crop_weather.orchard_hive() == _ecology.orchard_hive(),
		"ARCH-SYS-006 must borrow ARCH-SYS-005's hives, not compose a second orchard store")
	assert(_crop_weather.rng() == _rng,
		"ARCH-SYS-006 must consume this settlement's one ARCH-RNG-002 stream set")
	assert(DAILY_LEG_CAPACITY == LEG_PROGRESSION + 1,
		"the leg log must hold exactly REQ-SET-007's legs plus the season handover")
	assert(_planner.forage() == _ecology.forage(),
		"ARCH-SYS-009 must plan over ARCH-SYS-005's own HarvestZone store, not a second one")
	assert(_planner.jobs() == _jobs,
		"ARCH-SYS-009 must publish into the Job store ARCH-SYS-010 selects from")
	assert(_planner.hives() == _ecology.orchard_hive(),
		"R06-JOB-006's producer must service the hives ARCH-SYS-005 advances, not a private set")
	assert(_planner.farming() == _crop_weather.farming(),
		"ARCH-SYS-009 must service the FarmPlot rows ARCH-SYS-006 integrates")
	assert(_world.directory() == _directory,
		"REQ-SET-009's generator must allocate out of this settlement's one directory")
	assert(TICK_STAGE_KEYS.size() == TICK_STAGE_COUNT,
		"every measured tick stage must name the ARCH-SYS system it dispatches")
	assert(_stage_usec.size() == TICK_STAGE_COUNT and _stage_usec_total.size() == TICK_STAGE_COUNT,
		"the per-stage measurement columns must hold exactly one entry per dispatched stage")


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

func create_generated_settlement(items: ItemDefinitionsScript,
		world_seed: int = WorldInitScript.TUTORIAL_WORLD_SEED) -> bool:
	"""REQ-SET-009 end to end: §5.1's cohort takes ids 1-12, then §5.1's world follows from 13.

	THE GAP THIS CLOSES. `world_init.gd` built the world and `create_initial_settlement()` built
	the population, and NOTHING CALLED BOTH -- so generating produced an empty world and booting
	produced a cohort with nowhere to stand. §5.1 states one initialization contract, not two, and
	this is the single operation that satisfies it.

	THE ORDER IS THE RULING'S (R-INIT-ID-001, decision 0075), AND IT IS THE REVERSE OF DECISION
	0071's. That decision recorded that `world_init._publish()` cleared the directory, forcing the
	world to be created first and leaving the cohort on ids 1714-1725 instead of §5.1's "IDs 1-12".
	The specification owner ruled that the clear is a reset BEFORE new-world allocation, not a
	second reset inside terrain publication. So this operation is now one transaction:

	  1. PREFLIGHT, changing nothing: the settlement must be empty, the seventeen resource ids must
	     bind, the world plan must stage and validate, and the cohort's own catalog, capacities and
	     opening-day weather must check out. Every refusal below is decided here.
	  2. ENTER THE TRANSACTION: `reset()` once -- stores, directory, allocators, command, job and
	     child state -- then seed the nine RNG streams, before any consumer draws.
	  3. ALLOCATE THE TWELVE RESIDENTS FIRST, in §5.1's cohort order, through the ordinary
	     directory allocator. They receive persistent ids 1-12 and Warden Rowan receives 1.
	  4. PUBLISH THE WORLD from the SAME continuing counter, so the first world entity is 13.
	     `publish_prepared()` clears and reseeds nothing.

	ALLOCATE BEFORE CONSUME (decision 0059). A populated settlement refuses at step 1 and is
	byte-identical afterwards, which is how "a refused initialization retains the previous valid
	world" is honoured: the only world this can overwrite is one with nobody in it. See
	`_abandon_transaction()` for what an in-transaction failure can and cannot restore.
	"""
	if _residents.population() != 0:
		return _refuse(ResidentsScript.REFUSE_SETTLEMENT_NOT_EMPTY)
	var built: WorldInitScript.RequestResult = WorldInitScript.bound_request(items, world_seed)
	if not built.ok:
		return _refuse(built.error)
	var planned: WorldInitScript.GenerateResult = _world.preflight(built.request)
	if not planned.ok:
		return _refuse(planned.error)
	var cohort: StringName = _refuse_cohort_preflight()
	if cohort != REFUSE_NONE:
		_world.discard_prepared_plan()
		return _refuse(cohort)
	return _run_initialization_transaction()


func _refuse_cohort_preflight() -> StringName:
	"""The code blocking §5.1's cohort, or REFUSE_NONE -- read from live state, writing nothing.

	Ruling step 1 requires the cohort's capacity, catalog bindings and resources preflighted before
	the transaction opens, so that step 3 cannot fail after the reset has already emptied a world.
	Every check below reads state the reset does not change: compiled catalogs, fixed capacities,
	and the opening day's weather preconditions (§5.10's forced first spring, which draws nothing).
	"""
	if _residents.catalog_error() != "":
		return ResidentsScript.REFUSE_SPECIES_CATALOG
	for species: StringName in ResidentsScript.INITIAL_SPECIES:
		if not _residents.has_species(species):
			return ResidentsScript.REFUSE_UNKNOWN_SPECIES
	if ResidentsScript.INITIAL_POPULATION > ResidentsScript.RESIDENT_CAPACITY \
			or ResidentsScript.INITIAL_POPULATION > EntityDirectoryScript.RESIDENT_LIVING_CAP \
			or ResidentsScript.INITIAL_POPULATION > _directory.capacity_of_kind(
				EntityDirectoryScript.KIND_RESIDENT):
		return EntityDirectoryScript.REFUSAL_LIVING_CAP
	var template: IntMath.IntResult = _schedule.default_template_id()
	if not template.ok:
		return StringName(template.error)
	return _crop_weather.preflight_refusal_for(OPENING_CALENDAR_DAY,
		OrchardHiveScript.season_of_day(OPENING_CALENDAR_DAY))


func _run_initialization_transaction() -> bool:
	"""Ruling steps 2-5: reset once, seed, allocate the cohort, then publish the world with it.

	The cohort is allocated BEFORE the world so that §5.1's twelve residents take persistent ids
	1-12 out of §4.2's one id space; publication continues the same counter rather than restarting
	it. Any failure inside the transaction abandons the whole thing through
	`_abandon_transaction()`; nothing is published by halves.
	"""
	reset()
	var seeded: StringName = _world.seed_prepared_streams()
	if seeded != REFUSE_NONE:
		return _abandon_transaction(seeded)
	if not create_initial_settlement():
		return _abandon_transaction(_last_refusal)
	var published: WorldInitScript.GenerateResult = _world.publish_prepared()
	if not published.ok:
		return _abandon_transaction(published.error)
	_last_refusal = REFUSE_NONE
	return true


func _abandon_transaction(code: StringName) -> bool:
	"""Return the settlement to EMPTY, drop the staged plan, and report `code`.

	WHAT THIS RESTORES AND WHAT IT CANNOT. A settlement that held residents refused in the
	preflight and never reached the transaction, so no populated world can be lost here. A world
	with NO residents in it -- the only other thing the transaction can overwrite -- is not
	restored: rebuilding it would mean re-running generation, and a regenerated world is a
	different set of persistent ids rather than the same world back. The ruling's "reset-to-empty
	alone is insufficient when a valid world preceded it" is therefore satisfied by the preflight
	rather than by a rollback, and this limitation is named in decision 0075 rather than hidden.
	"""
	_world.discard_prepared_plan()
	reset()
	return _refuse(code)


func create_initial_settlement() -> bool:
	"""Spawn the GDD §5.1 starting cohort and attach every per-resident settlement row.

	All-or-nothing: a partial cohort, or a resident missing its schedule or job agent, would be a
	settlement that ticks some residents and not others. On any refusal the whole settlement is
	returned to empty and the reason is preserved in `last_refusal()`.

	There is deliberately NO second emptiness check here. `residents.spawn_initial_settlement()`
	already refuses a non-empty store, to protect §5.1's "IDs 1-12", and a copy of that rule here
	would be a second place for it to be stated and to drift. Its refusal is passed through.

	§5.1's "IDs 1-12" IS NOW LITERAL ON BOTH PATHS (R-INIT-ID-001). Called on a freshly reset
	settlement -- which is what `_run_initialization_transaction()` does, before the world is
	published -- the twelve spawns take the first twelve persistent ids out of §4.2's one id space,
	in cohort order, so Warden Rowan is id 1. Called on its own, as the cohort-only path the suite
	uses, it does the same thing over an empty directory.
	"""
	var spawned: ResidentsScript.OpResult = _residents.spawn_initial_settlement()
	if not spawned.ok:
		return _refuse(spawned.error)
	if not _attach_all_residents() or not _open_the_first_day():
		var code: StringName = _last_refusal
		reset()
		_last_refusal = code
		return false
	_last_refusal = REFUSE_NONE
	return true


func _open_the_first_day() -> bool:
	"""Write §5.1's opening day's §5.10 weather, because day 1 never reaches a midnight.

	The offset calendar starts at 06:00 of day 1 and its first crossing is day 2, so without this
	the first 18 game hours would read the cleared Weather row -- 0.0 C and no rain -- instead of
	spring. It consumes no WEATHER draw: year 1's spring is §5.10's forced onboarding event.
	"""
	if _crop_weather.prime_day(OPENING_CALENDAR_DAY):
		return true
	return _refuse(_crop_weather.last_refusal())


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

	`_clear_stores()`'s `residents.clear()` also clears the directory and needs rows, because this
	system built the residents store with neither collaborator supplied and it therefore owns both.
	"""
	_clear_stores()
	_live_slots.fill(EntityDirectoryScript.NULL_SLOT)
	_live_count = 0
	_daily_leg_count = 0
	_boundary_tick = 0
	_clear_counters()


func _clear_stores() -> void:
	"""Empty every composed store in one place, so a store added later cannot be forgotten here."""
	_residents.clear()
	_priorities.clear()
	_schedule.clear()
	_jobs.clear()
	_work.clear()
	_reservations.clear()
	_commands.clear()
	_dispatch.clear()
	_ecology.clear()
	_crop_weather.clear()
	_clear_stock_layer()
	_planner.clear()
	_presentation.clear()
	_world.clear()
	_rng.clear()


func _clear_stock_layer() -> void:
	"""Empty the lot store and every storage declaration, then re-register the item catalog.

	`inventory.clear()` drops the item registry as well as the rows -- it is the catalog-time
	half of the same store -- so a settlement reset without this reload would leave every lot
	operation refusing UNKNOWN_ITEM. Both generation spaces step forward inside `clear()`, so a
	lot or container ref taken before a reset still cannot validate after it.
	"""
	_inventory.clear()
	_item_definitions.load_default(_inventory)
	_stock_age.clear()


func _clear_counters() -> void:
	"""Return every observable counter and refusal to its pre-run value."""
	_ticks_run = 0
	_refused_tick_count = 0
	_refused_crop_hour_count = 0
	_refused_stock_hour_count = 0
	_refused_extract_count = 0
	_refused_planner_day_count = 0
	_planner_day_count = 0
	_tick_usec_total = 0
	_tick_usec_max = 0
	_stage_usec.fill(0)
	_stage_usec_total.fill(0)
	_stage_measured.fill(0)
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
		_extract_presentation(tick_index)
		return false
	_age_stocks(tick_index)
	_integrate_crops(tick_index)
	_plan_jobs(tick_index)
	_select_jobs(tick_index)
	_run_productive_work()
	_extract_presentation(tick_index)
	return true


func _plan_jobs(tick_index: int) -> void:
	"""ARCH-SYS-009 JobPlanner: reconcile every dirty owner and this tick's staggered idle slice.

	R06-JOB-008 requires an owner's demand to be reconciled "before selection", and selection is
	the very next stage, so this sits between them. A refusal is recorded and not fatal: one
	unplannable owner is not a reason to discard a committed needs sweep.

	IT RUNS BEFORE ARCH-SYS-008's activity resolution rather than after it, which is one place
	off §5's table order. The two have no data dependency -- the planner reads FarmPlot rows and
	HarvestZone designations, and resolution reads needs and the hour -- and moving it after
	would split the fused resolve/select loop that keeps eligibility step 2 from seeing a stale
	hour. Named here rather than left for a reader to discover.
	"""
	_stage_timer.start()
	if not _planner.run_tick_into(tick_index, _planner_result):
		_last_refusal = StringName(_planner_result.error)
	_close_stage(TICK_STAGE_JOB_PLANNER)


func _extract_presentation(tick_index: int) -> void:
	"""ARCH-SYS-023 PresentationExtract: snapshot the committed tick. Writes no store, ever.

	LAST, because a snapshot taken before the final stage would show a tick that never existed.
	A refusal is recorded rather than fatal: a missed frame is a presentation fault, and the
	simulation it failed to photograph is still correct.
	"""
	_stage_timer.start()
	if not _presentation.capture(tick_index):
		_refused_extract_count += 1
	_close_stage(TICK_STAGE_PRESENTATION)


func _close_stage(stage: int) -> void:
	"""Close the open stage window and fold its cost into this tick's and the run's totals."""
	_stage_usec[stage] = _stage_timer.stop()
	_stage_usec_total[stage] += _stage_usec[stage]
	_stage_measured[stage] += 1


func _commit_commands(tick_index: int) -> void:
	"""ARCH-SYS-002 CommandCommit: drain and commit every player edit due at this tick."""
	_stage_timer.start()
	_commands_committed_last_tick = 0
	_commands_refused_last_tick = 0
	if not _dispatch.commit_tick_into(tick_index, _command_report):
		_last_refusal = _dispatch.last_refusal()
		_close_stage(TICK_STAGE_COMMAND_COMMIT)
		return
	_commands_committed_last_tick = _command_report.committed
	_commands_refused_last_tick = _command_report.refused
	_ensure_command_clock()
	_close_stage(TICK_STAGE_COMMAND_COMMIT)


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
	_stage_timer.start()
	var swept: NeedsScript.OpResult = _needs.tick_all()
	_close_stage(TICK_STAGE_INTERVAL)
	if swept.ok:
		return true
	_refused_tick_count += 1
	_report_first_refusal(swept.error)
	return _refuse(swept.error)


func _age_stocks(tick_index: int) -> void:
	"""ARCH-SYS-004 StockAge, the HOURLY cadence its §5 row states, in the table's own position.

	FOURTH, after ARCH-SYS-003 and before ARCH-SYS-006, which is exactly where §5's table puts
	it. Running it here is also what makes REQ-SET-007's FIRST daily leg land before
	ARCH-TICK-003's season handover: at a midnight tick the clock calls `run_tick()` for that
	tick and only then `run_day_boundary()`, so the aging pass has already consumed the midnight
	crossing by the time the handover runs.

	The predicate is the only per-tick cost: 23 ticks in 24 are not an hour crossing and this
	returns immediately. A refusal is COUNTED rather than fatal, for the same reason as the crop
	hour -- the needs sweep for this tick has already committed.
	"""
	_stage_timer.start()
	_age_stock_hour(tick_index)
	_close_stage(TICK_STAGE_STOCK_AGE)


func _age_stock_hour(tick_index: int) -> void:
	"""The hourly aging pass itself, so the measurement above stays one statement wide."""
	if not StockAgeScript.is_hour_boundary(tick_index):
		return
	if _stock_age.run_hour_into(tick_index, _stock_hour):
		return
	_refused_stock_hour_count += 1
	_last_refusal = _stock_hour.error


func _integrate_crops(tick_index: int) -> void:
	"""ARCH-SYS-006 CropWeather, HOURLY half: one hour of §5.6 growth, frost and ripe expiry.

	The predicate is the only per-tick cost: 23 ticks in 24 are not an hour crossing and this
	returns immediately. A refusal is COUNTED rather than fatal -- the needs sweep for this tick
	has already committed, and one refused crop hour is not a reason to discard it -- and
	`crop_hour()` carries the reason on its own channel.
	"""
	_stage_timer.start()
	_integrate_crop_hour(tick_index)
	_close_stage(TICK_STAGE_CROP_HOUR)


func _integrate_crop_hour(tick_index: int) -> void:
	"""The hourly crop integration itself, so the measurement above stays one statement wide."""
	if not CropWeatherScript.is_hour_boundary(tick_index):
		return
	if _crop_weather.run_hour_into(tick_index, _crop_hour):
		return
	_refused_crop_hour_count += 1
	_last_refusal = _crop_hour.error


func _select_jobs(tick_index: int) -> void:
	"""ARCH-SYS-008 (activity resolution only) and ARCH-SYS-010 JobSelector.

	§5.3 reevaluates an idle resident every 30 ticks staggered by persistent ID mod 30, and
	`jobs.should_evaluate()` is that predicate -- allocation-free, and false for a resident who
	already holds a job. The activity is resolved immediately before the pass that reads it, so
	eligibility step 2 can never see a stale hour.
	"""
	_stage_timer.start()
	_resolve_and_select(tick_index)
	_close_stage(TICK_STAGE_SELECTION)


func _resolve_and_select(tick_index: int) -> void:
	"""The fused resolve/select pass: one resident is resolved immediately before it is offered."""
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
	_stage_timer.start()
	for index: int in _jobs.job_count():
		var live: IntMath.IntResult = _jobs.live_job_at(index)
		if not live.ok:
			continue
		_tick_one_activity(live.value)
	_close_stage(TICK_STAGE_WORK)


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
	"""REQ-SET-007's daily boundary, in the requirement's own order, running the legs it owns.

	Age stocks (ARCH-SYS-004) is skipped first, then ARCH-TICK-003's season handover, then
	ARCH-SYS-005 Ecology; crops/weather, immigration/departures and progression are skipped after
	it, in that order, because they have no owner (header). Nothing is reordered and no unowned
	leg is faked: `daily_leg_at()` reports what actually ran.
	"""
	_daily_leg_count = 0
	if absolute_day <= 0:
		return _refuse(REFUSE_INVALID_DAY)
	if season < 0 or season >= SEASON_COUNT:
		return _refuse(REFUSE_INVALID_SEASON)
	if not _locate_boundary_tick(absolute_day, season):
		return false
	if not _age_stocks_leg():
		return false
	if not _apply_season_handover(season):
		return false
	if not _update_ecology():
		return false
	if not _advance_crops_and_weather():
		return false
	_run_planner_day()
	_last_refusal = REFUSE_NONE
	return true


func _locate_boundary_tick(absolute_day: int, season: int) -> bool:
	"""Find this day's 00:00 tick and PROVE it decodes back to the day and season handed in.

	The ecology stage is gated on a tick, and the clock hands this callback a day and a season,
	so the tick is recovered by `ecology.gd`'s inverse -- which is itself gated on
	`sim_clock.gd`'s `is_day_boundary()`, the single definition of a crossing -- and then decoded
	AGAIN through the calendar and compared. A wrong inverse, a caller inventing a day, or a
	season that does not belong to that day all refuse here rather than running the ecology stage
	on a tick that is not midnight. Day 1 opens at 06:00 and has no midnight, so it refuses.
	"""
	if not EcologyScript.midnight_tick_of_day_into(absolute_day, _read):
		return _refuse(StringName(_read.error))
	_boundary_tick = _read.value
	SimClockScript.calendar_at_into(_boundary_tick, _calendar)
	if _calendar.absolute_day != absolute_day or _calendar.season != season:
		return _refuse(REFUSE_CALENDAR_MISMATCH)
	return true


func _age_stocks_leg() -> bool:
	"""ARCH-SYS-004 StockAge: REQ-SET-007's FIRST leg, BEFORE ARCH-TICK-003's season handover.

	ARCH-TICK-002 forbids "a second age pass just because the same tick is both hourly and
	daily", and a midnight tick IS an hour crossing, so this does not age a second time: when
	`run_tick()` has already consumed this exact tick the leg is recorded and nothing else
	happens. It runs the pass itself only when nothing else has -- a boundary driven directly,
	with no tick path behind it -- so the leg is genuinely executed in either case rather than
	logged on trust.

	The pass reads the ELAPSED interval's season from the calendar itself, which is the other
	half of ARCH-TICK-003: aging must not see the new day's season, and `_apply_season_handover()`
	below is the very next statement.
	"""
	if _stock_age.last_hour_tick() != _boundary_tick:
		if not _stock_age.run_hour_into(_boundary_tick, _stock_hour):
			_refused_stock_hour_count += 1
			return _refuse(_stock_hour.error)
	_record_daily_leg(LEG_STOCK_AGE)
	return true


func _apply_season_handover(season: int) -> bool:
	"""ARCH-TICK-003's handover between aging and ecology: REQ-SET-143's winter multiplier."""
	var applied: ResidentsScript.OpResult = _residents.set_winter(season == SEASON_WINTER)
	if not applied.ok:
		return _refuse(applied.error)
	_record_daily_leg(LEG_SEASON_HANDOVER)
	return true


func _update_ecology() -> bool:
	"""ARCH-SYS-005 Ecology: REQ-SET-007's second leg, on the new calendar day (ARCH-TICK-003).

	One call. Fish recovery and the daily fishing quota reset, forage regrowth and decision 0030
	§4.4's quota midnight, every live hive's completed day, and the resource nodes whose regrowth
	date has arrived -- all inside `ecology.gd`, which refuses a replayed day rather than
	applying it twice.
	"""
	if not _ecology.run_day_into(_boundary_tick, _ecology_day):
		return _refuse(_ecology_day.error)
	_record_daily_leg(LEG_ECOLOGY)
	return true


func _advance_crops_and_weather() -> bool:
	"""ARCH-SYS-006 CropWeather, MIDNIGHT half: REQ-SET-007's third leg, after ARCH-SYS-005's.

	The eligibility crossings ARCH-SYS-005 just committed are handed straight over: `ecology.gd`
	refreshed the ORCHARD side of decision 0044's pollination links inside `orchard_hive.gd`, and
	the FARM side needs the plot->tile join only ARCH-SYS-006 can make. Nothing runs between the
	two legs, so that refresh is still synchronous with the change that caused it.
	"""
	if not _crop_weather.run_day_into(
			_boundary_tick, _ecology_day.hive_eligibility_crossings, _crop_day):
		return _refuse(_crop_day.error)
	_record_daily_leg(LEG_CROP_WEATHER)
	return true


func _run_planner_day() -> void:
	"""ARCH-SYS-009's own daily maintenance. NOT a sixth REQ-SET-007 leg, and not logged as one.

	REQ-SET-007 names five legs and job planning is not among them, so this is deliberately
	absent from `daily_leg_at()`: putting it there would make the leg log claim a requirement
	step that the requirement does not contain. What it does is the planner's own midnight --
	settle yesterday's unserved daily services, then mark every owner and every designation dirty
	so the next tick reconciles against the new day's quota. It runs AFTER ARCH-SYS-005 reset
	those quotas, because released quota is R06-JOB-002's trigger and reconciling before the
	reset would find nothing released.

	A refusal is COUNTED, not fatal: the day's ecology and crop legs have already committed.
	"""
	_planner_day = _planner.run_day_boundary(_boundary_tick)
	if _planner_day.ok:
		_planner_day_count += 1
		return
	_refused_planner_day_count += 1
	_last_refusal = REFUSE_PLANNER_DAY


func _record_daily_leg(leg: int) -> void:
	"""Append one executed REQ-SET-007 leg to this boundary's order log."""
	_daily_legs[_daily_leg_count] = leg
	_daily_leg_count += 1


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


func daily_leg_count() -> int:
	"""REQ-SET-007 legs the most recent day boundary actually executed; 0 before the first."""
	return _daily_leg_count


func daily_leg_at(index: int) -> IntMath.IntResult:
	"""The `index`-th leg the most recent boundary executed, in execution order, or a refusal.

	A refusal rather than a sentinel: "no leg ran" and "leg 0 ran" are different answers and a
	returned 0 would be indistinguishable from LEG_STOCK_AGE, which this system never runs.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _daily_leg_count:
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	out.succeed(_daily_legs[index])
	return out


func last_ecology_day() -> int:
	"""Absolute day ARCH-SYS-005 last consumed; 0 before the first midnight. See `ecology.gd`."""
	return _ecology.last_day_run()


func ecology_day() -> EcologyScript.DayResult:
	"""The most recent ecology day's counts. Inspect `.ok` before any field; see `ecology.gd`."""
	return _ecology_day


func crop_weather() -> CropWeatherScript:
	"""ARCH-SYS-006's crop and weather stores. A world generator places its plots here."""
	return _crop_weather


func farming() -> FarmingScript:
	"""The §4.2 FarmPlot store and §2's TileHistory ledger, composed under ARCH-SYS-006."""
	return _crop_weather.farming()


func weather() -> WeatherScript:
	"""The §4.2 single Weather row this settlement schedules and refreshes."""
	return _crop_weather.weather()


func rng() -> RngScript:
	"""The settlement's one ARCH-RNG-002 stream set. UNSEEDED until a world generator seeds it."""
	return _rng


func crop_weather_day() -> CropWeatherScript.DayResult:
	"""The most recent crop/weather day. Inspect `.ok` before any field; see `crop_weather.gd`."""
	return _crop_day


func crop_hour() -> CropWeatherScript.HourResult:
	"""The most recent hourly crop integration. Inspect `.ok` before any field."""
	return _crop_hour


func refused_crop_hour_count() -> int:
	"""Hour crossings whose crop integration refused, so a skipped hour is never silent."""
	return _refused_crop_hour_count


func stock_age() -> StockAgeScript:
	"""ARCH-SYS-004's aging stage. A building layer declares its storage classes here."""
	return _stock_age


func inventory() -> InventoryScript:
	"""The settlement's own InventoryLot/InventoryContainer store, the one ARCH-SYS-004 ages."""
	return _inventory


func item_definitions() -> ItemDefinitionsScript:
	"""The §4.3 item catalog registered into this settlement's inventory."""
	return _item_definitions


func stock_hour() -> StockAgeScript.HourResult:
	"""The most recent hourly aging pass. Inspect `.ok` before any field."""
	return _stock_hour


func refused_stock_hour_count() -> int:
	"""Hour crossings whose aging pass refused, so a skipped hour is never silent."""
	return _refused_stock_hour_count


func refused_extract_count() -> int:
	"""Ticks whose ARCH-SYS-023 snapshot refused, so a missed frame is never silent."""
	return _refused_extract_count


func refused_planner_day_count() -> int:
	"""Midnights whose ARCH-SYS-009 maintenance refused, so a skipped one is never silent."""
	return _refused_planner_day_count


func planner_day_count() -> int:
	"""Midnights on which ARCH-SYS-009's own daily maintenance actually ran and succeeded.

	Counted rather than assumed: with no FarmPlot and no designation the planner's midnight has
	nothing visible to do, so "it ran" would otherwise be indistinguishable from "it was skipped".
	"""
	return _planner_day_count


func tick_stage_measured_count(stage: int) -> IntMath.IntResult:
	"""How many times one stage has been measured since the last reset().

	Every dispatched stage closes its window exactly once per tick, so this equals `ticks_run()`
	for every stage. A stage that stopped being dispatched, or whose window was closed against
	another stage's index, shows up here as a count that no longer matches.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tick_stage(stage):
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	out.succeed(_stage_measured[stage])
	return out


func job_planner() -> JobPlannerScript:
	"""ARCH-SYS-009's producer. The store DESIGNATE_ZONE enables standing demand in."""
	return _planner


func presentation() -> PresentationExtractScript:
	"""ARCH-SYS-023's read-only snapshot. It exposes no store and can write to none."""
	return _presentation


func tick_stage_count() -> int:
	"""How many §5 stages this node measures on the tick path."""
	return TICK_STAGE_COUNT


func is_tick_stage(stage: int) -> bool:
	"""True when this index names one of the measured tick stages."""
	return stage >= 0 and stage < TICK_STAGE_COUNT


func tick_stage_name(stage: int) -> StringName:
	"""The ARCH-SYS system a measured stage dispatches, or the empty name for an unknown index."""
	if not is_tick_stage(stage):
		return REFUSE_NONE
	return TICK_STAGE_KEYS[stage]


func tick_stage_usec_at(stage: int) -> IntMath.IntResult:
	"""Microseconds the MOST RECENT tick spent in one stage, or a refusal for an unknown index.

	A measurement, not a budget: nothing here compares it to REQ-SET-163, which is stated for 256
	residents on a named machine that this has not been run on.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tick_stage(stage):
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	out.succeed(_stage_usec[stage])
	return out


func mean_tick_stage_usec(stage: int) -> IntMath.IntResult:
	"""Mean microseconds per tick in one stage since the last reset(). REFUSES before tick one.

	A mean over zero ticks has no value, and 0 would be a measurement-shaped sentinel -- the same
	rule `mean_tick_usec()` follows.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tick_stage(stage):
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	if _ticks_run <= 0:
		out.refuse(String(REFUSE_NO_TICK_MEASURED))
		return out
	IntMath.floor_div_into(_stage_usec_total[stage], _ticks_run, out)
	return out


func last_refusal() -> StringName:
	"""Reason the most recent refused operation was refused; empty after a successful one."""
	return _last_refusal


func directory() -> EntityDirectoryScript:
	"""The allocator behind every settlement reference."""
	return _directory


func ecology() -> EcologyScript:
	"""ARCH-SYS-005's four stores. A world generator and ARCH-SYS-006 reach the ecology here."""
	return _ecology


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
	"""ARCH-SYS-002's commit stage, WITH the ecology bound: all six implemented kinds commit here.

	`_bind_ecology_to_commands()` calls `bind_ecology()` during composition, so DESIGNATE_ZONE and
	SET_POLICY reach `forage.gd` and `job_planner.gd` instead of refusing COMMAND_STORE_NOT_BOUND.
	The other eighteen ARCH-CMD-003 kinds still refuse COMMAND_UNSUPPORTED_FEATURE and name the
	store they are waiting for.
	"""
	return _dispatch


func commands_committed_last_tick() -> int:
	"""Player commands committed by the most recent CommandCommit stage."""
	return _commands_committed_last_tick


func commands_refused_last_tick() -> int:
	"""Player commands the most recent CommandCommit stage refused, with a documented result id."""
	return _commands_refused_last_tick


func world() -> WorldInitScript:
	"""REQ-SET-009's generator, composed over this settlement's own stores.

	`is_published()` on it answers whether a world has been generated, and its tile readers answer
	what is under a tile. It is a reader here: `create_generated_settlement()` is the only thing
	in this node that calls `generate()`.
	"""
	return _world


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
