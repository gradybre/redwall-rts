extends RefCounted
## ARCH-SYS-009 JobPlanner: the store that turns a service condition into a Job row, plus
## R06-JOB-007's daily FARM tending producer.
##
## THIS IS THE FIRST THING IN THIS PROJECT THAT CREATES A JOB. `settlement_system.gd`'s header
## has said "NOTHING CREATES JOBS" since the loop was wired; that sentence is corrected there,
## precisely, by this file.
##
## ---------------------------------------------------------------------------------------
## THE TWO CONTRACTS IMPLEMENTED HERE, verbatim from
## `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1:
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
##     service_row(owner typed row r, operation op) = r * DAILY_SERVICE_OPERATION_COUNT + op
##
## an owner-major child index in ARCH-MEM-005's sense. The owner class is FarmPlot at its
## already-budgeted 4096 rows and `DAILY_SERVICE_OPERATION_COUNT` IS ONE, because exactly one
## daily service operation is implementable: R06-JOB-006's 20-WU hive KEEP service and
## REQ-SET-079/080's orchard care have no store to own them (see DEFERRED below). Widening the
## stride to three would budget capacity for two stores that do not exist, which AGENTS.md
## forbids; adding an operation later is a change to that one constant and to nothing else.
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
## IDEMPOTENCE IS THE PROPERTY, AND IT IS ENFORCED IN TWO PLACES.
##   1. MARKING. `mark_plot_dirty()` sets a membership BIT before pushing the owner, so N dirty
##      events on one owner produce ONE entry. The dirty set is a fixed 4096-entry stack; it
##      cannot grow, so no sequence of events can build a hidden queue.
##   2. RECONCILING. `_reconcile()` refuses with SERVICE_PENDING when the row already holds a
##      live Job for `(owner, operation, today)`, and with SERVICE_ALREADY_COMPLETE when
##      `_serviced_day` already names today. Repeated reconciliation of the same owner on the
##      same day therefore creates exactly one service, whatever the caller does.
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
##   * R06-JOB-004 sowing first-plant  -- next phase.
##   * R06-JOB-005 rotation advance    -- `FieldPolicy` does not exist (task 03 increment 7).
##   * R06-JOB-006 hive service        -- `Hive` does not exist (task 03 increment 8).
##   * REQ-SET-073 ripe harvest and REQ-SET-085 withered clearing keep their existing route; this
##     module does not reroute them and creates neither.
##
## BLOCKER U2 -- NO COMMAND DELIVERY. The ruling's confirm-driven producers need a transport that
## does not exist: ARCH-CMD-003's command kinds are unimplemented and no player command reaches
## the simulation. Daily tending is condition-driven and has no player enable, so THIS MODULE
## OWNS NO enable/confirm entry point of its own; the entry points a command handler would call
## when U2 closes are `mark_plot_dirty()`, `mark_all_owners_dirty()`, `mark_capacity_released()`
## and `record_service_completed()`. No command kind is invented and ARCH-CMD-003 is not
## renumbered.
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
## boundary run through `_reconcile()`, which returns a StringName and allocates NOTHING OF ITS
## OWN, so `run_tick_into()` costs zero objects in this file. It calls three functions that
## allocate INSIDE modules this task does not own, each their published contract:
##   * `farming.state_of()`   one IntResult per owner reconciled -- farming.gd publishes no
##     `_into` form. Reported, not worked around, and not fixed by editing a file this task does
##     not own; `jobs.gd`'s header records the same cost against `live_job_at()`.
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
## REFUSAL, NOT SENTINELS. `reconcile_plot()` succeeds ONLY when it created work; every other
## outcome is an explicit refusal naming which rule declined, so "already serviced", "already
## pending", "not growing" and "job capacity exhausted" are four distinguishable answers rather
## than one silent no-op. No reader returns -1 for absence.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- the daily service operations, per the pending-service identity ----------------------------

## R06-JOB-007's 1-WU FARM tending of a GROWING plot: the one daily service operation whose owner
## store exists. See DEFERRED in the header for the operations that have no store yet.
const OPERATION_FARM_TEND: int = 0
## The operation stride of `service_row()`. ONE, deliberately -- see the header.
const DAILY_SERVICE_OPERATION_COUNT: int = 1

# --- capacities --------------------------------------------------------------------------------

## The owner class of every operation implemented here. `_init()` asserts this equals both
## farming.gd's capacity and the directory's KIND_FARM_PLOT arena rather than restating a number.
const OWNER_CAPACITY: int = FarmingScript.FARM_PLOT_CAPACITY
## Rows in the pending-service table: one per (owner, operation) pair.
const SERVICE_ROW_COUNT: int = OWNER_CAPACITY * DAILY_SERVICE_OPERATION_COUNT

# --- pending-service status --------------------------------------------------------------------

## No record: this owner has no service outstanding for any day.
const STATUS_FREE: int = 0
## A Job exists for `(owner, operation, service_day)`. THIS IS THE IDEMPOTENCE GUARD's subject.
const STATUS_PENDING: int = 1
## Policy demand that could not be met because job capacity was exhausted. Retained, not queued.
const STATUS_UNMET: int = 2
const STATUS_COUNT: int = 3

## `_service_day` and `_serviced_day` are ABSOLUTE days, which start at 1; 0 means "no day", and
## it is a distinguishable absence rather than a sentinel that could read as a real day.
const NO_DAY: int = 0

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

# --- scratch (not simulation state) ------------------------------------------------------------

var _math: IntMath.IntResult = IntMath.IntResult.new()


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
	assert(SERVICE_ROW_COUNT == OWNER_CAPACITY * DAILY_SERVICE_OPERATION_COUNT,
		"the pending-service table is one row per (owner, operation) pair")
	assert(TENDING_JOB_KIND == JobsScript.JOB_KIND_FARM,
		"a tending service is a FARM job")
	assert(FarmingScript.TEND_WORK_MILLI_WU == 1000,
		"R06-JOB-007's tending service is one WU, which is 1000 milli-WU")


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	for column: PackedInt32Array in [_owner_slot, _owner_generation, _service_day, _job_slot,
			_job_generation, _serviced_day]:
		column.resize(SERVICE_ROW_COUNT)
	for column: PackedByteArray in [_status, _requires_water]:
		column.resize(SERVICE_ROW_COUNT)
	_dirty_rows.resize(OWNER_CAPACITY)
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
	_dirty_rows.fill(0)
	_is_dirty.fill(0)
	_dirty_count = 0
	_pending_count = 0
	_unmet_count = 0
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
	"""True when the argument names a daily service operation this build implements."""
	return operation >= 0 and operation < DAILY_SERVICE_OPERATION_COUNT


func service_row(owner_slot: int, operation: int) -> IntMath.IntResult:
	"""The pending-service row of `(owner, operation)`, or an explicit refusal.

	`r * DAILY_SERVICE_OPERATION_COUNT + op`, the owner-major child index of ARCH-MEM-005.
	"""
	if not is_owner_slot(owner_slot):
		return _read(REFUSE_INVALID_OWNER_SLOT, 0)
	if not is_operation(operation):
		return _read(REFUSE_INVALID_OPERATION, 0)
	return _read(REFUSE_NONE, owner_slot * DAILY_SERVICE_OPERATION_COUNT + operation)


func _row_of(owner_slot: int, operation: int) -> int:
	"""Unchecked `service_row()` for callers that have already validated both arguments."""
	return owner_slot * DAILY_SERVICE_OPERATION_COUNT + operation


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
	"""Non-allocating service_day_of(). Refuses rather than answering 0 for a free row."""
	if not status_into(owner_slot, operation, out):
		return false
	if out.value == STATUS_FREE:
		return out.refuse(String(REFUSE_NO_SERVICE))
	return out.succeed(_service_day[_row_of(owner_slot, operation)])


func last_serviced_day_of(owner_slot: int, operation: int) -> IntMath.IntResult:
	"""The absolute day of the last COMPLETED service, or NO_DAY when none has completed."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	last_serviced_day_into(owner_slot, operation, out)
	return out


func last_serviced_day_into(owner_slot: int, operation: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating last_serviced_day_of(). NO_DAY is an answer here, not a refusal."""
	if not is_owner_slot(owner_slot):
		return out.refuse(String(REFUSE_INVALID_OWNER_SLOT))
	if not is_operation(operation):
		return out.refuse(String(REFUSE_INVALID_OPERATION))
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
		if _farming.is_present(owner_slot) or _status[_row_of(owner_slot, OPERATION_FARM_TEND)] \
				!= STATUS_FREE:
			if _is_dirty[owner_slot] == 0:
				marked += 1
			mark_plot_dirty(owner_slot)
	return marked


func mark_capacity_released() -> int:
	"""R06-JOB-008's explicit retry: re-mark every retained unmet demand. Returns the count."""
	var marked: int = 0
	for row: int in SERVICE_ROW_COUNT:
		if _status[row] != STATUS_UNMET:
			continue
		var owner_slot: int = row / DAILY_SERVICE_OPERATION_COUNT
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
	"""Reconcile one owner's demand at `tick`. Succeeds ONLY when a service was created.

	Every other outcome is an explicit refusal naming the rule that declined: SERVICE_PENDING and
	SERVICE_ALREADY_COMPLETE are R06-JOB-008's idempotence guards, PLOT_NOT_GROWING and
	OWNER_NOT_PRESENT are R06-JOB-007's condition, and a directory refusal passed through is
	capacity exhaustion with its demand retained.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var code: StringName = _reconcile(owner_slot, tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _succeed(_row_of(owner_slot, OPERATION_FARM_TEND),
		service_job_of(owner_slot, OPERATION_FARM_TEND))


func _reconcile(owner_slot: int, tick: int) -> StringName:
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
	"""Return one service row to STATUS_FREE, keeping its durable completion history."""
	if _status[row] == STATUS_PENDING:
		_pending_count -= 1
	elif _status[row] == STATUS_UNMET:
		_unmet_count -= 1
	_status[row] = STATUS_FREE
	_owner_slot[row] = EntityDirectory.NULL_SLOT
	_owner_generation[row] = EntityDirectory.NULL_GENERATION
	_service_day[row] = NO_DAY
	_job_slot[row] = EntityDirectory.NULL_SLOT
	_job_generation[row] = EntityDirectory.NULL_GENERATION
	_requires_water[row] = 0


# --- explicit outcome entry points -------------------------------------------------------------

func record_service_completed(owner_slot: int, operation: int, day: int) -> OpResult:
	"""Record that this owner's service for `day` completed, from outside this module's own Job.

	The seam ARCH-SYS-006 uses when a tend is performed by a path that is not a planner Job.
	Refuses a day outside the calendar rather than writing one that would invert every later
	once-per-day test.
	"""
	var row: IntMath.IntResult = service_row(owner_slot, operation)
	if not row.ok:
		return _refuse(StringName(row.error))
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
		if _reconcile(_pop_dirty(), tick) == REFUSE_NONE:
			created += 1
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
		if _farming.is_present(owner_slot) \
				or _status[_row_of(owner_slot, OPERATION_FARM_TEND)] != STATUS_FREE:
			if _reconcile(owner_slot, tick) == REFUSE_NONE:
				created += 1
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
	"""Retire every service row older than `day`, cancelling any Job that never completed.

	No retroactive service: an owner that becomes eligible mid-day is reconciled against today,
	and yesterday's unfinished work does not survive into it.
	"""
	if _pending_count == 0 and _unmet_count == 0:
		return 0
	var settled: int = 0
	for row: int in SERVICE_ROW_COUNT:
		if _status[row] == STATUS_FREE or _service_day[row] >= day:
			continue
		_retire_unserved(row)
		settled += 1
	return settled


func preceding_day_is_settled(day: int) -> bool:
	"""True when no service row still carries a service day earlier than `day`.

	`run_day_boundary()` consults this BETWEEN settling and opening, so the ruling's ordering is
	a checked precondition of opening demand rather than a comment about statement order.
	"""
	for row: int in SERVICE_ROW_COUNT:
		if _status[row] != STATUS_FREE and _service_day[row] < day:
			return false
	return true


# --- load-time repair --------------------------------------------------------------------------

func revalidate_after_load() -> IntMath.IntResult:
	"""Drop pending rows whose Job no longer resolves; keep every other column. Returns the drops.

	The repair the ruling permits for an index over live jobs. Completion history is untouched --
	`_serviced_day` is what keeps "once per day" true across a load even when every pending row
	has gone -- and an unmet row is kept, because retained demand is policy state rather than a
	pointer into the Job store.
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
