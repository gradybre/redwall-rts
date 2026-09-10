extends RefCounted
## ARCH-SYS-009 JobPlanner: the store that turns a service condition into a Job row, plus
## R06-JOB-007's daily FARM tending producer and R06-JOB-004's sowing first-plant producer.
##
## THIS IS THE FIRST THING IN THIS PROJECT THAT CREATES A JOB. `settlement_system.gd`'s header
## has said "NOTHING CREATES JOBS" since the loop was wired; that sentence is corrected there,
## precisely, by this file.
##
## ---------------------------------------------------------------------------------------
## THE THREE CONTRACTS IMPLEMENTED HERE, verbatim from
## `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1:
##
##   R06-JOB-004  "When the player confirms the current crop for an EMPTY plot/field, JobPlanner
##                 shall request its first sowing cycle. Before publishing sowing jobs it shall
##                 apply all REQ-SET-070 gates. Failed plots remain unsown with an explicit
##                 reason; a failed gate does not consume seed. Changing a rotation list without
##                 confirming planting shall not start work."
##
##   R06-JOB-008  "When a relevant policy, stock, season/day, closure, gear, route, reservation
##                 or service condition changes, JobPlanner shall mark the affected owner dirty
##                 and reconcile its demand before selection. Reevaluation shall be idempotent.
##                 Capacity exhaustion shall retain unmet policy demand, report a blocker, and
##                 retry when capacity is released; it shall not create a hidden unbounded
##                 queue."
##
##   R06-JOB-007  "When a GROWING plot enters a new day without completed/pending tending,
##                 JobPlanner shall create its one 1-WU FARM tending service; water is required
##                 only under §5.6's moisture condition."
##
## ARCH-SYS-009 fixes the cadence: "On dirty service conditions; idle selectors every 30 ticks
## staggered by ID."
##
## ---------------------------------------------------------------------------------------
## PENDING-SERVICE IDENTITY IS `(owner EntityRef, operation, absolute service day)`. The ruling
## states it in those words, so it is the schema rather than a paraphrase of one:
##
##     service_row(owner typed row r, operation op) = r * OPERATION_COUNT + op
##
## an owner-major child index in ARCH-MEM-005's sense. The owner class is FarmPlot at its
## already-budgeted 4096 rows.
##
## THE OPERATION DOMAIN IS TWO, AND THE TWO OPERATIONS ARE NOT THE SAME KIND OF THING. The ruling
## splits them in one sentence: "Pending service identity is `(owner EntityRef, operation,
## absolute service day)`; sowing/rotation identity includes the field cycle." So:
##
##   * operation 0, OPERATION_FARM_TEND, is a DAILY SERVICE. It reopens every midnight, it is
##     settled unserved by midnight, and its third identity term is the absolute service day.
##   * operation 1, OPERATION_FARM_SOW, is NOT a daily service. It does not reopen at midnight
##     and it is NEVER settled as an unserved daily service; its third identity term is the FIELD
##     CYCLE, and it lives until it is published, completed, cancelled or its plot is destroyed.
##
## `DAILY_SERVICE_OPERATION_COUNT` IS STILL ONE and now means what its name says: how many of the
## operations reopen daily. `is_daily_service_operation()` is the predicate, the daily operations
## occupy the low ordinals, and `_init()` asserts OPERATION_FARM_SOW is not among them. The three
## places where "daily" is structural -- `_settle_preceding_day()`, `preceding_day_is_settled()`
## and `record_service_completed()` -- all consult that predicate rather than a hard-coded 0.
## R06-JOB-006's 20-WU hive KEEP service and REQ-SET-079/080's orchard care still have NO STORE
## (see DEFERRED below) and are therefore still not budgeted: adding one later is a change to
## OPERATION_COUNT and to nothing else.
##
## ---------------------------------------------------------------------------------------
## THE FIELD CYCLE IS A PER-OWNER ORDINAL THIS MODULE ALLOCATES, AND IT ASSUMES NO FieldPolicy.
## R06-JOB-004's identity term is "the field cycle", and the ruling adds that "any non-derivable
## cycle intent must be included in the schema/budget". There is no `FieldPolicy` store, so there
## is no rotation cursor to read a cycle number out of, and inventing one would be inventing a
## contract. What IS derivable without one is the ORDER of sowing cycles on a plot: cycle 1 is the
## first sowing cycle confirmed on that plot, cycle 2 the next, and so on. `_cycle_cursor` holds
## the last ordinal allocated for an owner and `confirm_first_planting()` is the ONLY writer; the
## ordinal is copied onto the row, so the row's identity is `(owner EntityRef, SOW, field cycle)`
## with every term stored and checked. `_completed_cycle` is the durable completion history the
## ruling forbids discarding.
##
## THE CURSOR NEVER GOES BACKWARDS AND NEVER WRAPS. A confirm at int32's maximum refuses with
## FIELD_CYCLE_OVERFLOW rather than reusing an ordinal that a retained row might still name.
##
## NOTHING HERE ADVANCES A ROTATION. R06-JOB-005 is the rotation producer and stays unbuilt; the
## ruling's own default is `auto_rotation=false`, and "changing a rotation list without confirming
## planting shall not start work" holds here BY CONSTRUCTION, because the only thing that opens a
## sowing cycle is `confirm_first_planting()` and no other entry point writes `_requested_crop`.
##
## ---------------------------------------------------------------------------------------
## REQ-SET-070's FIVE GATES: TWO ARE EVALUATED, THREE HAVE NO STORE AND ARE SAID SO.
##   * CROP SOIL      -- EVALUATED. `farming.is_soil_compatible()` owns §5.6's soil column.
##     Refuses with SOIL_INCOMPATIBLE and the row records REASON_SOIL_INCOMPATIBLE.
##   * PLANTING WINDOW -- EVALUATED. `farming.is_plant_window()` owns §5.6's window column; the
##     season and season-day come from `sim_clock.gd`'s offset calendar, never from `tick/18000`.
##     Refuses with OUTSIDE_PLANT_WINDOW.
##   * SEED SUPPLY    -- NO STORE. `inventory.gd` exposes no seed reservation to this module and
##     ARCH-SYS-006's join does not exist. Following decision 0039's precedent for §5.6's water,
##     the published Job carries `inputs_gate = GATE_UNAVAILABLE`, which `jobs.gd` defines as "the
##     job declares this requirement and the owning system cannot answer" and which REFUSES AT
##     SELECTION. Writing GATE_SATISFIED would fabricate a seed supply.
##   * OUTPUT CAPACITY -- NO STORE. Same gate column, same refusal; §4.2's Job row has no separate
##     output gate, so one is not invented and no ProductionOrder is created.
##   * FIELD CONNECTIVITY -- NO STORE AT ALL. Nothing groups plots into fields and no reachability
##     oracle answers eligibility step 7. It is NOT evaluated and NOT faked; it is named here as
##     an open gate. No sowing can proceed on an unchecked connectivity claim anyway, because the
##     same Job is already ineligible on its UNAVAILABLE inputs gate.
##
## A FAILED GATE CONSUMES NOTHING, and that is decision 0024's allocate-before-consume. The gate
## sweep runs BEFORE `create_job()` and before anything is written except the row's own reason
## byte, so a refused sowing leaves the plot EMPTY, leaves `_seed_committed_milli` where it was,
## and moves no counter. Seed is committed at PRODUCTIVE START and nowhere else -- see below.
##
## ---------------------------------------------------------------------------------------
## SEED IS COMMITTED ONCE, BY `farming.plant()`, THROUGH `record_sowing_started()`.
## READY_06 §6.1: "at PRODUCTIVE START the exact 250 milli-U of seed is committed and the sowing
## WIP created atomically, and the state becomes SOWN". `farming.plant()` IS that instant and it
## RE-APPLIES both evaluable gates itself, so a window that closed between publishing and starting
## refuses there too and still consumes nothing. This module never calls `inventory.gd`: `plant()`
## returns the milli-units and the caller owns the lot, exactly as farming.gd's header states.
## `_seed_committed_milli` is the observable total, and it is the counter the no-consume tests
## watch.
##
## SOWING CANCELLATION HAS TWO REGIMES AND THIS MODULE OWNS THE FIRST.
##   * PRE-COMMITMENT -- `cancel_sowing_request()`. Before productive start the plot is still
##     EMPTY and no seed has moved. The request row is retired and its Job cancelled, which
##     releases the only reservation this build can hold: the Job's bound worker. There is no
##     inventory reservation to release, because no seed reservation was ever made -- the inputs
##     gate says the supply cannot even be answered. The plot is left EMPTY, untouched.
##   * POST-COMMITMENT -- `farming.cancel_sowing()`, which already exists and which this module
##     does not duplicate: seed and WIP discarded, no refund, history preserved. Once the plot is
##     SOWN, `cancel_sowing_request()` REFUSES with SOWING_SEED_ALREADY_COMMITTED and names that
##     other regime instead of silently applying the wrong one. `retire_service(owner, SOW)` is
##     the row-only retirement a caller pairs with it.
##
## WORKER REPLACEMENT PRESERVES THE SAME JOB AND WIP for sowing exactly as for tending: nothing
## on any sowing path touches `remaining_mwu`, and reconciling a published request returns
## SOWING_ALREADY_PENDING with the same Job reference.
##
## THE OWNER GENERATION IS STORED, NOT ASSUMED. `entity_directory.gd` reuses a typed row after a
## destroy, so a service row that recorded only the row index would be inherited by whatever
## plot lands there next. Both halves of the EntityRef are written and both are checked.
##
## THE SERVICE DAY IS AN ABSOLUTE DAY, NOT A BOOLEAN. `sim_clock.gd` decodes a tick through the
## OFFSET calendar, so day 1 runs from tick 0 to 13499 and the first midnight is tick 13500 --
## never `tick % 18000 == 0`. `absolute_day_of_tick()` is `SimClock.day_index_at(tick) + 1` and
## is the only place this module derives a day.
##
## ---------------------------------------------------------------------------------------
## THE PENDING ROW IS SAVED STATE, NOT A DERIVED INDEX -- and that is why it is budgeted.
## The ruling permits rebuilding indexes derived from live jobs and forbids discarding completion
## or policy history. A Job row carries kind, refs, priority, state, created_tick and work; it
## carries NO OPERATION DISCRIMINATOR, so "this FARM job is a tending service rather than a
## REQ-SET-073 harvest" is NOT recoverable from the Job store. The identity the ruling names is
## therefore not derivable, and inventing a discriminator on §4.2's Job row would be inventing a
## schema field. `revalidate_after_load()` is the load-time entry point: it drops pending rows
## whose Job reference no longer resolves and keeps everything else, which is the repair the
## ruling permits, not a reconstruction it does not.
##
## `_serviced_day` -- the absolute day of the last COMPLETED service -- is the completion history
## the ruling says may not be discarded. It survives midnight, a load, a worker replacement and a
## rebuild, and it is what makes "once per day" hold when every other column has been dropped.
##
## THIS MODULE DOES NOT READ `TileHistory.tended_today`, AND THAT IS DELIBERATE. That flag is
## farming.gd's per-day EFFECT state (it halves REQ-SET-087 blight loss and REQ-SET-084 cabbage
## frost) and `farming.clear_tended_today()`'s midnight reset belongs to ARCH-SYS-006, which does
## not exist (increment 10, not started). A boolean nobody resets would suppress every later
## day's service; an absolute day cannot fail that way. `record_service_completed()` is the entry
## point through which a tend performed outside this module's own Job is recorded.
##
## ---------------------------------------------------------------------------------------
## LIFECYCLE AND ORDERING, from the ruling's own paragraph. Daily service work is eligible DURING
## ITS SERVICE DAY. `run_day_boundary()` SETTLES THE PRECEDING DAY BEFORE OPENING THE NEW ONE,
## and that order is structural rather than documented: opening is guarded by the public
## `preceding_day_is_settled()`, so a caller -- or a later edit -- that opens first gets a refusal
## instead of a day of demand layered on an unsettled one. An owner that
## becomes eligible mid-day receives NO RETROACTIVE SERVICE: settlement retires yesterday's row
## and only today's demand is opened. Worker changes preserve the same Job and its WIP, because
## nothing here touches `remaining_mwu` and `jobs.release_worker()` returns the same row to the
## queue.
##
## ---------------------------------------------------------------------------------------
## IDEMPOTENCE IS THE PROPERTY, AND IT IS ENFORCED IN THREE PLACES.
##   1. MARKING. `mark_plot_dirty()` sets a membership BIT before pushing the owner, so N dirty
##      events on one owner produce ONE entry. The dirty set is a fixed 4096-entry stack; it
##      cannot grow, so no sequence of events can build a hidden queue.
##   2. RECONCILING A TEND. `_reconcile_tend()` refuses with SERVICE_PENDING when the row already
##      holds a live Job for `(owner, operation, today)`, and with SERVICE_ALREADY_COMPLETE when
##      `_serviced_day` already names today. Repeated reconciliation of the same owner on the
##      same day therefore creates exactly one service, whatever the caller does.
##   3. CONFIRMING AND RECONCILING A SOWING. `confirm_first_planting()` refuses an owner that
##      already carries a request, so a repeated confirm allocates NO second field cycle and
##      creates no second row; `_reconcile_sow()` refuses with SOWING_ALREADY_PENDING while a live
##      Job covers `(owner, SOW, cycle)`. N confirms and N dirty events produce ONE sowing job.
##
## CAPACITY EXHAUSTION RETAINS DEMAND. When `jobs.create_job()` refuses -- the KIND_JOB arena
## holds 8192 rows -- the service row is written with STATUS_UNMET, carrying the owner and the
## service day, and the directory's own refusal code is recorded as the blocker. That is ONE ROW
## PER OWNER in an array allocated once: retained demand is bounded by construction, which is
## exactly what "shall not create a hidden unbounded queue" asks for. `mark_capacity_released()`
## re-marks every retained row dirty for an explicit retry, and the 30-tick idle sweep retries it
## anyway within one sweep period.
##
## ---------------------------------------------------------------------------------------
## SELECTION IS NOT AUTHORISED HERE, AND NEITHER IS MOVEMENT. A created job is QUEUED. Nothing in
## this file writes JOB_STATE_WORK; the ruling is explicit that "creating a job does not authorize
## teleporting its worker into WORK", and RESERVED -> TRAVEL -> WORK is ARCH-SYS-011/012's, which
## do not exist. The one state this module writes other than the QUEUED a new row already carries
## is JOB_STATE_CANCELLED, on a service its own midnight settlement is retiring.
##
## `OrderMode` IS NOT THE VEHICLE. ONCE/REPEAT/MAINTAIN_STOCK describe `ProductionOrder`, whose
## schema is recipe- and building-based. No plot id is written into a `recipe_id` here and no
## production order is created: daily care is not a production recipe, and the ruling says so.
##
## ---------------------------------------------------------------------------------------
## DEFERRED PRODUCERS -- each named with the store that blocks it, none stubbed:
##   * R06-JOB-001/002 forage demand   -- NOT BLOCKED, deferred to the next phase by scope.
##   * R06-JOB-003 fishing cycles      -- the Expedition store does not exist.
##   * R06-JOB-005 rotation advance    -- `FieldPolicy` does not exist (task 03 increment 7).
##     Nothing here advances a cursor, substitutes a crop or reseeds after a completed cycle.
##   * R06-JOB-006 hive service        -- `Hive` does not exist (task 03 increment 8).
##   * REQ-SET-073 ripe harvest and REQ-SET-085 withered clearing keep their existing route; this
##     module does not reroute them and creates neither.
##
## BLOCKER U2 -- NO COMMAND DELIVERY. R06-JOB-004 begins "when the player confirms", and there is
## no transport for that confirmation: ARCH-CMD-003's command kinds are unimplemented and no
## player command reaches the simulation. `confirm_first_planting()` IS the entry point a command
## handler calls when U2 closes, and it is complete and tested -- but nothing delivers to it, so
## no sowing is confirmed in a running settlement. NO COMMAND KIND IS INVENTED for it and
## ARCH-CMD-003 IS NOT RENUMBERED; the ruling's implementation boundary says to refine the
## existing SET_FIELD_ROTATION/SET_POLICY payloads, which is a change to a document this module
## does not own. Daily tending is condition-driven and needs no confirmation at all. The other
## entry points a command handler would call are `mark_plot_dirty()`, `mark_all_owners_dirty()`,
## `mark_capacity_released()`, `record_service_completed()` and `cancel_sowing_request()`.
##
## BLOCKER -- SOWING WORK HAS NO PERFORMER. `record_sowing_started()` and
## `record_sowing_completed()` are the two seams ARCH-SYS-006 (increment 10) drives when a worker
## actually reaches the plot: the first is READY_06 §6.1's productive start, the second its
## successful completion. This module does not call them itself and does not move a worker: no
## selection happens here, RESERVED -> TRAVEL -> WORK is ARCH-SYS-011/012's, and neither exists.
## Exactly as the tending producer does not call `farming.tend()`, the sowing producer does not
## apply the work's effect on its own; `_settle_pending_sowing()` observing a COMPLETE Job closes
## the CYCLE and leaves the crop state to `farming.begin_growing()`.
##
## BLOCKER -- THE WATER INPUT HAS NO SUPPLIER. §5.6 requires water 0.25 U when a plot is below
## its crop's moisture minimum, and `farming.needs_water()` answers that condition exactly. No
## inventory join exists (ARCH-SYS-006, increment 10), so a service that requires water is
## created with `inputs_gate = GATE_UNAVAILABLE`, which `jobs.gd` defines as "the job declares
## this requirement and the owning system cannot answer" and which refuses at selection. A
## service that requires no water carries GATE_NOT_REQUIRED. Writing GATE_SATISFIED would be
## fabricating a supply; writing GATE_NOT_REQUIRED for a dry plot would be denying a stated input.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. Every column is sized once in `_init()`; `clear()` refills the existing buffers and
## nothing outside `_allocate_columns()` calls `resize()`. The drain, the sweep and the day
## boundary run through `_reconcile_owner()`, which returns an int and allocates NOTHING OF ITS
## OWN, so `run_tick_into()` costs zero objects in this file. The offset calendar is decoded into
## ONE OWNED `SimClock.Calendar` scratch through `calendar_at_into()`, never by allocating one per
## gate check. An owner with no sowing request costs one byte read on the sowing path and nothing
## else. It calls four functions that allocate INSIDE modules this task does not own, each their
## published contract:
##   * `farming.state_of()`   one IntResult per owner reconciled -- farming.gd publishes no
##     `_into` form. Reported, not worked around, and not fixed by editing a file this task does
##     not own; `jobs.gd`'s header records the same cost against `live_job_at()`.
##   * `farming.soil_of()`    one IntResult per sowing gate sweep, for the same reason.
##   * `jobs.state_of()`      one IntResult per PENDING row settled.
##   * `jobs.create_job()`    one OpResult per service created, plus one per `set_source()` and
##     `set_inputs_gate()` call on that same creation.
## The idle sweep walks a fixed 1/30 slice of the 4096 owner rows -- 137 rows -- using
## `farming.is_present()` and this module's own status byte, both allocation-free, and reconciles
## only the rows that are live or already carry a record. At forty plots that is one or two
## reconciles per tick, not 137.
##
## NO PER-TICK DRAIN BUDGET IS INVENTED. ARCH-SYS-009 specifies none. `reconcile_dirty_into()`
## takes the budget as an argument and retains the remainder in the bounded dirty set, and
## `run_tick_into()` passes the structural maximum. The one burst this permits is the tick after
## a midnight, which opens demand for every live owner; that is the specified behaviour of a new
## day, and its bound is the owner capacity, stated here rather than discovered later.
##
## REFUSAL, NOT SENTINELS. `reconcile_plot()` and `reconcile_sowing()` succeed ONLY when they
## created work; every other outcome is an explicit refusal naming which rule declined, so
## "already serviced", "already pending", "not growing", "soil incompatible", "outside the
## planting window" and "job capacity exhausted" are distinguishable answers rather than one
## silent no-op. No reader returns -1 for absence, and no gate CLAMPS: a crop that cannot legally
## be sown today is refused, never planted at the nearest legal moment instead.
##
## THE GATE SWEEP IS ALSO A PUBLIC QUESTION. `sowing_gate_for()` runs the same evaluable gates
## over an arbitrary crop without publishing, confirming or consuming anything, so a UI panel
## asking "why can this plot not be sown?" and the producer that acts on the answer read ONE
## implementation. `service_row_is_clear()` is the row-hygiene predicate `jobs.gd` publishes as
## `inactive_job_row_is_clear()`: a retired row that kept a field cycle would hand the row's next
## occupant someone else's identity.
##
## THE ROW'S OWN REASON IS A BYTE, BECAUSE A StringName CANNOT LIVE IN A PACKED COLUMN. R06-JOB-004
## requires a failed plot to remain unsown "with an explicit reason", and a reason that only
## existed in a return value would be gone by the next reconcile. `_gate_reason` stores it and
## `sowing_refusal_of_reason()` maps it back to the same StringName the refusal carried, so the
## retained reason and the returned one cannot drift.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- the operations, per the pending-service and sowing identities ------------------------------

## R06-JOB-007's 1-WU FARM tending of a GROWING plot: the one DAILY service operation whose owner
## store exists. See DEFERRED in the header for the daily operations that have no store yet.
const OPERATION_FARM_TEND: int = 0
## How many operations reopen every midnight. ONE: only tending is a daily service. The daily
## operations occupy the low ordinals, so `operation < DAILY_SERVICE_OPERATION_COUNT` is the test.
const DAILY_SERVICE_OPERATION_COUNT: int = 1
## R06-JOB-004's sowing cycle. NOT a daily service: it carries a field cycle instead of a service
## day, it does not reopen at midnight, and midnight never settles it as unserved.
const OPERATION_FARM_SOW: int = 1
## The operation stride of `service_row()`. TWO, and only two -- see the header.
const OPERATION_COUNT: int = 2

# --- capacities --------------------------------------------------------------------------------

## The owner class of every operation implemented here. `_init()` asserts this equals both
## farming.gd's capacity and the directory's KIND_FARM_PLOT arena rather than restating a number.
const OWNER_CAPACITY: int = FarmingScript.FARM_PLOT_CAPACITY
## Rows in the pending-service table: one per (owner, operation) pair.
const SERVICE_ROW_COUNT: int = OWNER_CAPACITY * OPERATION_COUNT

# --- pending-service status --------------------------------------------------------------------

## No record: this owner has no service outstanding for any day and no sowing request.
const STATUS_FREE: int = 0
## A Job exists for `(owner, operation, service_day)` or `(owner, SOW, field cycle)`. THIS IS THE
## IDEMPOTENCE GUARD's subject.
const STATUS_PENDING: int = 1
## Policy demand that could not be met because job capacity was exhausted. Retained, not queued.
const STATUS_UNMET: int = 2
## SOWING ONLY: a confirmed field cycle whose gates have not yet let it publish a Job. R06-JOB-004
## keeps a failed plot unsown WITH ITS REASON rather than dropping the player's confirmation.
const STATUS_REQUESTED: int = 3
const STATUS_COUNT: int = 4

## `_service_day` and `_serviced_day` are ABSOLUTE days, which start at 1; 0 means "no day", and
## it is a distinguishable absence rather than a sentinel that could read as a real day.
const NO_DAY: int = 0

# --- the field cycle, R06-JOB-004's third identity term ------------------------------------------

## No cycle has been allocated or completed. Cycles start at 1, so 0 names none.
const NO_CYCLE: int = 0
## The first sowing cycle of a plot.
const FIRST_CYCLE: int = 1
## int32's maximum. A confirm at the cap REFUSES; the cursor never wraps onto a live ordinal.
const MAX_FIELD_CYCLE: int = 2147483647
## §4.2: "empty catalog IDs are -1". A row with no confirmed crop carries farming.gd's own value.
const NO_CROP: int = FarmingScript.CROP_NONE

# --- REQ-SET-070 gate reasons, the `_gate_reason` byte column ------------------------------------

## No gate has refused this row. §4.2: "empty counters/remainders are 0".
const REASON_NONE: int = 0
## The confirmed crop id no longer names a crop.
const REASON_CROP_INVALID: int = 1
## REQ-SET-070's planting-window gate, evaluated by `farming.is_plant_window()`.
const REASON_OUTSIDE_PLANT_WINDOW: int = 2
## The owner is no longer a live FarmPlot.
const REASON_OWNER_NOT_PRESENT: int = 3
## R06-JOB-004 sows an EMPTY plot; anything else is refused rather than overwritten.
const REASON_PLOT_NOT_EMPTY: int = 4
## REQ-SET-070's crop-soil gate, evaluated by `farming.is_soil_compatible()`.
const REASON_SOIL_INCOMPATIBLE: int = 5
const REASON_COUNT: int = 6

# --- the ruling's defaults ---------------------------------------------------------------------

## "Ordinary newly generated work has priority 3, preserving explicit priority-2 ripe harvest and
## existing rescue/urgency rules." This is `Job.priority`, the fourth §5.3 sort term -- NOT the
## urgency bucket, which stays at `jobs.gd`'s URGENCY_ORDINARY default. The two fields carry the
## same number 3 by coincidence and are not the same thing.
const ORDINARY_JOB_PRIORITY: int = 3
## §4.3 JobKind of a tending service. Read from jobs.gd, which reads catalog.gd (decision 0018).
const TENDING_JOB_KIND: int = JobsScript.JOB_KIND_FARM
## Decision 0022: 0 is "no minimum experience". §5.6 states no minimum for tending, so none is
## invented here.
const TENDING_REQUIRED_SKILL: int = 0
## §4.3 JobKind of a sowing cycle. §5.6's sow/tend/harvest are all FARM work.
const SOWING_JOB_KIND: int = JobsScript.JOB_KIND_FARM
## §5.6 states no minimum experience for sowing either, so none is invented.
const SOWING_REQUIRED_SKILL: int = 0

# --- ARCH-SYS-009 cadence ----------------------------------------------------------------------

## "idle selectors every 30 ticks staggered by ID."
const IDLE_SWEEP_INTERVAL_TICKS: int = 30
## The sweep partitions on the owner's TYPED ROW, which is the id that indexes this store and the
## only one readable without a directory call per row. §5.3's resident stagger uses the persistent
## id because a resident is reached through its agent row; ARCH-SYS-009 says only "staggered by
## ID". The difference is stated rather than assumed away: the property the stagger exists for --
## an even 1/30 slice of the owners per tick -- holds under either id.
const STAGGER_MODULUS: int = 30

# --- refusal codes -----------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_OWNER_SLOT: StringName = &"INVALID_OWNER_SLOT"
const REFUSE_INVALID_OPERATION: StringName = &"INVALID_SERVICE_OPERATION"
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_DAY: StringName = &"INVALID_DAY"
const REFUSE_INVALID_BUDGET: StringName = &"INVALID_BUDGET"
const REFUSE_OWNER_NOT_PRESENT: StringName = &"OWNER_NOT_PRESENT"
const REFUSE_NOT_GROWING: StringName = &"PLOT_NOT_GROWING"
const REFUSE_SERVICE_PENDING: StringName = &"SERVICE_ALREADY_PENDING"
const REFUSE_SERVICE_ALREADY_COMPLETE: StringName = &"SERVICE_ALREADY_COMPLETE"
const REFUSE_NO_SERVICE: StringName = &"NO_SERVICE_RECORD"
const REFUSE_DAY_UNSETTLED: StringName = &"PRECEDING_DAY_UNSETTLED"
const REFUSE_JOB_BINDING_FAILED: StringName = &"JOB_BINDING_FAILED"
const REFUSE_NOT_A_DAILY_SERVICE: StringName = &"NOT_A_DAILY_SERVICE"

# --- R06-JOB-004 refusal codes -------------------------------------------------------------------

const REFUSE_INVALID_CROP: StringName = &"INVALID_CROP"
const REFUSE_PLOT_NOT_EMPTY: StringName = &"PLOT_NOT_EMPTY"
const REFUSE_SOIL_INCOMPATIBLE: StringName = &"SOIL_INCOMPATIBLE"
const REFUSE_OUTSIDE_PLANT_WINDOW: StringName = &"OUTSIDE_PLANT_WINDOW"
const REFUSE_NO_SOWING_REQUEST: StringName = &"NO_SOWING_REQUEST"
const REFUSE_SOWING_PENDING: StringName = &"SOWING_ALREADY_PENDING"
const REFUSE_SOWING_REQUESTED: StringName = &"SOWING_ALREADY_REQUESTED"
const REFUSE_SOWING_COMPLETE: StringName = &"SOWING_ALREADY_COMPLETE"
const REFUSE_SOWING_CANCELLED: StringName = &"SOWING_JOB_CANCELLED"
const REFUSE_SOWING_NOT_PENDING: StringName = &"SOWING_NOT_PENDING"
const REFUSE_SOWING_JOB_MISSING: StringName = &"SOWING_JOB_MISSING"
const REFUSE_SOWING_COMMITTED: StringName = &"SOWING_SEED_ALREADY_COMMITTED"
const REFUSE_CYCLE_OVERFLOW: StringName = &"FIELD_CYCLE_OVERFLOW"
const REFUSE_INVALID_GATE_REASON: StringName = &"INVALID_GATE_REASON"

## `_gate_reason` ordinal -> the refusal code the same gate returns. ONE mapping, so the byte kept
## on the row and the StringName handed to the caller cannot disagree. Indexed by REASON_*.
const REASON_REFUSALS: Array[StringName] = [
	REFUSE_NONE, REFUSE_INVALID_CROP, REFUSE_OUTSIDE_PLANT_WINDOW, REFUSE_OWNER_NOT_PRESENT,
	REFUSE_PLOT_NOT_EMPTY, REFUSE_SOIL_INCOMPATIBLE,
]


class OpResult:
	"""Outcome of one planner operation: success flag, refusal code, produced value, reference.

	`.ok` MUST be inspected before `.value` or `.ref` is used. A refusal always carries value 0
	and the null reference, so an ignored refusal cannot surface a plausible-looking job slot.
	"""
	var ok: bool
	var error: StringName
	var value: int
	var ref: Vector2i

	func _init(p_ok: bool, p_error: StringName, p_value: int, p_ref: Vector2i) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value
		ref = p_ref


# --- collaborating stores ----------------------------------------------------------------------

var _farming: FarmingScript = null
var _jobs: JobsScript = null
var _directory: EntityDirectory = null

# --- pending-service columns (ARCH-MEM-001: packed, allocated once) -----------------------------

var _owner_slot: PackedInt32Array = PackedInt32Array()
var _owner_generation: PackedInt32Array = PackedInt32Array()
var _service_day: PackedInt32Array = PackedInt32Array()
var _job_slot: PackedInt32Array = PackedInt32Array()
var _job_generation: PackedInt32Array = PackedInt32Array()
var _serviced_day: PackedInt32Array = PackedInt32Array()
var _status: PackedByteArray = PackedByteArray()
var _requires_water: PackedByteArray = PackedByteArray()

# --- R06-JOB-004's sowing columns (same owner-major table, same allocate-once rule) --------------

## The field cycle this row's request belongs to: the third term of the sowing identity.
var _field_cycle: PackedInt32Array = PackedInt32Array()
## The crop the player confirmed for that cycle. The ruling's "non-derivable cycle intent".
var _requested_crop: PackedInt32Array = PackedInt32Array()
## The REQ-SET-070 gate that last refused this row, so a failed plot keeps its explicit reason.
var _gate_reason: PackedByteArray = PackedByteArray()

# --- per-owner sowing history (OWNER_CAPACITY long, not one per operation) -----------------------

## The last field cycle allocated for this owner. Monotonic; `confirm_first_planting()` is its
## only writer and it never wraps.
var _cycle_cursor: PackedInt32Array = PackedInt32Array()
## The last field cycle whose sowing Job completed. Durable history the ruling forbids discarding.
var _completed_cycle: PackedInt32Array = PackedInt32Array()

# --- the dirty set: a fixed stack plus a membership bit, indexed by owner slot ------------------

var _dirty_rows: PackedInt32Array = PackedInt32Array()
var _is_dirty: PackedByteArray = PackedByteArray()
var _dirty_count: int = 0

# --- observable counters -----------------------------------------------------------------------

var _pending_count: int = 0
var _unmet_count: int = 0
var _created_count: int = 0
var _completed_count: int = 0
var _cancelled_count: int = 0
var _settled_unserved_count: int = 0
var _blocker_count: int = 0
var _dropped_on_load_count: int = 0
var _last_blocker: StringName = REFUSE_NONE
var _requested_count: int = 0
var _sowing_request_count: int = 0
var _sowing_created_count: int = 0
var _sowing_started_count: int = 0
var _sowing_completed_count: int = 0
var _sowing_cancelled_count: int = 0
var _seed_committed_milli: int = 0

# --- scratch (not simulation state) ------------------------------------------------------------

var _math: IntMath.IntResult = IntMath.IntResult.new()
## One owned Calendar, re-decoded through `SimClock.calendar_at_into()`. Every field is read into
## a local before anything else can touch it, so no two live values share this instance.
var _calendar: SimClock.Calendar = SimClock.Calendar.new()


func _init(p_farming: FarmingScript = null, p_jobs: JobsScript = null) -> void:
	"""Bind the farm and job stores, assert every borrowed capacity, and allocate once.

	Passing existing stores shares them; passing nothing builds a consistent private pair in
	which the farm plots and the jobs are allocated from ONE directory, because a service row
	holds an EntityRef to each and two directories could hand out the same reference twice.
	"""
	_jobs = p_jobs if p_jobs != null else JobsScript.new()
	_directory = _jobs.directory()
	_farming = p_farming if p_farming != null else FarmingScript.new(_directory)
	_assert_shared_contracts()
	_allocate_columns()
	clear()


func _assert_shared_contracts() -> void:
	"""Prove the capacities, the shared directory and the enum values this module reads elsewhere."""
	assert(_farming.directory() == _directory,
		"the farm plots and the jobs must be allocated from one entity directory")
	assert(OWNER_CAPACITY == _directory.capacity_of_kind(EntityDirectory.KIND_FARM_PLOT),
		"the owner class must match the directory's KIND_FARM_PLOT capacity")
	assert(SERVICE_ROW_COUNT == OWNER_CAPACITY * OPERATION_COUNT,
		"the pending-service table is one row per (owner, operation) pair")
	assert(TENDING_JOB_KIND == JobsScript.JOB_KIND_FARM,
		"a tending service is a FARM job")
	assert(FarmingScript.TEND_WORK_MILLI_WU == 1000,
		"R06-JOB-007's tending service is one WU, which is 1000 milli-WU")
	_assert_sowing_contracts()


func _assert_sowing_contracts() -> void:
	"""Prove R06-JOB-004's borrowed constants and that sowing is not a daily service operation."""
	assert(OPERATION_FARM_SOW >= DAILY_SERVICE_OPERATION_COUNT,
		"sowing must not sit among the operations midnight reopens and settles")
	assert(OPERATION_FARM_SOW < OPERATION_COUNT,
		"every implemented operation must have a row in the table")
	assert(SOWING_JOB_KIND == JobsScript.JOB_KIND_FARM, "a sowing cycle is a FARM job")
	assert(FarmingScript.SOW_WORK_MILLI_WU == 4000,
		"§5.6's sowing is four WU, which is 4000 milli-WU")
	assert(REASON_REFUSALS.size() == REASON_COUNT,
		"every gate reason must map to exactly one refusal code")
	assert(NO_CROP == FarmingScript.CROP_NONE, "the empty crop id is farming.gd's own")


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	for column: PackedInt32Array in [_owner_slot, _owner_generation, _service_day, _job_slot,
			_job_generation, _serviced_day, _field_cycle, _requested_crop]:
		column.resize(SERVICE_ROW_COUNT)
	for column: PackedByteArray in [_status, _requires_water, _gate_reason]:
		column.resize(SERVICE_ROW_COUNT)
	for column: PackedInt32Array in [_cycle_cursor, _completed_cycle, _dirty_rows]:
		column.resize(OWNER_CAPACITY)
	_is_dirty.resize(OWNER_CAPACITY)


func clear() -> void:
	"""Return every service row and the dirty set to the empty state without reallocating."""
	_owner_slot.fill(EntityDirectory.NULL_SLOT)
	_owner_generation.fill(EntityDirectory.NULL_GENERATION)
	_job_slot.fill(EntityDirectory.NULL_SLOT)
	_job_generation.fill(EntityDirectory.NULL_GENERATION)
	_service_day.fill(NO_DAY)
	_serviced_day.fill(NO_DAY)
	_status.fill(STATUS_FREE)
	_requires_water.fill(0)
	_field_cycle.fill(NO_CYCLE)
	_requested_crop.fill(NO_CROP)
	_gate_reason.fill(REASON_NONE)
	_cycle_cursor.fill(NO_CYCLE)
	_completed_cycle.fill(NO_CYCLE)
	_dirty_rows.fill(0)
	_is_dirty.fill(0)
	_dirty_count = 0
	_pending_count = 0
	_unmet_count = 0
	_requested_count = 0
	_reset_counters()


func _reset_counters() -> void:
	"""Zero the observable outcome counters. Split out to keep clear() under thirty lines."""
	_created_count = 0
	_completed_count = 0
	_cancelled_count = 0
	_settled_unserved_count = 0
	_blocker_count = 0
	_dropped_on_load_count = 0
	_last_blocker = REFUSE_NONE
	_sowing_request_count = 0
	_sowing_created_count = 0
	_sowing_started_count = 0
	_sowing_completed_count = 0
	_sowing_cancelled_count = 0
	_seed_committed_milli = 0


# --- results -----------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refusal. It always carries 0 and the null reference, never a stale number."""
	return OpResult.new(false, code, 0, EntityDirectory.NULL_REF)


func _read(code: StringName, value: int) -> IntMath.IntResult:
	"""Build a reader's IntResult: the value on success, an explicit refusal otherwise."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_read_into(code, value, out)
	return out


func _read_into(code: StringName, value: int, out: IntMath.IntResult) -> bool:
	"""Write a reader's outcome into a caller-owned IntResult (decision 0015)."""
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(value)


# --- collaborators -----------------------------------------------------------------------------

func farming() -> FarmingScript:
	"""The FarmPlot store this planner reconciles."""
	return _farming


func jobs() -> JobsScript:
	"""The Job store this planner creates rows in."""
	return _jobs


func directory() -> EntityDirectory:
	"""The single entity directory both collaborating stores allocate from."""
	return _directory


# --- addressing --------------------------------------------------------------------------------

func is_owner_slot(owner_slot: int) -> bool:
	"""True when the argument addresses a FarmPlot typed row, present or not."""
	return owner_slot >= 0 and owner_slot < OWNER_CAPACITY


func is_operation(operation: int) -> bool:
	"""True when the argument names an operation this build implements."""
	return operation >= 0 and operation < OPERATION_COUNT


func is_daily_service_operation(operation: int) -> bool:
	"""True when this operation reopens every midnight and midnight settles it unserved.

	The ruling separates the two identities, so this predicate is what keeps R06-JOB-004's sowing
	cycle out of R06-JOB-007's daily machinery. The daily operations occupy the low ordinals.
	"""
	return operation >= 0 and operation < DAILY_SERVICE_OPERATION_COUNT


func service_row(owner_slot: int, operation: int) -> IntMath.IntResult:
	"""The pending-service row of `(owner, operation)`, or an explicit refusal.

	`r * OPERATION_COUNT + op`, the owner-major child index of ARCH-MEM-005.
	"""
	if not is_owner_slot(owner_slot):
		return _read(REFUSE_INVALID_OWNER_SLOT, 0)
	if not is_operation(operation):
		return _read(REFUSE_INVALID_OPERATION, 0)
	return _read(REFUSE_NONE, owner_slot * OPERATION_COUNT + operation)


func _row_of(owner_slot: int, operation: int) -> int:
	"""Unchecked `service_row()` for callers that have already validated both arguments."""
	return owner_slot * OPERATION_COUNT + operation


static func absolute_day_of_tick(tick: int) -> int:
	"""The 1-based absolute calendar day containing `tick`, under sim_clock's OFFSET calendar.

	`sim_clock.gd` owns the formula; this is its day index plus one, matching Calendar's own
	`absolute_day`. Never `tick / 18000`: the first midnight is tick 13500.
	"""
	return SimClock.day_index_at(tick) + 1


# --- pending-service readers -------------------------------------------------------------------

func status_of(owner_slot: int, operation: int) -> IntMath.IntResult:
	"""STATUS_FREE, STATUS_PENDING or STATUS_UNMET for one service row."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	status_into(owner_slot, operation, out)
	return out


func status_into(owner_slot: int, operation: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating status_of(), for the reconcile and sweep paths (decision 0015)."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	if not is_operation(operation):
		return out.refuse(String(REFUSE_INVALID_OPERATION))
	return out.succeed(_status[_row_of(owner_slot, operation)])


func service_day_of(owner_slot: int, operation: int) -> IntMath.IntResult:
	"""The absolute day a pending or retained service belongs to; refuses when the row is free."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	service_day_into(owner_slot, operation, out)
	return out


func service_day_into(owner_slot: int, operation: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating service_day_of(). Refuses rather than answering 0 for a free row.

	Refuses a NON-DAILY operation outright: a sowing row's `_service_day` is NO_DAY by
	construction, and answering 0 here would hand a caller a number that reads like a day.
	"""
	if not status_into(owner_slot, operation, out):
		return false
	if not is_daily_service_operation(operation):
		return out.refuse(String(REFUSE_NOT_A_DAILY_SERVICE))
	if out.value == STATUS_FREE:
		return out.refuse(String(REFUSE_NO_SERVICE))
	return out.succeed(_service_day[_row_of(owner_slot, operation)])


func last_serviced_day_of(owner_slot: int, operation: int) -> IntMath.IntResult:
	"""The absolute day of the last COMPLETED service, or NO_DAY when none has completed."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	last_serviced_day_into(owner_slot, operation, out)
	return out


func last_serviced_day_into(owner_slot: int, operation: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating last_serviced_day_of(). NO_DAY is an answer here, not a refusal.

	A non-daily operation refuses: `completed_field_cycle_of()` is sowing's completion history.
	"""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	if not is_operation(operation):
		return out.refuse(String(REFUSE_INVALID_OPERATION))
	if not is_daily_service_operation(operation):
		return out.refuse(String(REFUSE_NOT_A_DAILY_SERVICE))
	return out.succeed(_serviced_day[_row_of(owner_slot, operation)])


func service_job_of(owner_slot: int, operation: int) -> Vector2i:
	"""The Job this service is bound to, or the null reference when there is none."""
	if not is_owner_slot(owner_slot) or not is_operation(operation):
		return EntityDirectory.NULL_REF
	var row: int = _row_of(owner_slot, operation)
	if _status[row] != STATUS_PENDING:
		return EntityDirectory.NULL_REF
	return Vector2i(_job_slot[row], _job_generation[row])


func service_owner_of(owner_slot: int, operation: int) -> Vector2i:
	"""The owner EntityRef the service row recorded, or the null reference when free."""
	if not is_owner_slot(owner_slot) or not is_operation(operation):
		return EntityDirectory.NULL_REF
	var row: int = _row_of(owner_slot, operation)
	if _status[row] == STATUS_FREE:
		return EntityDirectory.NULL_REF
	return Vector2i(_owner_slot[row], _owner_generation[row])


func service_row_is_clear(owner_slot: int, operation: int) -> bool:
	"""True when a FREE row holds no residue of the request or service it used to carry.

	`jobs.gd` publishes `inactive_job_row_is_clear()` for the same reason: a retired row that kept
	a field cycle, an owner reference or a gate reason would hand the row's next occupant someone
	else's identity. A row that is not FREE reports false, because it is not a free row.
	"""
	if not is_owner_slot(owner_slot) or not is_operation(operation):
		return false
	var row: int = _row_of(owner_slot, operation)
	return _status[row] == STATUS_FREE \
		and _owner_slot[row] == EntityDirectory.NULL_SLOT \
		and _owner_generation[row] == EntityDirectory.NULL_GENERATION \
		and _service_day[row] == NO_DAY \
		and _job_slot[row] == EntityDirectory.NULL_SLOT \
		and _job_generation[row] == EntityDirectory.NULL_GENERATION \
		and _requires_water[row] == 0 \
		and _field_cycle[row] == NO_CYCLE \
		and _requested_crop[row] == NO_CROP \
		and _gate_reason[row] == REASON_NONE


func service_requires_water(owner_slot: int, operation: int) -> bool:
	"""True when the recorded service declared §5.6's water input at the moment it was created."""
	if not is_owner_slot(owner_slot) or not is_operation(operation):
		return false
	var row: int = _row_of(owner_slot, operation)
	return _status[row] != STATUS_FREE and _requires_water[row] == 1


# --- observable counters -----------------------------------------------------------------------

func pending_service_count() -> int:
	"""Number of service rows currently holding a live Job."""
	return _pending_count


func unmet_demand_count() -> int:
	"""Number of service rows holding retained demand a capacity refusal could not meet."""
	return _unmet_count


func created_count() -> int:
	"""Total services created since the last clear()."""
	return _created_count


func completed_count() -> int:
	"""Total services recorded as completed since the last clear()."""
	return _completed_count


func cancelled_count() -> int:
	"""Total services whose Job was observed CANCELLED, recorded rather than read as complete."""
	return _cancelled_count


func settled_unserved_count() -> int:
	"""Total services midnight retired without completion: the preceding day's unserved outcome."""
	return _settled_unserved_count


func blocker_count() -> int:
	"""Times capacity exhaustion has been reported since the last clear()."""
	return _blocker_count


func dropped_on_load_count() -> int:
	"""Pending rows revalidate_after_load() dropped because their Job no longer resolved."""
	return _dropped_on_load_count


func last_blocker() -> StringName:
	"""Refusal code of the most recent capacity blocker; empty when none has been reported."""
	return _last_blocker


# --- the dirty set (R06-JOB-008) ---------------------------------------------------------------

func dirty_count() -> int:
	"""Owners currently awaiting reconciliation. Bounded by OWNER_CAPACITY by construction."""
	return _dirty_count


func is_plot_dirty(owner_slot: int) -> bool:
	"""True when this owner is already in the dirty set."""
	return is_owner_slot(owner_slot) and _is_dirty[owner_slot] == 1


func mark_plot_dirty(owner_slot: int) -> OpResult:
	"""Mark one owner's demand for reconciliation. Idempotent: a repeat adds no second entry.

	Accepts an addressable slot whether or not a plot is present, because retiring the record of
	a destroyed owner is itself a reconciliation. Refuses only an out-of-range slot.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if _is_dirty[owner_slot] == 1:
		return _succeed(_dirty_count, EntityDirectory.NULL_REF)
	_is_dirty[owner_slot] = 1
	_dirty_rows[_dirty_count] = owner_slot
	_dirty_count += 1
	return _succeed(_dirty_count, EntityDirectory.NULL_REF)


func mark_all_owners_dirty() -> int:
	"""Mark every live owner, and every owner still carrying a record, dirty. Returns the count."""
	var marked: int = 0
	for owner_slot: int in OWNER_CAPACITY:
		if _farming.is_present(owner_slot) or _owner_carries_a_record(owner_slot):
			if _is_dirty[owner_slot] == 0:
				marked += 1
			mark_plot_dirty(owner_slot)
	return marked


func _owner_carries_a_record(owner_slot: int) -> bool:
	"""True when ANY of this owner's operations still holds a row, sowing included.

	Reading only the tending row here would let a sowing request on a destroyed plot survive
	every sweep and every midnight unreconciled.
	"""
	var row: int = _row_of(owner_slot, 0)
	for operation: int in OPERATION_COUNT:
		if _status[row + operation] != STATUS_FREE:
			return true
	return false


func mark_capacity_released() -> int:
	"""R06-JOB-008's explicit retry: re-mark every retained unmet demand. Returns the count."""
	var marked: int = 0
	for row: int in SERVICE_ROW_COUNT:
		if _status[row] != STATUS_UNMET:
			continue
		var owner_slot: int = row / OPERATION_COUNT
		if _is_dirty[owner_slot] == 0:
			marked += 1
		mark_plot_dirty(owner_slot)
	return marked


func _pop_dirty() -> int:
	"""Remove and return the most recently marked owner, clearing its membership bit."""
	_dirty_count -= 1
	var owner_slot: int = _dirty_rows[_dirty_count]
	_is_dirty[owner_slot] = 0
	return owner_slot


# --- reconciliation (R06-JOB-008) --------------------------------------------------------------

func reconcile_plot(owner_slot: int, tick: int) -> OpResult:
	"""Reconcile one owner's DAILY TENDING demand at `tick`. Succeeds ONLY when one was created.

	Every other outcome is an explicit refusal naming the rule that declined: SERVICE_PENDING and
	SERVICE_ALREADY_COMPLETE are R06-JOB-008's idempotence guards, PLOT_NOT_GROWING and
	OWNER_NOT_PRESENT are R06-JOB-007's condition, and a directory refusal passed through is
	capacity exhaustion with its demand retained. `reconcile_sowing()` is R06-JOB-004's own entry
	point; the drain and the sweep run both through `_reconcile_owner()`.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var code: StringName = _reconcile_tend(owner_slot, tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _succeed(_row_of(owner_slot, OPERATION_FARM_TEND),
		service_job_of(owner_slot, OPERATION_FARM_TEND))


func _reconcile_owner(owner_slot: int, tick: int) -> int:
	"""Reconcile every operation of one owner, returning how many pieces of work were created.

	The order is fixed and stated: the daily tending service first, then the sowing cycle. They
	are independent -- a tending refusal never suppresses a sowing publication and vice versa --
	so the count is 0, 1 or 2 and the caller's budget is spent per OWNER, not per operation.
	"""
	var created: int = 0
	if _reconcile_tend(owner_slot, tick) == REFUSE_NONE:
		created += 1
	if _reconcile_sow(owner_slot, tick) == REFUSE_NONE:
		created += 1
	return created


func _reconcile_tend(owner_slot: int, tick: int) -> StringName:
	"""R06-JOB-007's producer over one owner. Allocates nothing of its own; see the header.

	Order is fixed: settle whatever the row already holds, then apply the completion guard, then
	the growing condition, and only then create. Nothing is written before every gate has passed,
	so a refused reconciliation consumes nothing (decision 0024's allocate-before-consume).
	"""
	var day: int = absolute_day_of_tick(tick)
	var row: int = _row_of(owner_slot, OPERATION_FARM_TEND)
	var code: StringName = _settle_existing(row, owner_slot, day)
	if code != REFUSE_NONE:
		return code
	if _serviced_day[row] == day:
		return REFUSE_SERVICE_ALREADY_COMPLETE
	code = _owner_is_serviceable(owner_slot)
	if code != REFUSE_NONE:
		return code
	return _create_tending_service(owner_slot, row, day, tick)


func _settle_existing(row: int, owner_slot: int, day: int) -> StringName:
	"""Classify whatever the service row already holds, retiring it unless it is still pending.

	Returns REFUSE_SERVICE_PENDING -- the idempotence guard -- only when a live Job already covers
	`(owner, operation, day)`. A record for another day, another owner generation, a vanished Job
	or a CANCELLED one is retired here so the day's demand can be reconsidered exactly once. ALL
	THREE PARTS OF THE IDENTITY ARE CHECKED: dropping the day comparison would let yesterday's
	pending record silently absorb today's demand whenever a midnight boundary was missed.
	"""
	if _status[row] == STATUS_FREE:
		return REFUSE_NONE
	if _owner_generation[row] != _farming.ref_of(owner_slot).y or _service_day[row] != day:
		_retire_unserved(row)
		return REFUSE_NONE
	if _status[row] == STATUS_UNMET:
		_retire_row(row)
		return REFUSE_NONE
	return _settle_pending_job(row, day)


func _retire_unserved(row: int) -> void:
	"""Retire a record that no longer belongs to today's owner and day, cancelling its Job.

	Daily service work is eligible DURING ITS SERVICE DAY, so a record carrying another day -- or
	another generation of the owner row -- is an unserved outcome, not work still in flight. It is
	settled exactly as midnight settles one, whether the boundary ran or a reconcile found it
	first, so no path can leave a Job alive with nothing recording that it exists.
	"""
	if _status[row] == STATUS_PENDING:
		_cancel_job(Vector2i(_job_slot[row], _job_generation[row]))
	_settled_unserved_count += 1
	_retire_row(row)


func _settle_pending_job(row: int, day: int) -> StringName:
	"""Read the pending Job's state and retire the row unless the service is genuinely live."""
	var job_ref: Vector2i = Vector2i(_job_slot[row], _job_generation[row])
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		_retire_row(row)
		return REFUSE_NONE
	var state: IntMath.IntResult = _jobs.state_of(_directory.get_typed_row(job_ref))
	if not state.ok:
		_retire_row(row)
		return REFUSE_NONE
	if state.value == JobsScript.JOB_STATE_COMPLETE:
		_record_completion(row, day, job_ref)
		return REFUSE_NONE
	if state.value == JobsScript.JOB_STATE_CANCELLED:
		_cancelled_count += 1
		_retire_row(row)
		return REFUSE_NONE
	return REFUSE_SERVICE_PENDING


func _record_completion(row: int, day: int, job_ref: Vector2i) -> void:
	"""Record a completed service in the durable history column and release its Job row.

	Destroying the Job is right for tending, which has no output to haul; a producer whose work
	yields a lot must not adopt this rule without examining who owns the completed row.
	"""
	_serviced_day[row] = day
	_completed_count += 1
	_retire_row(row)
	_destroy_job(job_ref)


func _owner_is_serviceable(owner_slot: int) -> StringName:
	"""REFUSE_NONE when the owner is a live plot in GROWING, R06-JOB-007's only trigger state.

	A plot that is EMPTY, SOWN, RIPE or WITHERED creates no tending work, and neither does an
	absent one: ripe harvest and withered clearing keep REQ-SET-073/085's own route.
	"""
	if not _farming.is_present(owner_slot):
		return REFUSE_OWNER_NOT_PRESENT
	var state: IntMath.IntResult = _farming.state_of(owner_slot)
	if not state.ok:
		return REFUSE_OWNER_NOT_PRESENT
	if state.value != FarmingScript.STATE_GROWING:
		return REFUSE_NOT_GROWING
	return REFUSE_NONE


func _create_tending_service(owner_slot: int, row: int, day: int, tick: int) -> StringName:
	"""Create R06-JOB-007's one 1-WU FARM tending Job and record it. Consumes nothing on refusal.

	Capacity exhaustion retains the demand as STATUS_UNMET carrying the owner and the service day,
	and reports the directory's own refusal code as the blocker.
	"""
	var created: JobsScript.OpResult = _jobs.create_job(TENDING_JOB_KIND, ORDINARY_JOB_PRIORITY,
		TENDING_REQUIRED_SKILL, FarmingScript.TEND_WORK_MILLI_WU, tick)
	if not created.ok:
		_retain_unmet_demand(row, owner_slot, day, created.error)
		return created.error
	var water: bool = _farming.needs_water(owner_slot)
	if not _bind_service_job(created.value, owner_slot, water):
		_jobs.destroy_job(created.value)
		return REFUSE_JOB_BINDING_FAILED
	_write_pending_row(row, owner_slot, day, created.ref, water)
	return REFUSE_NONE


func _bind_service_job(job_slot: int, owner_slot: int, water: bool) -> bool:
	"""Point the new Job at its plot and declare §5.6's water input. True when both writes took.

	The plot is the work's SOURCE. `destination` stays null: tending delivers nothing, and no
	reachability oracle exists to answer eligibility step 7 anyway. The water condition is read
	ONCE by the caller and passed here, so the Job's gate and the service row cannot disagree.
	"""
	var source: JobsScript.OpResult = _jobs.set_source(job_slot, _farming.ref_of(owner_slot))
	if not source.ok:
		return false
	var gate: int = JobsScript.GATE_UNAVAILABLE if water else JobsScript.GATE_NOT_REQUIRED
	return _jobs.set_inputs_gate(job_slot, gate).ok


func _write_pending_row(row: int, owner_slot: int, day: int, job_ref: Vector2i,
		water: bool) -> void:
	"""Commit the pending-service identity once its Job exists. The last step, never the first."""
	var owner_ref: Vector2i = _farming.ref_of(owner_slot)
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	_service_day[row] = day
	_job_slot[row] = job_ref.x
	_job_generation[row] = job_ref.y
	_requires_water[row] = 1 if water else 0
	_status[row] = STATUS_PENDING
	_pending_count += 1
	_created_count += 1


func _retain_unmet_demand(row: int, owner_slot: int, day: int, code: StringName) -> void:
	"""R06-JOB-008: keep the unmet demand in its own fixed row and report the blocker.

	One row per owner in an array allocated once, so retained demand cannot grow without bound
	however many times the refusal repeats.
	"""
	var owner_ref: Vector2i = _farming.ref_of(owner_slot)
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	_service_day[row] = day
	_job_slot[row] = EntityDirectory.NULL_SLOT
	_job_generation[row] = EntityDirectory.NULL_GENERATION
	_requires_water[row] = 0
	_status[row] = STATUS_UNMET
	_unmet_count += 1
	_blocker_count += 1
	_last_blocker = code


func _retire_row(row: int) -> void:
	"""Return one row to STATUS_FREE, keeping the durable history in the per-owner columns.

	`_serviced_day`, `_cycle_cursor` and `_completed_cycle` are NOT touched here: they are the
	completion and allocation history the ruling forbids discarding, and they are what keeps
	"once per day" and "never reuse a field cycle" true after every retirement.
	"""
	if _status[row] == STATUS_PENDING:
		_pending_count -= 1
	elif _status[row] == STATUS_UNMET:
		_unmet_count -= 1
	elif _status[row] == STATUS_REQUESTED:
		_requested_count -= 1
	_status[row] = STATUS_FREE
	_owner_slot[row] = EntityDirectory.NULL_SLOT
	_owner_generation[row] = EntityDirectory.NULL_GENERATION
	_service_day[row] = NO_DAY
	_job_slot[row] = EntityDirectory.NULL_SLOT
	_job_generation[row] = EntityDirectory.NULL_GENERATION
	_requires_water[row] = 0
	_field_cycle[row] = NO_CYCLE
	_requested_crop[row] = NO_CROP
	_gate_reason[row] = REASON_NONE


# --- explicit outcome entry points -------------------------------------------------------------

func record_service_completed(owner_slot: int, operation: int, day: int) -> OpResult:
	"""Record that this owner's service for `day` completed, from outside this module's own Job.

	The seam ARCH-SYS-006 uses when a tend is performed by a path that is not a planner Job.
	Refuses a day outside the calendar rather than writing one that would invert every later
	once-per-day test, and refuses a NON-DAILY operation: R06-JOB-004's sowing cycle is closed by
	`record_sowing_completed()` and must never be settled as a day's service.
	"""
	var row: IntMath.IntResult = service_row(owner_slot, operation)
	if not row.ok:
		return _refuse(StringName(row.error))
	if not is_daily_service_operation(operation):
		return _refuse(REFUSE_NOT_A_DAILY_SERVICE)
	if day < 1:
		return _refuse(REFUSE_INVALID_DAY)
	var index: int = row.value
	if _status[index] == STATUS_PENDING:
		_record_completion(index, day, Vector2i(_job_slot[index], _job_generation[index]))
		return _succeed(day, EntityDirectory.NULL_REF)
	_retire_row(index)
	_serviced_day[index] = day
	_completed_count += 1
	return _succeed(day, EntityDirectory.NULL_REF)


func retire_service(owner_slot: int, operation: int) -> OpResult:
	"""Drop this owner's pending record, cancelling its Job. For a caller destroying the owner.

	Completion history is kept: retiring a record is not the same as saying the work was done.
	"""
	var row: IntMath.IntResult = service_row(owner_slot, operation)
	if not row.ok:
		return _refuse(StringName(row.error))
	var index: int = row.value
	if _status[index] == STATUS_FREE:
		return _refuse(REFUSE_NO_SERVICE)
	if _status[index] == STATUS_PENDING:
		_cancel_job(Vector2i(_job_slot[index], _job_generation[index]))
	_retire_row(index)
	return _succeed(index, EntityDirectory.NULL_REF)


func _cancel_job(job_ref: Vector2i) -> bool:
	"""Mark a service Job CANCELLED and release its row. Never writes any other state.

	A bound worker is released first, because `jobs.destroy_job()` refuses while one is held and
	decision 0017 gives departure and cancellation separate paths; nothing here touches
	`remaining_mwu`, so a worker change preserves the Job's work in progress.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return false
	var job_slot: int = _directory.get_typed_row(job_ref)
	var worker: Vector2i = _jobs.worker_of(job_slot)
	if worker != EntityDirectory.NULL_REF:
		_jobs.release_worker(_directory.get_typed_row(worker))
	_jobs.set_state(job_slot, JobsScript.JOB_STATE_CANCELLED)
	return _jobs.destroy_job(job_slot).ok


func _destroy_job(job_ref: Vector2i) -> bool:
	"""Release a completed service's Job row, freeing its slot in the 8192-row KIND_JOB arena."""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return false
	var job_slot: int = _directory.get_typed_row(job_ref)
	var worker: Vector2i = _jobs.worker_of(job_slot)
	if worker != EntityDirectory.NULL_REF:
		_jobs.release_worker(_directory.get_typed_row(worker))
	return _jobs.destroy_job(job_slot).ok


# --- the drain, the sweep and the tick ---------------------------------------------------------

func reconcile_dirty(tick: int, budget: int) -> IntMath.IntResult:
	"""Reconcile up to `budget` dirty owners, returning the number of services created."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	reconcile_dirty_into(tick, budget, out)
	return out


func reconcile_dirty_into(tick: int, budget: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating reconcile_dirty(). The unspent remainder stays in the bounded dirty set.

	No per-tick budget is invented: ARCH-SYS-009 specifies none, so the caller states one and
	`run_tick_into()` passes the structural maximum.
	"""
	if tick < 0:
		return out.refuse(String(REFUSE_INVALID_TICK))
	if budget < 0:
		return out.refuse(String(REFUSE_INVALID_BUDGET))
	var created: int = 0
	var spent: int = 0
	while spent < budget and _dirty_count > 0:
		created += _reconcile_owner(_pop_dirty(), tick)
		spent += 1
	return out.succeed(created)


func run_idle_sweep(tick: int) -> IntMath.IntResult:
	"""Reconcile this tick's staggered 1/30 slice of the owners, returning services created."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	run_idle_sweep_into(tick, out)
	return out


func run_idle_sweep_into(tick: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating run_idle_sweep(): ARCH-SYS-009's "idle selectors every 30 ticks".

	Walks a fixed slice of the owner rows and reconciles only those that are live or already
	carry a record, so an empty settlement costs a bounded integer walk and nothing else.
	"""
	if tick < 0:
		return out.refuse(String(REFUSE_INVALID_TICK))
	var created: int = 0
	var owner_slot: int = tick % STAGGER_MODULUS
	while owner_slot < OWNER_CAPACITY:
		if _farming.is_present(owner_slot) or _owner_carries_a_record(owner_slot):
			created += _reconcile_owner(owner_slot, tick)
		owner_slot += STAGGER_MODULUS
	return out.succeed(created)


func run_tick(tick: int) -> IntMath.IntResult:
	"""Run one planner tick: drain the dirty set, then this tick's idle slice."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	run_tick_into(tick, out)
	return out


func run_tick_into(tick: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating run_tick(). Dirty conditions are reconciled BEFORE the idle sweep.

	R06-JOB-008 requires an owner's demand to be reconciled "before selection", and selection is
	`jobs.evaluate()` on the same tick; the sweep then catches anything no event marked.
	"""
	if not reconcile_dirty_into(tick, SERVICE_ROW_COUNT, out):
		return false
	var drained: int = out.value
	if not run_idle_sweep_into(tick, out):
		return false
	return out.succeed(drained + out.value)


# --- the daily boundary ------------------------------------------------------------------------

func run_day_boundary(tick: int) -> OpResult:
	"""Settle the preceding day's service outcome, THEN open the new day's demand.

	The ruling's ordering, made structural: opening is guarded by `preceding_day_is_settled()`,
	so reversing these two statements produces a refusal rather than a new day of demand layered
	on an unsettled one. Creation itself belongs to the reconcile that follows; this only opens
	the demand.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var day: int = absolute_day_of_tick(tick)
	var settled: int = _settle_preceding_day(day)
	if not preceding_day_is_settled(day):
		return _refuse(REFUSE_DAY_UNSETTLED)
	mark_all_owners_dirty()
	return _succeed(settled, EntityDirectory.NULL_REF)


func _settle_preceding_day(day: int) -> int:
	"""Retire every DAILY service row older than `day`, cancelling any Job that never completed.

	No retroactive service: an owner that becomes eligible mid-day is reconciled against today,
	and yesterday's unfinished work does not survive into it. R06-JOB-004's sowing rows are
	SKIPPED -- their identity carries a field cycle, not a service day, so midnight neither
	reopens nor settles them, and a sowing cycle spanning a midnight keeps its Job and its WIP.
	"""
	if _pending_count == 0 and _unmet_count == 0:
		return 0
	var settled: int = 0
	for row: int in SERVICE_ROW_COUNT:
		if not is_daily_service_operation(row % OPERATION_COUNT):
			continue
		if _status[row] == STATUS_FREE or _service_day[row] >= day:
			continue
		_retire_unserved(row)
		settled += 1
	return settled


func preceding_day_is_settled(day: int) -> bool:
	"""True when no DAILY service row still carries a service day earlier than `day`.

	`run_day_boundary()` consults this BETWEEN settling and opening, so the ruling's ordering is
	a checked precondition of opening demand rather than a comment about statement order. Sowing
	rows are skipped for the same reason `_settle_preceding_day()` skips them: their `_service_day`
	is NO_DAY by construction, and counting it as "earlier than today" would make every day
	unsettleable the moment one plot was waiting to be sown.
	"""
	for row: int in SERVICE_ROW_COUNT:
		if not is_daily_service_operation(row % OPERATION_COUNT):
			continue
		if _status[row] != STATUS_FREE and _service_day[row] < day:
			return false
	return true


# --- load-time repair --------------------------------------------------------------------------

func revalidate_after_load() -> IntMath.IntResult:
	"""Drop pending rows whose Job no longer resolves; keep every other column. Returns the drops.

	The repair the ruling permits for an index over live jobs. Completion history is untouched --
	`_serviced_day`, `_cycle_cursor` and `_completed_cycle` are what keep "once per day" and "never
	reuse a field cycle" true across a load even when every pending row has gone -- and an unmet or
	REQUESTED row is kept, because retained demand and a player's confirmed sowing intent are
	policy state rather than pointers into the Job store. Both operations are repaired the same
	way: a sowing row whose Job no longer resolves is dropped, and its owner must be confirmed
	again, which is the same answer the reconcile sweep gives.
	"""
	var dropped: int = 0
	for row: int in SERVICE_ROW_COUNT:
		if _status[row] != STATUS_PENDING:
			continue
		if _directory.is_valid_of_kind(Vector2i(_job_slot[row], _job_generation[row]),
				EntityDirectory.KIND_JOB):
			continue
		_retire_row(row)
		dropped += 1
	_dropped_on_load_count += dropped
	return _read(REFUSE_NONE, dropped)


# --- R06-JOB-004: the sowing first-plant producer -------------------------------------------------

func confirm_first_planting(owner_slot: int, crop_id: int) -> OpResult:
	"""R06-JOB-004's player confirmation: open a sowing cycle for an EMPTY plot. Returns the cycle.

	This is the entry point BLOCKER U2 has no transport for; nothing delivers a player command to
	it yet. It records the intent and marks the owner dirty -- it publishes nothing itself, because
	REQ-SET-070's gates are applied by the reconcile that follows, "before publishing sowing jobs".
	A repeated confirm REFUSES and allocates no second field cycle, so N confirms open one cycle.
	Allocate before consume: the cursor advances only after every check has passed.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if not _farming.is_crop(crop_id):
		return _refuse(REFUSE_INVALID_CROP)
	if not _farming.is_present(owner_slot):
		return _refuse(REFUSE_OWNER_NOT_PRESENT)
	var state: IntMath.IntResult = _farming.state_of(owner_slot)
	if not state.ok or state.value != FarmingScript.STATE_EMPTY:
		return _refuse(REFUSE_PLOT_NOT_EMPTY)
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	var outstanding: StringName = _outstanding_request_code(row)
	if outstanding != REFUSE_NONE:
		return _refuse(outstanding)
	if not can_allocate_field_cycle(_cycle_cursor[owner_slot]):
		return _refuse(REFUSE_CYCLE_OVERFLOW)
	var cycle: int = _cycle_cursor[owner_slot] + 1
	_write_requested_row(row, owner_slot, crop_id, cycle)
	mark_plot_dirty(owner_slot)
	return _succeed(cycle, _farming.ref_of(owner_slot))


static func can_allocate_field_cycle(cursor: int) -> bool:
	"""True when one more field cycle fits above `cursor` without leaving int32.

	The cap REFUSES rather than wrapping: a wrapped ordinal could name a cycle a retained row
	still carries, and this codebase has already been bitten by an overflow sentinel that a merge
	gate accepted. Public and static so the boundary is testable without 2^31 confirmations.
	"""
	return cursor >= NO_CYCLE and cursor < MAX_FIELD_CYCLE


func _outstanding_request_code(row: int) -> StringName:
	"""The refusal a second confirm on this row earns, or REFUSE_NONE when the row is free."""
	if _status[row] == STATUS_PENDING:
		return REFUSE_SOWING_PENDING
	if _status[row] == STATUS_REQUESTED or _status[row] == STATUS_UNMET:
		return REFUSE_SOWING_REQUESTED
	return REFUSE_NONE


func _write_requested_row(row: int, owner_slot: int, crop_id: int, cycle: int) -> void:
	"""Commit one confirmed sowing cycle: the identity, the crop intent, and the cursor.

	The owner EntityRef is stored in full, both halves, for the same reason the tending row stores
	it: a reused plot row must not inherit the previous plot's confirmed crop.
	"""
	var owner_ref: Vector2i = _farming.ref_of(owner_slot)
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	_service_day[row] = NO_DAY
	_job_slot[row] = EntityDirectory.NULL_SLOT
	_job_generation[row] = EntityDirectory.NULL_GENERATION
	_requires_water[row] = 0
	_field_cycle[row] = cycle
	_requested_crop[row] = crop_id
	_gate_reason[row] = REASON_NONE
	_status[row] = STATUS_REQUESTED
	_requested_count += 1
	_cycle_cursor[owner_slot] = cycle
	_sowing_request_count += 1


func reconcile_sowing(owner_slot: int, tick: int) -> OpResult:
	"""Reconcile one owner's sowing demand at `tick`. Succeeds ONLY when a sowing Job was created.

	Every other outcome names its rule: NO_SOWING_REQUEST when nothing was confirmed,
	SOWING_ALREADY_PENDING for the idempotence guard, one gate code per REQ-SET-070 gate that
	refused, and a directory refusal passed through for capacity exhaustion.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var code: StringName = _reconcile_sow(owner_slot, tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _succeed(_row_of(owner_slot, OPERATION_FARM_SOW),
		service_job_of(owner_slot, OPERATION_FARM_SOW))


func _reconcile_sow(owner_slot: int, tick: int) -> StringName:
	"""R06-JOB-004's producer over one owner. Allocates nothing of its own; see the header.

	Order is fixed: settle whatever the row holds, then apply every evaluable REQ-SET-070 gate,
	and only then create. NOTHING IS CONSUMED BEFORE EVERY GATE HAS PASSED -- a refusal writes the
	row's reason byte and moves no counter, no crop and no seed (decision 0024).
	"""
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	if _status[row] == STATUS_FREE:
		return REFUSE_NO_SOWING_REQUEST
	var code: StringName = _settle_existing_sowing(row, owner_slot)
	if code != REFUSE_NONE:
		return code
	var reason: int = _sowing_gate(owner_slot, _requested_crop[row], tick)
	if reason != REASON_NONE:
		_gate_reason[row] = reason
		return REASON_REFUSALS[reason]
	_gate_reason[row] = REASON_NONE
	return _create_sowing_job(owner_slot, row, tick)


func _settle_existing_sowing(row: int, owner_slot: int) -> StringName:
	"""Classify whatever the sowing row holds. REFUSE_NONE means "evaluate the gates now".

	A request whose owner has gone -- destroyed, or its row reused by a different plot -- is
	abandoned here rather than inherited: BOTH HALVES OF THE OWNER EntityRef ARE CHECKED, so a
	redrawn plot starts with no confirmed crop and must be confirmed again.
	"""
	if not _farming.is_present(owner_slot) \
			or _owner_generation[row] != _farming.ref_of(owner_slot).y:
		_abandon_sowing(row)
		return REFUSE_NO_SOWING_REQUEST
	if _status[row] != STATUS_PENDING:
		return REFUSE_NONE
	return _settle_pending_sowing(row, owner_slot)


func _settle_pending_sowing(row: int, owner_slot: int) -> StringName:
	"""Read the published sowing Job's state and close the cycle unless it is genuinely live.

	The still-live answer is SOWING_ALREADY_PENDING, and it is the idempotence guard: the SAME
	Job reference and the same `remaining_mwu` come back however often this runs, which is why a
	worker replacement costs nothing here.
	"""
	var job_ref: Vector2i = Vector2i(_job_slot[row], _job_generation[row])
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		_retire_row(row)
		return REFUSE_NO_SOWING_REQUEST
	var state: IntMath.IntResult = _jobs.state_of(_directory.get_typed_row(job_ref))
	if not state.ok:
		_retire_row(row)
		return REFUSE_NO_SOWING_REQUEST
	if state.value == JobsScript.JOB_STATE_COMPLETE:
		_close_sowing_cycle(row, owner_slot, job_ref)
		return REFUSE_SOWING_COMPLETE
	if state.value == JobsScript.JOB_STATE_CANCELLED:
		_sowing_cancelled_count += 1
		_retire_row(row)
		return REFUSE_SOWING_CANCELLED
	return REFUSE_SOWING_PENDING


func _abandon_sowing(row: int) -> void:
	"""Drop a request whose owner no longer exists, cancelling its Job so none is left orphaned."""
	if _status[row] == STATUS_PENDING:
		_cancel_job(Vector2i(_job_slot[row], _job_generation[row]))
	_sowing_cancelled_count += 1
	_retire_row(row)


func _close_sowing_cycle(row: int, owner_slot: int, job_ref: Vector2i) -> void:
	"""Record a completed field cycle in the durable per-owner history and release its Job row.

	The CROP STATE is not touched: SOWN -> GROWING is `farming.begin_growing()`, exactly as a
	completed tending service does not call `farming.tend()` from here. `record_sowing_completed()`
	is the entry point that performs both steps together.
	"""
	_completed_cycle[owner_slot] = _field_cycle[row]
	_sowing_completed_count += 1
	_retire_row(row)
	_destroy_job(job_ref)


func sowing_gate_for(owner_slot: int, crop_id: int, tick: int) -> IntMath.IntResult:
	"""The REQ-SET-070 gate that would refuse sowing `crop_id` here now; REASON_NONE if none would.

	A pure question with no side effect: it publishes nothing, confirms nothing and consumes
	nothing, so a caller -- a UI panel asking "why can this plot not be sown?", or a command
	handler pre-checking a confirmation -- gets the same answer the producer would act on, from
	the same code. It answers only for the two gates with an owning store; see `_sowing_gate()`.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	sowing_gate_for_into(owner_slot, crop_id, tick, out)
	return out


func sowing_gate_for_into(owner_slot: int, crop_id: int, tick: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating sowing_gate_for(). A gate that refuses is an ANSWER here, not a refusal."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	if tick < 0:
		return out.refuse(String(REFUSE_INVALID_TICK))
	return out.succeed(_sowing_gate(owner_slot, crop_id, tick))


func _sowing_gate(owner_slot: int, crop: int, tick: int) -> int:
	"""REQ-SET-070's evaluable gates over one crop on one plot. REASON_NONE means all of them pass.

	Two of the five gates have an owning store and are really evaluated here: crop soil and the
	planting window. Seed supply and output capacity have NO store and are declared on the
	published Job as GATE_UNAVAILABLE; field connectivity has no field-grouping store at all. See
	the header -- none of the three is faked, and none of them is answered here.
	"""
	if not _farming.is_present(owner_slot):
		return REASON_OWNER_NOT_PRESENT
	if not _farming.is_crop(crop):
		return REASON_CROP_INVALID
	var state: IntMath.IntResult = _farming.state_of(owner_slot)
	if not state.ok or state.value != FarmingScript.STATE_EMPTY:
		return REASON_PLOT_NOT_EMPTY
	var soil: IntMath.IntResult = _farming.soil_of(owner_slot)
	if not soil.ok or not _farming.is_soil_compatible(crop, soil.value):
		return REASON_SOIL_INCOMPATIBLE
	SimClock.calendar_at_into(tick, _calendar)
	if not _farming.is_plant_window(crop, _calendar.season, _calendar.season_day):
		return REASON_OUTSIDE_PLANT_WINDOW
	return REASON_NONE


func _create_sowing_job(owner_slot: int, row: int, tick: int) -> StringName:
	"""Publish §5.6's 4-WU FARM sowing Job for a gated cycle. Consumes nothing on refusal.

	Capacity exhaustion retains the demand as STATUS_UNMET carrying the owner and its field cycle,
	and reports the directory's own refusal code as the blocker -- one row per owner, so a
	thousand refusals still hold one row.
	"""
	var created: JobsScript.OpResult = _jobs.create_job(SOWING_JOB_KIND, ORDINARY_JOB_PRIORITY,
		SOWING_REQUIRED_SKILL, FarmingScript.SOW_WORK_MILLI_WU, tick)
	if not created.ok:
		_retain_unmet_sowing(row, created.error)
		return created.error
	if not _bind_sowing_job(created.value, owner_slot):
		_jobs.destroy_job(created.value)
		return REFUSE_JOB_BINDING_FAILED
	_publish_sowing_row(row, created.ref)
	return REFUSE_NONE


func _bind_sowing_job(job_slot: int, owner_slot: int) -> bool:
	"""Point the new Job at its plot and declare the two storeless gates. True when both writes took.

	The plot is the work's SOURCE. `destination` stays null: sowing delivers nothing. The inputs
	gate is GATE_UNAVAILABLE because REQ-SET-070's seed supply and output capacity have no owning
	store -- jobs.gd reads that as "the job declares this requirement and the owning system cannot
	answer", so the Job REFUSES AT SELECTION instead of claiming a seed supply that nothing checked.
	"""
	var source: JobsScript.OpResult = _jobs.set_source(job_slot, _farming.ref_of(owner_slot))
	if not source.ok:
		return false
	return _jobs.set_inputs_gate(job_slot, JobsScript.GATE_UNAVAILABLE).ok


func _publish_sowing_row(row: int, job_ref: Vector2i) -> void:
	"""Bind the confirmed cycle to its Job. The last step of publication, never the first.

	The field cycle and the crop are NOT rewritten: this is the same request the player confirmed,
	now carrying a Job, so a retried publication after a capacity blocker keeps its own identity.
	"""
	if _status[row] == STATUS_UNMET:
		_unmet_count -= 1
	elif _status[row] == STATUS_REQUESTED:
		_requested_count -= 1
	_job_slot[row] = job_ref.x
	_job_generation[row] = job_ref.y
	_gate_reason[row] = REASON_NONE
	_status[row] = STATUS_PENDING
	_pending_count += 1
	_sowing_created_count += 1


func _retain_unmet_sowing(row: int, code: StringName) -> void:
	"""R06-JOB-008: keep an unpublishable cycle in its own fixed row and report the blocker."""
	if _status[row] == STATUS_REQUESTED:
		_requested_count -= 1
		_unmet_count += 1
		_status[row] = STATUS_UNMET
	_blocker_count += 1
	_last_blocker = code


# --- R06-JOB-004: seed commitment and the two cancellation regimes --------------------------------

func record_sowing_started(owner_slot: int, tick: int) -> OpResult:
	"""READY_06 §6.1's PRODUCTIVE START. Returns the seed milli-units REQ-SET-071 must consume.

	The seam ARCH-SYS-006 drives when a worker reaches the plot; nothing in this module calls it,
	because no selection or movement exists. `farming.plant()` is the only seed commitment in the
	build and it RE-APPLIES the soil and window gates itself, so a window that closed since the
	Job was published refuses HERE too and commits nothing. NO INVENTORY LOT IS TOUCHED: the
	quantity is returned and `inventory.gd` owns the lot.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	var code: StringName = _published_cycle_code(row)
	if code != REFUSE_NONE:
		return _refuse(code)
	SimClock.calendar_at_into(tick, _calendar)
	var planted: FarmingScript.OpResult = _farming.plant(owner_slot, _requested_crop[row],
		absolute_day_of_tick(tick), _calendar.season, _calendar.season_day)
	if not planted.ok:
		return _refuse(planted.error)
	_seed_committed_milli += planted.value
	_sowing_started_count += 1
	return _succeed(planted.value, planted.ref)


func _published_cycle_code(row: int) -> StringName:
	"""REFUSE_NONE when this row holds a published cycle whose Job still resolves.

	The two refusals are DISTINGUISHABLE and deliberately so: SOWING_NOT_PENDING means this owner
	never published a cycle, SOWING_JOB_MISSING means the cycle it published has lost its Job.
	Collapsing them would make the status guard invisible, because an unpublished row's Job
	reference is null anyway -- and an invisible guard is one a later edit deletes for free.
	"""
	if _status[row] != STATUS_PENDING:
		return REFUSE_SOWING_NOT_PENDING
	if not _directory.is_valid_of_kind(Vector2i(_job_slot[row], _job_generation[row]),
			EntityDirectory.KIND_JOB):
		return REFUSE_SOWING_JOB_MISSING
	return REFUSE_NONE


func record_sowing_completed(owner_slot: int) -> OpResult:
	"""SUCCESSFUL sowing completion: move the plot to GROWING and close its field cycle.

	READY_06 §6.1: "only SUCCESSFUL sowing completion enters GROWING". Allocate before consume --
	`farming.begin_growing()` runs FIRST and its refusal is passed straight back, so a cycle is
	never recorded as complete on a plot that never reached SOWN.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	if _status[row] != STATUS_PENDING:
		return _refuse(REFUSE_SOWING_NOT_PENDING)
	var grown: FarmingScript.OpResult = _farming.begin_growing(owner_slot)
	if not grown.ok:
		return _refuse(grown.error)
	var cycle: int = _field_cycle[row]
	_close_sowing_cycle(row, owner_slot, Vector2i(_job_slot[row], _job_generation[row]))
	return _succeed(cycle, grown.ref)


func cancel_sowing_request(owner_slot: int) -> OpResult:
	"""READY_06 §6.1's PRE-COMMITMENT cancellation. Returns the cancelled field cycle.

	Before productive start the plot is still EMPTY and no seed has moved, so this releases the
	reservations the request holds and leaves the plot exactly as it was: NO SEED LOSS, no crop, no
	fertility or history change. The only reservation this build can hold is the Job's bound
	worker, released by `_cancel_job()`; no seed reservation was ever made, because the inputs gate
	says the supply cannot even be answered.

	A plot that is already SOWN REFUSES with SOWING_SEED_ALREADY_COMMITTED. That is the OTHER
	regime, and it belongs to `farming.cancel_sowing()` -- which discards the seed with no refund.
	Applying the wrong regime silently would either refund seed the ruling says is gone or destroy
	seed that was never committed.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	if _status[row] == STATUS_FREE:
		return _refuse(REFUSE_NO_SOWING_REQUEST)
	if _farming.is_sowing(owner_slot):
		return _refuse(REFUSE_SOWING_COMMITTED)
	var cycle: int = _field_cycle[row]
	if _status[row] == STATUS_PENDING:
		_cancel_job(Vector2i(_job_slot[row], _job_generation[row]))
	_sowing_cancelled_count += 1
	_retire_row(row)
	return _succeed(cycle, _farming.ref_of(owner_slot))


# --- R06-JOB-004 readers -------------------------------------------------------------------------

func sowing_crop_of(owner_slot: int) -> IntMath.IntResult:
	"""The crop this owner's confirmed cycle sows; refuses when no cycle is outstanding."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	sowing_crop_into(owner_slot, out)
	return out


func sowing_crop_into(owner_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating sowing_crop_of() (decision 0015)."""
	return _sowing_column_into(owner_slot, _requested_crop, out)


func sowing_field_cycle_of(owner_slot: int) -> IntMath.IntResult:
	"""The field cycle of this owner's outstanding request: the third term of its identity."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	sowing_field_cycle_into(owner_slot, out)
	return out


func sowing_field_cycle_into(owner_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating sowing_field_cycle_of()."""
	return _sowing_column_into(owner_slot, _field_cycle, out)


func _sowing_column_into(owner_slot: int, column: PackedInt32Array,
		out: IntMath.IntResult) -> bool:
	"""Read one sowing column, refusing an unaddressable owner and a row with no request."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	if _status[row] == STATUS_FREE:
		return out.refuse(String(REFUSE_NO_SOWING_REQUEST))
	return out.succeed(column[row])


func sowing_gate_reason_of(owner_slot: int) -> IntMath.IntResult:
	"""The REQ-SET-070 gate that last refused this owner's cycle: R06-JOB-004's explicit reason."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	sowing_gate_reason_into(owner_slot, out)
	return out


func sowing_gate_reason_into(owner_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating sowing_gate_reason_of(). REASON_NONE is an answer, not a refusal."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	var row: int = _row_of(owner_slot, OPERATION_FARM_SOW)
	if _status[row] == STATUS_FREE:
		return out.refuse(String(REFUSE_NO_SOWING_REQUEST))
	return out.succeed(_gate_reason[row])


func sowing_refusal_of_reason(reason: int) -> StringName:
	"""The refusal code a stored gate reason names, so the row and the return value agree."""
	if reason < 0 or reason >= REASON_COUNT:
		return REFUSE_INVALID_GATE_REASON
	return REASON_REFUSALS[reason]


func allocated_field_cycle_of(owner_slot: int) -> IntMath.IntResult:
	"""The last field cycle allocated for this owner. NO_CYCLE when none ever was."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	allocated_field_cycle_into(owner_slot, out)
	return out


func allocated_field_cycle_into(owner_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating allocated_field_cycle_of()."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	return out.succeed(_cycle_cursor[owner_slot])


func completed_field_cycle_of(owner_slot: int) -> IntMath.IntResult:
	"""The last field cycle whose sowing completed: sowing's durable completion history."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	completed_field_cycle_into(owner_slot, out)
	return out


func completed_field_cycle_into(owner_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating completed_field_cycle_of()."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	return out.succeed(_completed_cycle[owner_slot])


func requested_sowing_count() -> int:
	"""Rows holding a confirmed cycle that has not yet published a Job."""
	return _requested_count


func sowing_confirmed_count() -> int:
	"""Total sowing cycles confirmed since the last clear()."""
	return _sowing_request_count


func sowing_created_count() -> int:
	"""Total sowing Jobs published since the last clear()."""
	return _sowing_created_count


func sowing_started_count() -> int:
	"""Total productive starts recorded, each of which committed its crop's seed."""
	return _sowing_started_count


func sowing_completed_count() -> int:
	"""Total field cycles whose sowing completed successfully."""
	return _sowing_completed_count


func sowing_cancelled_count() -> int:
	"""Total sowing cycles cancelled, abandoned with their owner, or found CANCELLED."""
	return _sowing_cancelled_count


func seed_committed_milli() -> int:
	"""Total seed in milli-units this planner has caused `farming.plant()` to commit.

	The counter the no-consume tests watch: a refused gate never moves it.
	"""
	return _seed_committed_milli
