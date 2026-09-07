extends RefCounted
## The Job store and the JobAgent store, plus the GDD §5.3 / ARCH-JOB-002 job selection pass.
##
## GDD §4.2 fixes the two row shapes this module owns and nothing else:
##   Job:      kind: enum, requester: EntityRef, destination: EntityRef, source: EntityRef,
##             priority: int32, required_skill: int32, remaining_mwu: int64, state: enum,
##             created_tick: int64, worker: EntityRef      -- "At most 8192 active/queued jobs"
##   JobAgent: job: EntityRef, phase: enum, target: EntityRef, path_id: int32,
##             path_cursor: int32, lease_expiry: int64, blocked_tick: int64,
##             manual_until: int64                          -- "At most 1 active job/resident"
## `systems_architecture.md` §2.2 fixes the packed layouts: Job as twelve I32 columns of 8192
## plus two I64 columns of 8192; JobAgent as seven I32 columns of 512 plus three I64 columns of
## 512. JobAgent is ONE ROW PER RESIDENT, indexed by the RESIDENT typed row, so a resident's
## agent row is found without a lookup. Job rows are indexed by the JOB typed row that
## `entity_directory.gd` allocates from its already-reserved KIND_JOB arena (capacity 8192);
## this module never invents a slot allocator of its own.
##
## ---------------------------------------------------------------------------------------
## VALUES COME FROM catalog.gd. JobKind and JobState are both explicitly numbered by GDD §4.3,
## so per decision 0018 their numbers live in `catalog.gd`'s protected enum table and are read
## here as constant expressions. There is no second copy of HAUL=0, RESERVED_3=3 or
## HAUL_OUTPUT=4 in this file, and nothing here can renumber them.
##
## ---------------------------------------------------------------------------------------
## THE SELECTION CONTRACT, verbatim from GDD §5.3 (ARCH-JOB-002 repeats it):
##
##   "Eligibility order: health/rescue safety; activity permits work; job kind priority
##    nonzero; required station/tool/skill/unlock; dangerous consent; complete inputs; legal
##    destination. Urgency buckets ascending: 0 rescue/feeding an incapacitated resident;
##    1 personal critical needs; 2 food/fuel jobs while projected reserve<2 days; 3 ordinary
##    production/construction; 4 cosmetic upkeep. Within a bucket sort
##    (player_priority, job_priority, -skill_level, estimated_path_cells, created_tick, job_id).
##    Reevaluate idle residents every 30 ticks, staggered by resident ID mod 30. A worker
##    evaluates at most 32 indexed candidate jobs per pass, continuing next pass from the saved
##    cursor when needed; this budget never changes eligibility."
##
## Implemented here: eligibility steps 1-6, all five urgency buckets, five of the six sort
## terms, the 30-tick cadence with the persistent-ID stagger, and the 32-candidate budget with
## its saved per-resident cursor. Step 7 and the sixth sort term are NOT implemented; see GAPS.
##
## `is_eligible()` reports the FIRST failing step by its own refusal code, so a caller -- and a
## test -- can tell which of the six rules rejected a job instead of receiving one flat "no".
##
## ---------------------------------------------------------------------------------------
## THE BUDGET IS A THROUGHPUT LIMIT, NOT A FILTER. One pass examines at most 32 candidates
## starting at the resident's saved cursor and picks the best of those it examined; the cursor
## then resumes after the last candidate examined, wrapping over the live-job index. Every
## eligible job is therefore reached within ceil(live_jobs/32) passes and no job is ever marked
## ineligible, blocked or skipped because the cursor has not arrived -- which is exactly what
## "this budget never changes eligibility" forbids. The alternative reading (defer any
## assignment until a whole sweep completes so the choice equals an unbudgeted scan) is
## rejected: at the 8192-row capacity it would leave a resident idle for 256 passes, i.e. 256
## real seconds at 1x, and §5.3 says the budget continues "when needed", not that selection
## waits for a full sweep. This reading is a judgement call on an ambiguous sentence and is
## reported as such.
##
## The cursor is a POSITION in the live-job index, not a job identity. Destroying a job shifts
## the index, so a saved cursor can re-examine or skip one candidate on the pass after a
## destroy. That costs one pass of latency and never costs eligibility, which is the property
## the sentence protects.
##
## ---------------------------------------------------------------------------------------
## SELECTION DOES NOT ASSIGN. `evaluate()` returns the winning candidate and mutates nothing
## but the resident's scan cursor and hazard latch. REQ-SET-030 requires worker, inputs, output
## capacity and destination slot to be reserved atomically before movement, and the reservation
## pool is a different module; `assign_worker()` binds a worker only once its caller has
## obtained whatever reservations that module requires. Nothing here reserves anything.
##
## Decision 0017's coordinator Job is NOT built here, and nothing here prevents it: `worker`
## defaults to the null reference and is never assumed present, `remaining_mwu` is a plain
## per-row column that no worker owns, and `release_worker()` clears the assignment while
## leaving `remaining_mwu` untouched -- the exact separation 0017 exists to guarantee. A later
## task adds the coordinator flag and the "a coordinator cannot be selected by a resident"
## eligibility exclusion; no unused column is added for it in advance.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. Every column is a packed array sized once in `_init()`; `clear()` refills the
## existing buffers and nothing outside `_allocate_columns()` calls `resize()`. One selection
## pass allocates one OpResult plus the IntResult objects that `residents.gd`, `needs.gd`,
## `priorities.gd` and `schedule.gd` allocate inside their own readers -- 27 of them, bounded
## by the 12-wide skill and priority strides and NOT by the 32 candidates, because both strides
## are read into packed scratch columns once per pass before the candidate loop begins. Those
## four modules publish no `_into` reader forms and this task does not own their files, so 27
## per pass is the floor available here; a resident evaluates at most once per 30 ticks, so
## this is not a per-tick-per-resident path. Named, not worked around.
##
## REFUSAL, NOT SENTINELS. Every mutator returns an OpResult and every reader an
## IntMath.IntResult whose `.ok` must be inspected. "No eligible job this pass" is an explicit
## REFUSE_NO_ELIGIBLE_JOB refusal carrying job slot 0 and the null reference, never a -1 job
## slot: this codebase has been bitten four times by a sentinel that read as data downstream.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md "do not invent a constant"):
##   * ELIGIBILITY STEP 7, "legal destination", IS NOT IMPLEMENTED. No pathfinder, no
##     navigation graph and no reachability oracle exists in this milestone. A job's
##     `destination` reference is stored and validated as a live EntityRef, and that is all: no
##     code here claims it can be reached. `path_id` and `path_cursor` exist, are explicitly 0,
##     and are never written -- the FaunaStockReserved pattern GDD §4.2 uses for a reserved
##     allocation, and the same pattern `needs.gd` uses for `departure_days`.
##   * THE `estimated_path_cells` SORT TERM IS NOT IMPLEMENTED, for the same reason. It is the
##     fourth of six terms, so ties that §5.3 would break by path length fall through to
##     `created_tick` and then `job_id` here. The order remains total and deterministic, but it
##     is NOT the specified order for two candidates that differ only in distance. No
##     fabricated distance, no zero-filled column pretending to be a measurement.
##   * REQ-SET-032/033 travel leases, the 300-tick release and the 900-tick blocked retry
##     (ARCH-JOB-004) are not implemented: `lease_expiry` and `blocked_tick` exist, are 0, and
##     are never written. They are lease bookkeeping over reservations this module does not own.
##   * REQ-SET-028's automatic fallback is not applied to the sort. Its priority-and-flag half
##     already lives in `priorities.fallback_priority_allows()`; its "low-risk FORAGE" half
##     needs a HarvestZone danger value and no HarvestZone store exists. Since step 3 already
##     excludes priority 0 and fallback cannot lower a configured priority, no job is wrongly
##     admitted here -- but a resident with nothing permitted is simply told so, rather than
##     being offered the HAUL/KEEP/FORAGE fallback set.
##   * ManualTask "work here" (§5.3, a 6-game-hour preferred destination) is blocked by U6: the
##     owner-major index formula for the 8-per-resident child store is unspecified.
##     `manual_until` exists, is 0, and is never written.
##   * The WU model and XP (§5.2's 80 milli-WU x factor/1000, §5.3's 10 XP per productive WU)
##     are a later task. `remaining_mwu` is stored and settable; nothing here decrements it.
##   * REQ-SET-034's "finish at most the current 30-WU safe work segment" is stated in WU and
##     needs that same model.
##   * `required_skill: int32` is read as a MINIMUM SKILL LEVEL (0-10) in the job's own kind,
##     because §4.3 makes JobKind and skill index the same number ("JobKind/skill index"), which
##     leaves a "which skill" reading of the field carrying no information at all while
##     eligibility step 4 explicitly demands a skill test. This is a reading of an underspecified
##     field, not a settled contract, and is reported as such.
##
## ---------------------------------------------------------------------------------------
## LEDGER DELTA. `systems_architecture.md` §2.2 budgets the Job and JobAgent columns listed at
## the top of this header and no others. These additional columns exist here and are NOT in
## that table; report them rather than deleting state the specification requires:
##   Job:      _present (B8 8192), _ref_slot/_ref_generation (I32 8192 x2, the directory
##             reference each row was allocated under -- `residents.gd` carries the same pair),
##             _urgency (B8 8192, §5.3's bucket, which no §4.2 field can hold and which JobKind
##             cannot derive: HAUL and KEEP both span buckets 0, 3 and 4), _dangerous (B8 8192,
##             step 5's consent subject -- §4.2 gives danger to HarvestZone and FishHabitat,
##             neither of which exists yet, so it is carried per job), four gate columns
##             _station/_tool/_unlock/_inputs_gate (B8 8192 each, see GATE_* below),
##             _live_slots (I32 8192, the ascending live-job index the cursor addresses).
##   JobAgent: _present (B8 512), _scan_cursor (I32 512, §5.3's "saved cursor" itself, which
##             §4.2's JobAgent row has no field for), _hazard_locked (B8 512, REQ-SET-015's
##             rest<=500 / rest>=4000 latch that `schedule.gd`'s header explicitly hands to this
##             module so exactly one hazard gate exists), _agent_persistent_id (I32 512, a cache
##             of the directory's persistent ID so the stagger test allocates nothing).

const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")

# --- capacities ----------------------------------------------------------------------------

## GDD §4.2 "At most 8192 active/queued jobs"; `_init()` asserts this equals the directory's own
## KIND_JOB capacity rather than restating an independent number.
const JOB_CAPACITY: int = 8192
## One JobAgent row per RESIDENT typed row; `_init()` asserts this equals needs.gd's capacity.
const AGENT_CAPACITY: int = 512

const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- GDD §4.3 JobKind, read from catalog.gd's protected table (decision 0018) ----------------

const JOB_KIND_COUNT: int = 12
const JOB_KIND_HAUL: int = Catalog.JOB_KIND["HAUL"]
const JOB_KIND_BUILD: int = Catalog.JOB_KIND["BUILD"]
const JOB_KIND_FISH: int = Catalog.JOB_KIND["FISH"]
const JOB_KIND_FORAGE: int = Catalog.JOB_KIND["FORAGE"]
const JOB_KIND_FARM: int = Catalog.JOB_KIND["FARM"]
const JOB_KIND_COOK: int = Catalog.JOB_KIND["COOK"]
const JOB_KIND_PRESERVE: int = Catalog.JOB_KIND["PRESERVE"]
const JOB_KIND_CRAFT: int = Catalog.JOB_KIND["CRAFT"]
const JOB_KIND_TEND: int = Catalog.JOB_KIND["TEND"]
const JOB_KIND_KEEP: int = Catalog.JOB_KIND["KEEP"]
const JOB_KIND_HEAL: int = Catalog.JOB_KIND["HEAL"]
## `setting_rules_amendment.md` renamed HUNT=3 to RESERVED_3=3 with assignment prohibited, so no
## Job row may ever carry it; the physical 12-wide stride is preserved either way.
const JOB_KIND_RESERVED_INDEX: int = Catalog.JOB_KIND["RESERVED_3"]

# --- GDD §4.3 JobState, read from catalog.gd's protected table (decision 0018) ---------------

const JOB_STATE_QUEUED: int = Catalog.JOB_STATE["QUEUED"]
const JOB_STATE_RESERVED: int = Catalog.JOB_STATE["RESERVED"]
const JOB_STATE_TRAVEL: int = Catalog.JOB_STATE["TRAVEL"]
const JOB_STATE_WORK: int = Catalog.JOB_STATE["WORK"]
const JOB_STATE_HAUL_OUTPUT: int = Catalog.JOB_STATE["HAUL_OUTPUT"]
const JOB_STATE_COMPLETE: int = Catalog.JOB_STATE["COMPLETE"]
const JOB_STATE_BLOCKED: int = Catalog.JOB_STATE["BLOCKED"]
const JOB_STATE_CANCELLED: int = Catalog.JOB_STATE["CANCELLED"]
## JobState is contiguous 0..7, which `_init()` proves before any range check relies on it.
const JOB_STATE_COUNT: int = 8

# --- GDD §4.3 Activity, via schedule.gd (which reads catalog.gd) -----------------------------

## §5.3 eligibility step 2, "activity permits work". WORK is the scheduled work hour; ANYTHING
## is the flexible hour, and the "Flexible is all ANYTHING" template would never work at all if
## it did not permit work. SLEEP and SOCIAL do not.
const ACTIVITY_WORK: int = ScheduleScript.ACTIVITY_WORK
const ACTIVITY_ANYTHING: int = ScheduleScript.ACTIVITY_ANYTHING

# --- GDD §5.3 urgency buckets, ascending -----------------------------------------------------

## "0 rescue/feeding an incapacitated resident".
const URGENCY_RESCUE: int = 0
## "1 personal critical needs".
const URGENCY_PERSONAL_CRITICAL: int = 1
## "2 food/fuel jobs while projected reserve<2 days". A job DECLARES this value to say it is a
## food or fuel job; it only OCCUPIES bucket 2 while the reserve is under two days, and ranks as
## ordinary work otherwise. The condition is a world state, not a property of the job, so it
## cannot be baked into the stored value -- see `set_food_reserve_below_two_days()`.
const URGENCY_FOOD_FUEL: int = 2
## "3 ordinary production/construction". The default for a newly created job.
const URGENCY_ORDINARY: int = 3
## "4 cosmetic upkeep".
const URGENCY_COSMETIC: int = 4
const URGENCY_COUNT: int = 5

# --- GDD §5.3 eligibility step 4 gates -------------------------------------------------------

## Step 4 is "required station/tool/skill/unlock". The skill half is decided from the resident's
## own Skills column against the job's `required_skill`. The other three need a Building/Room/
## Furniture store, an Equipment store and a Progress store, none of which exist in this
## milestone, so each is an explicit per-job input column with an honest default -- the same
## convention `needs.gd` uses for its unavailable environment inputs.
##
## GATE_NOT_REQUIRED is the default and means "this job declares no such requirement", NOT "the
## station is ready". GATE_SATISFIED is an owning system's positive answer, GATE_BLOCKED its
## negative one. Only GATE_BLOCKED makes a job ineligible, so an unfurnished world runs the
## honest behaviour of a settlement with no stations rather than a fabricated readiness.
const GATE_NOT_REQUIRED: int = 0
const GATE_SATISFIED: int = 1
const GATE_BLOCKED: int = 2
const GATE_COUNT: int = 3

# --- GDD §5.3 cadence and budget -------------------------------------------------------------

## "Reevaluate idle residents every 30 ticks, staggered by resident ID mod 30."
const REEVALUATION_INTERVAL_TICKS: int = 30
const STAGGER_MODULUS: int = 30
## "A worker evaluates at most 32 indexed candidate jobs per pass."
const CANDIDATE_BUDGET_PER_PASS: int = 32

# --- REQ-SET-015 hazard latch thresholds (borrowed from needs.gd, never restated) -------------

const REST_COLLAPSE_THRESHOLD: int = NeedsScript.REST_COLLAPSE_THRESHOLD
const REST_HAZARD_CLEAR_THRESHOLD: int = NeedsScript.REST_HAZARD_CLEAR_THRESHOLD

# --- skill level bounds ----------------------------------------------------------------------

const SKILL_LEVEL_MIN: int = 0
const SKILL_LEVEL_MAX: int = ResidentsScript.SKILL_LEVEL_MAX

# --- refusal codes ---------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_JOB_SLOT: StringName = &"INVALID_JOB_SLOT"
const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
const REFUSE_INVALID_RESIDENT_SLOT: StringName = &"INVALID_RESIDENT_SLOT"
const REFUSE_AGENT_NOT_PRESENT: StringName = &"JOB_AGENT_NOT_PRESENT"
const REFUSE_AGENT_ALREADY_PRESENT: StringName = &"JOB_AGENT_ALREADY_PRESENT"
const REFUSE_RESIDENT_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
const REFUSE_INVALID_JOB_KIND: StringName = &"INVALID_JOB_KIND"
const REFUSE_RESERVED_JOB_KIND: StringName = &"RESERVED_JOB_KIND"
const REFUSE_INVALID_JOB_STATE: StringName = &"INVALID_JOB_STATE"
const REFUSE_INVALID_PRIORITY: StringName = &"INVALID_JOB_PRIORITY"
const REFUSE_INVALID_REQUIRED_SKILL: StringName = &"INVALID_REQUIRED_SKILL"
const REFUSE_INVALID_MWU: StringName = &"INVALID_REMAINING_MWU"
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_URGENCY: StringName = &"INVALID_URGENCY"
const REFUSE_INVALID_GATE: StringName = &"INVALID_GATE"
const REFUSE_INVALID_REFERENCE: StringName = &"INVALID_REFERENCE"
const REFUSE_JOB_HAS_WORKER: StringName = &"JOB_HAS_WORKER"
const REFUSE_JOB_NOT_QUEUED: StringName = &"JOB_NOT_QUEUED"
const REFUSE_AGENT_BUSY: StringName = &"JOB_AGENT_BUSY"
const REFUSE_AGENT_IDLE: StringName = &"JOB_AGENT_IDLE"
const REFUSE_NOT_DUE_THIS_TICK: StringName = &"NOT_DUE_THIS_TICK"
const REFUSE_NO_ELIGIBLE_JOB: StringName = &"NO_ELIGIBLE_JOB"

# Eligibility step refusals: one code per rule, in §5.3's own order.
const REFUSE_RESIDENT_DEAD: StringName = &"STEP1_RESIDENT_DEAD"
const REFUSE_RESIDENT_INCAPACITATED: StringName = &"STEP1_RESIDENT_INCAPACITATED"
const REFUSE_REST_COLLAPSED: StringName = &"STEP1_REST_COLLAPSED"
const REFUSE_ACTIVITY_UNRESOLVED: StringName = &"STEP2_ACTIVITY_UNRESOLVED"
const REFUSE_ACTIVITY_FORBIDS_WORK: StringName = &"STEP2_ACTIVITY_FORBIDS_WORK"
const REFUSE_KIND_PRIORITY_FORBIDDEN: StringName = &"STEP3_KIND_PRIORITY_FORBIDDEN"
const REFUSE_STATION_BLOCKED: StringName = &"STEP4_STATION_BLOCKED"
const REFUSE_TOOL_BLOCKED: StringName = &"STEP4_TOOL_BLOCKED"
const REFUSE_SKILL_TOO_LOW: StringName = &"STEP4_SKILL_TOO_LOW"
const REFUSE_UNLOCK_BLOCKED: StringName = &"STEP4_UNLOCK_BLOCKED"
const REFUSE_DANGEROUS_CONSENT: StringName = &"STEP5_DANGEROUS_CONSENT"
const REFUSE_HAZARD_LOCKED: StringName = &"STEP5_HAZARD_LOCKED"
const REFUSE_INPUTS_INCOMPLETE: StringName = &"STEP6_INPUTS_INCOMPLETE"
const REFUSE_NEEDS_UNAVAILABLE: StringName = &"NEEDS_ROW_UNAVAILABLE"
const REFUSE_PRIORITIES_UNAVAILABLE: StringName = &"PRIORITIES_ROW_UNAVAILABLE"
const REFUSE_SKILLS_UNAVAILABLE: StringName = &"SKILLS_ROW_UNAVAILABLE"


class OpResult:
	"""Outcome of one job operation: success flag, refusal code, produced value, reference.

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


# --- collaborating stores ---------------------------------------------------------------------

var _residents: ResidentsScript = null
var _directory: EntityDirectory = null
var _needs: NeedsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null

# --- Job columns (ARCH-MEM-001: packed, allocated once) ---------------------------------------

var _kind: PackedInt32Array = PackedInt32Array()
var _requester_slot: PackedInt32Array = PackedInt32Array()
var _requester_generation: PackedInt32Array = PackedInt32Array()
var _destination_slot: PackedInt32Array = PackedInt32Array()
var _destination_generation: PackedInt32Array = PackedInt32Array()
var _source_slot: PackedInt32Array = PackedInt32Array()
var _source_generation: PackedInt32Array = PackedInt32Array()
var _priority: PackedInt32Array = PackedInt32Array()
var _required_skill: PackedInt32Array = PackedInt32Array()
var _state: PackedInt32Array = PackedInt32Array()
var _worker_slot: PackedInt32Array = PackedInt32Array()
var _worker_generation: PackedInt32Array = PackedInt32Array()
var _remaining_mwu: PackedInt64Array = PackedInt64Array()
var _created_tick: PackedInt64Array = PackedInt64Array()

# Ledger delta, listed in the header.
var _job_present: PackedByteArray = PackedByteArray()
var _job_ref_slot: PackedInt32Array = PackedInt32Array()
var _job_ref_generation: PackedInt32Array = PackedInt32Array()
var _urgency: PackedByteArray = PackedByteArray()
var _dangerous: PackedByteArray = PackedByteArray()
var _station_gate: PackedByteArray = PackedByteArray()
var _tool_gate: PackedByteArray = PackedByteArray()
var _unlock_gate: PackedByteArray = PackedByteArray()
var _inputs_gate: PackedByteArray = PackedByteArray()
var _live_slots: PackedInt32Array = PackedInt32Array()

var _live_count: int = 0

# --- JobAgent columns, one row per resident slot ------------------------------------------------

var _agent_job_slot: PackedInt32Array = PackedInt32Array()
var _agent_job_generation: PackedInt32Array = PackedInt32Array()
var _agent_phase: PackedInt32Array = PackedInt32Array()
var _agent_target_slot: PackedInt32Array = PackedInt32Array()
var _agent_target_generation: PackedInt32Array = PackedInt32Array()
## Reserved allocation only: no pathfinder exists, so these are 0 and never written (GAPS).
var _agent_path_id: PackedInt32Array = PackedInt32Array()
var _agent_path_cursor: PackedInt32Array = PackedInt32Array()
## Reserved allocation only: REQ-SET-032/033 lease bookkeeping is not implemented (GAPS).
var _agent_lease_expiry: PackedInt64Array = PackedInt64Array()
var _agent_blocked_tick: PackedInt64Array = PackedInt64Array()
## Reserved allocation only: ManualTask is blocked by U6 (GAPS).
var _agent_manual_until: PackedInt64Array = PackedInt64Array()

# Ledger delta, listed in the header.
var _agent_present: PackedByteArray = PackedByteArray()
var _agent_scan_cursor: PackedInt32Array = PackedInt32Array()
var _agent_hazard_locked: PackedByteArray = PackedByteArray()
var _agent_persistent_id: PackedInt32Array = PackedInt32Array()

var _agent_count: int = 0

# --- world input ---------------------------------------------------------------------------------

## §5.3 bucket 2's condition, "while projected reserve<2 days". It is a world state owned by the
## food-days figure and the inventory, not by any job, so it arrives as an explicit input with an
## honest default of false. No projection is computed here.
var _food_reserve_below_two_days: bool = false

# --- per-pass scratch (not simulation state) ----------------------------------------------------

## The resident's twelve skill levels and twelve job priorities, read once per selection pass so
## the candidate loop allocates nothing. Both are filled by `_load_resident_scratch()` and
## consumed before that pass returns; nothing here invokes a callback, so no public operation can
## re-enter while they hold a live value.
var _skill_scratch: PackedInt32Array = PackedInt32Array()
var _priority_scratch: PackedInt32Array = PackedInt32Array()
var _dangerous_consent_scratch: bool = false
var _hazard_locked_scratch: bool = false

## The incumbent best candidate of the pass in progress. `_best_slot` is -1 only while no
## candidate has been offered; it is internal scratch and never leaves this module as a value.
var _best_slot: int = -1
var _best_bucket: int = 0
var _best_player_priority: int = 0
var _best_job_priority: int = 0
var _best_skill_level: int = 0
var _best_created_tick: int = 0
var _best_job_id: int = 0


func _init(p_residents: ResidentsScript = null, p_priorities: PrioritiesScript = null,
		p_schedule: ScheduleScript = null) -> void:
	"""Bind the collaborating stores, assert every borrowed capacity, and allocate once.

	Passing existing stores shares them; passing nothing builds a private, consistent set in
	which the schedule reads the same needs rows the residents store owns.
	"""
	_residents = p_residents if p_residents != null else ResidentsScript.new()
	_directory = _residents.directory()
	_needs = _residents.needs()
	_priorities = p_priorities if p_priorities != null else PrioritiesScript.new()
	_schedule = p_schedule if p_schedule != null else ScheduleScript.new(_needs)
	_assert_shared_contracts()
	_allocate_columns()
	clear()


func _assert_shared_contracts() -> void:
	"""Prove the capacities, strides and enum shapes this module reads from other documents."""
	assert(JOB_CAPACITY == _directory.capacity_of_kind(EntityDirectory.KIND_JOB),
		"the Job store must match the directory's KIND_JOB capacity")
	assert(AGENT_CAPACITY == NeedsScript.RESIDENT_CAPACITY,
		"JobAgent is one row per resident and must match the needs store's capacity")
	assert(JOB_KIND_COUNT == PrioritiesScript.JOB_KIND_COUNT,
		"the job-priority stride and the JobKind count are the same twelve")
	assert(JOB_KIND_COUNT == ResidentsScript.SKILL_COUNT,
		"GDD §4.3 makes JobKind and the skill index one enum")
	assert(Catalog.JOB_STATE.size() == JOB_STATE_COUNT,
		"GDD §4.3 JobState has exactly eight values")
	_assert_job_state_is_contiguous()


func _assert_job_state_is_contiguous() -> void:
	"""Prove JobState occupies 0..7, which every state range check here relies on.

	JobKind and ZoneType carry reserved gaps; JobState does not, so `0 <= s < 8` is a sound
	membership test only while that stays true of catalog.gd's protected table.
	"""
	var seen: Array[bool] = []
	for index: int in JOB_STATE_COUNT:
		seen.append(false)
	for key: String in Catalog.JOB_STATE:
		var value: int = int(Catalog.JOB_STATE[key])
		assert(value >= 0 and value < JOB_STATE_COUNT, "JobState value out of the contiguous range")
		assert(not seen[value], "JobState values must be distinct")
		seen[value] = true


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	for column: PackedInt32Array in [_kind, _requester_slot, _requester_generation,
			_destination_slot, _destination_generation, _source_slot, _source_generation,
			_priority, _required_skill, _state, _worker_slot, _worker_generation,
			_job_ref_slot, _job_ref_generation, _live_slots]:
		column.resize(JOB_CAPACITY)
	for column: PackedInt64Array in [_remaining_mwu, _created_tick]:
		column.resize(JOB_CAPACITY)
	for column: PackedByteArray in [_job_present, _urgency, _dangerous, _station_gate,
			_tool_gate, _unlock_gate, _inputs_gate]:
		column.resize(JOB_CAPACITY)
	_allocate_agent_columns()
	_skill_scratch.resize(JOB_KIND_COUNT)
	_priority_scratch.resize(JOB_KIND_COUNT)


func _allocate_agent_columns() -> void:
	"""Size every JobAgent column exactly once. Split out to keep each function under 30 lines."""
	for column: PackedInt32Array in [_agent_job_slot, _agent_job_generation, _agent_phase,
			_agent_target_slot, _agent_target_generation, _agent_path_id, _agent_path_cursor,
			_agent_scan_cursor, _agent_persistent_id]:
		column.resize(AGENT_CAPACITY)
	for column: PackedInt64Array in [_agent_lease_expiry, _agent_blocked_tick,
			_agent_manual_until]:
		column.resize(AGENT_CAPACITY)
	for column: PackedByteArray in [_agent_present, _agent_hazard_locked]:
		column.resize(AGENT_CAPACITY)


func clear() -> void:
	"""Return every Job and JobAgent row to the empty state without reallocating a column."""
	_kind.fill(JOB_KIND_HAUL)
	_priority.fill(0)
	_required_skill.fill(0)
	_state.fill(JOB_STATE_QUEUED)
	_remaining_mwu.fill(0)
	_created_tick.fill(0)
	_job_present.fill(0)
	_urgency.fill(URGENCY_ORDINARY)
	_dangerous.fill(0)
	_station_gate.fill(GATE_NOT_REQUIRED)
	_tool_gate.fill(GATE_NOT_REQUIRED)
	_unlock_gate.fill(GATE_NOT_REQUIRED)
	_inputs_gate.fill(GATE_NOT_REQUIRED)
	_live_slots.fill(0)
	_live_count = 0
	for column: PackedInt32Array in [_requester_slot, _destination_slot, _source_slot,
			_worker_slot, _job_ref_slot]:
		column.fill(EntityDirectory.NULL_SLOT)
	for column: PackedInt32Array in [_requester_generation, _destination_generation,
			_source_generation, _worker_generation, _job_ref_generation]:
		column.fill(EntityDirectory.NULL_GENERATION)
	_clear_agents()
	_food_reserve_below_two_days = false
	_reset_best()


func _clear_agents() -> void:
	"""Return every JobAgent row to the empty state, refilling the existing buffers."""
	for column: PackedInt32Array in [_agent_job_slot, _agent_target_slot]:
		column.fill(EntityDirectory.NULL_SLOT)
	for column: PackedInt32Array in [_agent_job_generation, _agent_target_generation]:
		column.fill(EntityDirectory.NULL_GENERATION)
	for column: PackedInt32Array in [_agent_phase, _agent_path_id, _agent_path_cursor,
			_agent_scan_cursor, _agent_persistent_id]:
		column.fill(0)
	for column: PackedInt64Array in [_agent_lease_expiry, _agent_blocked_tick,
			_agent_manual_until]:
		column.fill(0)
	_agent_present.fill(0)
	_agent_hazard_locked.fill(0)
	_agent_count = 0


# --- results ----------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refusal. It always carries 0 and the null reference, never a stale number."""
	return OpResult.new(false, code, 0, NULL_REF)


func _read(code: StringName, value: int) -> IntMath.IntResult:
	"""Build a reader's IntResult: the value on success, an explicit refusal otherwise."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if code != REFUSE_NONE:
		out.refuse(String(code))
	else:
		out.succeed(value)
	return out


# --- collaborators -------------------------------------------------------------------------------

func residents() -> ResidentsScript:
	"""The residents store these agent rows are indexed against."""
	return _residents


func directory() -> EntityDirectory:
	"""The entity directory this store allocates KIND_JOB rows from."""
	return _directory


func needs() -> NeedsScript:
	"""The needs store eligibility step 1 reads."""
	return _needs


func priorities() -> PrioritiesScript:
	"""The priorities store eligibility steps 3 and 5 read."""
	return _priorities


func schedule() -> ScheduleScript:
	"""The schedule store eligibility step 2 reads."""
	return _schedule


# --- address checks ------------------------------------------------------------------------------

func _check_job_slot(job_slot: int) -> StringName:
	"""REFUSE_NONE when `job_slot` is in range and holds a live Job row."""
	if job_slot < 0 or job_slot >= JOB_CAPACITY:
		return REFUSE_INVALID_JOB_SLOT
	if _job_present[job_slot] == 0:
		return REFUSE_JOB_NOT_PRESENT
	return REFUSE_NONE


func _check_agent_slot(resident_slot: int) -> StringName:
	"""REFUSE_NONE when `resident_slot` is in range and holds a spawned JobAgent row."""
	if resident_slot < 0 or resident_slot >= AGENT_CAPACITY:
		return REFUSE_INVALID_RESIDENT_SLOT
	if _agent_present[resident_slot] == 0:
		return REFUSE_AGENT_NOT_PRESENT
	return REFUSE_NONE


func _check_reference(ref: Vector2i) -> StringName:
	"""REFUSE_NONE for the null reference or for one the directory still validates."""
	if ref == NULL_REF:
		return REFUSE_NONE
	if not _directory.is_valid(ref):
		return REFUSE_INVALID_REFERENCE
	return REFUSE_NONE


# --- Job lifecycle -------------------------------------------------------------------------------

func create_job(kind: int, priority: int, required_skill: int, remaining_mwu: int,
		created_tick: int) -> OpResult:
	"""Allocate one Job row through the directory's KIND_JOB arena and write its §4.2 defaults.

	`required_skill` is the minimum skill LEVEL 0-10 the job's own kind demands; see the header
	GAPS entry on that field's underspecified meaning. Refuses without allocating anything on an
	unknown or reserved kind, an out-of-int32 priority, an out-of-range level, a negative work
	total or a negative creation tick, and passes a directory refusal through with its own
	ARCH-ID-004 code.
	"""
	var code: StringName = _check_create_arguments(kind, priority, required_skill,
		remaining_mwu, created_tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_JOB)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var job_slot: int = _directory.get_typed_row(ref)
	_write_new_job_row(job_slot, ref, kind, priority, required_skill)
	_remaining_mwu[job_slot] = remaining_mwu
	_created_tick[job_slot] = created_tick
	_insert_live_slot(job_slot)
	return _succeed(job_slot, ref)


func _check_create_arguments(kind: int, priority: int, required_skill: int, remaining_mwu: int,
		created_tick: int) -> StringName:
	"""REFUSE_NONE when every create_job() argument is inside its specified domain."""
	if kind < 0 or kind >= JOB_KIND_COUNT:
		return REFUSE_INVALID_JOB_KIND
	if kind == JOB_KIND_RESERVED_INDEX:
		return REFUSE_RESERVED_JOB_KIND
	if not IntMath.fits_int32(priority):
		return REFUSE_INVALID_PRIORITY
	if required_skill < SKILL_LEVEL_MIN or required_skill > SKILL_LEVEL_MAX:
		return REFUSE_INVALID_REQUIRED_SKILL
	if remaining_mwu < 0:
		return REFUSE_INVALID_MWU
	if created_tick < 0:
		return REFUSE_INVALID_TICK
	return REFUSE_NONE


func _write_new_job_row(job_slot: int, ref: Vector2i, kind: int, priority: int,
		required_skill: int) -> void:
	"""Write every Job column of a freshly allocated row to its §4.2 default."""
	_job_present[job_slot] = 1
	_job_ref_slot[job_slot] = ref.x
	_job_ref_generation[job_slot] = ref.y
	_kind[job_slot] = kind
	_priority[job_slot] = priority
	_required_skill[job_slot] = required_skill
	_state[job_slot] = JOB_STATE_QUEUED
	_urgency[job_slot] = URGENCY_ORDINARY
	_dangerous[job_slot] = 0
	_station_gate[job_slot] = GATE_NOT_REQUIRED
	_tool_gate[job_slot] = GATE_NOT_REQUIRED
	_unlock_gate[job_slot] = GATE_NOT_REQUIRED
	_inputs_gate[job_slot] = GATE_NOT_REQUIRED
	_set_ref_columns(job_slot, NULL_REF, _requester_slot, _requester_generation)
	_set_ref_columns(job_slot, NULL_REF, _destination_slot, _destination_generation)
	_set_ref_columns(job_slot, NULL_REF, _source_slot, _source_generation)
	_set_ref_columns(job_slot, NULL_REF, _worker_slot, _worker_generation)


func _set_ref_columns(row: int, ref: Vector2i, slot_column: PackedInt32Array,
		generation_column: PackedInt32Array) -> void:
	"""Write one EntityRef into its paired slot/generation columns."""
	slot_column[row] = ref.x
	generation_column[row] = ref.y


func destroy_job(job_slot: int) -> OpResult:
	"""Release one Job row and its directory slot. Refuses while a worker still holds it.

	Refusing rather than silently unbinding is deliberate: decision 0017 gives worker departure
	and job cancellation separate paths, and a destroy that quietly detached a worker would
	merge them. Call `release_worker()` first.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_JOB_HAS_WORKER)
	var ref: Vector2i = ref_of(job_slot)
	_directory.destroy(ref)
	_remove_live_slot(job_slot)
	_job_present[job_slot] = 0
	_clear_job_row(job_slot)
	return _succeed(job_slot, NULL_REF)


func _clear_job_row(job_slot: int) -> void:
	"""Return one released Job row to exactly the state clear() produces.

	Two logically identical worlds must serialize to identical columns, so a destroyed job
	leaves no residue that would change a canonical hash.
	"""
	_kind[job_slot] = JOB_KIND_HAUL
	_priority[job_slot] = 0
	_required_skill[job_slot] = 0
	_state[job_slot] = JOB_STATE_QUEUED
	_remaining_mwu[job_slot] = 0
	_created_tick[job_slot] = 0
	_urgency[job_slot] = URGENCY_ORDINARY
	_dangerous[job_slot] = 0
	_station_gate[job_slot] = GATE_NOT_REQUIRED
	_tool_gate[job_slot] = GATE_NOT_REQUIRED
	_unlock_gate[job_slot] = GATE_NOT_REQUIRED
	_inputs_gate[job_slot] = GATE_NOT_REQUIRED
	_set_ref_columns(job_slot, NULL_REF, _job_ref_slot, _job_ref_generation)
	_set_ref_columns(job_slot, NULL_REF, _requester_slot, _requester_generation)
	_set_ref_columns(job_slot, NULL_REF, _destination_slot, _destination_generation)
	_set_ref_columns(job_slot, NULL_REF, _source_slot, _source_generation)
	_set_ref_columns(job_slot, NULL_REF, _worker_slot, _worker_generation)


func _insert_live_slot(job_slot: int) -> void:
	"""Insert a created job into the ascending live index the scan cursor addresses."""
	var index: int = _live_count
	while index > 0 and _live_slots[index - 1] > job_slot:
		_live_slots[index] = _live_slots[index - 1]
		index -= 1
	_live_slots[index] = job_slot
	_live_count += 1


func _remove_live_slot(job_slot: int) -> void:
	"""Remove a destroyed job from the ascending live index, closing the gap it leaves."""
	var index: int = 0
	while index < _live_count and _live_slots[index] != job_slot:
		index += 1
	if index >= _live_count:
		return
	while index + 1 < _live_count:
		_live_slots[index] = _live_slots[index + 1]
		index += 1
	_live_count -= 1
	_live_slots[_live_count] = 0


# --- Job readers ----------------------------------------------------------------------------------

func is_job_present(job_slot: int) -> bool:
	"""True when `job_slot` is in range and holds a live Job row."""
	return _check_job_slot(job_slot) == REFUSE_NONE


func job_count() -> int:
	"""Number of live Job rows."""
	return _live_count


func live_job_at(index: int) -> IntMath.IntResult:
	"""The job slot at `index` of the ascending live index the scan cursor walks."""
	if index < 0 or index >= _live_count:
		return _read(REFUSE_INVALID_JOB_SLOT, 0)
	return _read(REFUSE_NONE, _live_slots[index])


func ref_of(job_slot: int) -> Vector2i:
	"""The directory reference owning a Job row, or the null reference when it is empty."""
	if not is_job_present(job_slot):
		return NULL_REF
	return Vector2i(_job_ref_slot[job_slot], _job_ref_generation[job_slot])


func job_id_of(job_slot: int) -> IntMath.IntResult:
	"""The never-reused persistent ID that breaks the last tie in the §5.3 sort key."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _directory.get_persistent_id(ref_of(job_slot)) if code == REFUSE_NONE else 0)


func kind_of(job_slot: int) -> IntMath.IntResult:
	"""JobKind of a Job row, 0-11 and never the reserved index 3."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _kind[job_slot] if code == REFUSE_NONE else 0)


func priority_of(job_slot: int) -> IntMath.IntResult:
	"""Job.priority: the second term of the §5.3 within-bucket sort key, ascending."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _priority[job_slot] if code == REFUSE_NONE else 0)


func required_skill_of(job_slot: int) -> IntMath.IntResult:
	"""Job.required_skill, read as a minimum skill level 0-10 (see the header GAPS entry)."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _required_skill[job_slot] if code == REFUSE_NONE else 0)


func remaining_mwu_of(job_slot: int) -> IntMath.IntResult:
	"""Job.remaining_mwu. Stored only: no WU model decrements it in this milestone."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _remaining_mwu[job_slot] if code == REFUSE_NONE else 0)


func created_tick_of(job_slot: int) -> IntMath.IntResult:
	"""Job.created_tick: the fifth term of the §5.3 within-bucket sort key, ascending."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _created_tick[job_slot] if code == REFUSE_NONE else 0)


func state_of(job_slot: int) -> IntMath.IntResult:
	"""Job.state, one of GDD §4.3's eight JobState values."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _state[job_slot] if code == REFUSE_NONE else 0)


func urgency_of(job_slot: int) -> IntMath.IntResult:
	"""The urgency bucket a job DECLARES, before bucket 2's reserve condition is applied."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _urgency[job_slot] if code == REFUSE_NONE else 0)


func effective_urgency_of(job_slot: int) -> IntMath.IntResult:
	"""The bucket a job actually occupies now: declared, with §5.3's bucket 2 condition applied.

	A job declaring URGENCY_FOOD_FUEL occupies bucket 2 only while the projected reserve is under
	two days, and ranks as ordinary production otherwise.
	"""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _effective_urgency(job_slot) if code == REFUSE_NONE else 0)


func _effective_urgency(job_slot: int) -> int:
	"""§5.3 bucket 2's condition applied to one job's declared bucket. No projection is made."""
	var declared: int = _urgency[job_slot]
	if declared == URGENCY_FOOD_FUEL and not _food_reserve_below_two_days:
		return URGENCY_ORDINARY
	return declared


func is_dangerous(job_slot: int) -> bool:
	"""True when a job is subject to §5.3's dangerous-consent step and REQ-SET-015's hazard bar."""
	return is_job_present(job_slot) and _dangerous[job_slot] == 1


func station_gate_of(job_slot: int) -> IntMath.IntResult:
	"""Eligibility step 4's station gate: GATE_NOT_REQUIRED, GATE_SATISFIED or GATE_BLOCKED."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _station_gate[job_slot] if code == REFUSE_NONE else 0)


func tool_gate_of(job_slot: int) -> IntMath.IntResult:
	"""Eligibility step 4's tool gate. No Equipment store exists; see the header."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _tool_gate[job_slot] if code == REFUSE_NONE else 0)


func unlock_gate_of(job_slot: int) -> IntMath.IntResult:
	"""Eligibility step 4's unlock gate. No Progress store exists; see the header."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _unlock_gate[job_slot] if code == REFUSE_NONE else 0)


func inputs_gate_of(job_slot: int) -> IntMath.IntResult:
	"""Eligibility step 6's complete-inputs gate. The reservation pool is another module's."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _inputs_gate[job_slot] if code == REFUSE_NONE else 0)


func requester_of(job_slot: int) -> Vector2i:
	"""Job.requester, or the null reference when unset or the row is empty."""
	return _ref_of_columns(job_slot, _requester_slot, _requester_generation)


func destination_of(job_slot: int) -> Vector2i:
	"""Job.destination. Stored and validated as a reference; reachability is NOT decided here."""
	return _ref_of_columns(job_slot, _destination_slot, _destination_generation)


func source_of(job_slot: int) -> Vector2i:
	"""Job.source, or the null reference when unset or the row is empty."""
	return _ref_of_columns(job_slot, _source_slot, _source_generation)


func worker_of(job_slot: int) -> Vector2i:
	"""Job.worker, or the null reference while the job is unassigned or is a coordinator."""
	return _ref_of_columns(job_slot, _worker_slot, _worker_generation)


func _ref_of_columns(job_slot: int, slot_column: PackedInt32Array,
		generation_column: PackedInt32Array) -> Vector2i:
	"""Read one EntityRef out of its paired slot/generation columns."""
	if not is_job_present(job_slot):
		return NULL_REF
	return Vector2i(slot_column[job_slot], generation_column[job_slot])


func inactive_job_row_is_clear(job_slot: int) -> bool:
	"""True when a released Job row holds no residue of the job that last occupied it."""
	if job_slot < 0 or job_slot >= JOB_CAPACITY or _job_present[job_slot] != 0:
		return false
	if _kind[job_slot] != JOB_KIND_HAUL or _priority[job_slot] != 0:
		return false
	if _required_skill[job_slot] != 0 or _state[job_slot] != JOB_STATE_QUEUED:
		return false
	if _remaining_mwu[job_slot] != 0 or _created_tick[job_slot] != 0:
		return false
	if _urgency[job_slot] != URGENCY_ORDINARY or _dangerous[job_slot] != 0:
		return false
	if _station_gate[job_slot] != GATE_NOT_REQUIRED or _tool_gate[job_slot] != GATE_NOT_REQUIRED:
		return false
	if _unlock_gate[job_slot] != GATE_NOT_REQUIRED or _inputs_gate[job_slot] != GATE_NOT_REQUIRED:
		return false
	return worker_of(job_slot) == NULL_REF and destination_of(job_slot) == NULL_REF


# --- Job mutators ------------------------------------------------------------------------------

func set_state(job_slot: int, state: int) -> OpResult:
	"""Write Job.state, accepting only GDD §4.3's eight values.

	No transition graph is enforced: ARCH-JOB-001 fixes the eight numbers and states that passive
	wait is a saved phase within WORK, but neither document enumerates the legal transitions, and
	inventing one here would be inventing a contract.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if state < 0 or state >= JOB_STATE_COUNT:
		return _refuse(REFUSE_INVALID_JOB_STATE)
	_state[job_slot] = state
	return _succeed(state, ref_of(job_slot))


func set_remaining_mwu(job_slot: int, remaining_mwu: int) -> OpResult:
	"""Write Job.remaining_mwu. Refuses a negative total rather than clamping it to zero."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if remaining_mwu < 0:
		return _refuse(REFUSE_INVALID_MWU)
	_remaining_mwu[job_slot] = remaining_mwu
	return _succeed(remaining_mwu, ref_of(job_slot))


func set_urgency(job_slot: int, urgency: int) -> OpResult:
	"""Declare which §5.3 urgency bucket a job belongs to, 0-4.

	URGENCY_FOOD_FUEL declares a food or fuel job; §5.3 puts it in bucket 2 only while the
	projected reserve is under two days, which `effective_urgency_of()` applies.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if urgency < 0 or urgency >= URGENCY_COUNT:
		return _refuse(REFUSE_INVALID_URGENCY)
	_urgency[job_slot] = urgency
	return _succeed(urgency, ref_of(job_slot))


func set_dangerous(job_slot: int, dangerous: bool) -> OpResult:
	"""Mark a job as subject to eligibility step 5 and to REQ-SET-015's hazardous-work bar."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	_dangerous[job_slot] = 1 if dangerous else 0
	return _succeed(_dangerous[job_slot], ref_of(job_slot))


func set_station_gate(job_slot: int, gate: int) -> OpResult:
	"""Write eligibility step 4's station gate. The Building/Room/Furniture owner writes this."""
	return _set_gate(job_slot, gate, _station_gate)


func set_tool_gate(job_slot: int, gate: int) -> OpResult:
	"""Write eligibility step 4's tool gate. The Equipment owner writes this."""
	return _set_gate(job_slot, gate, _tool_gate)


func set_unlock_gate(job_slot: int, gate: int) -> OpResult:
	"""Write eligibility step 4's unlock gate. The Progress owner writes this."""
	return _set_gate(job_slot, gate, _unlock_gate)


func set_inputs_gate(job_slot: int, gate: int) -> OpResult:
	"""Write eligibility step 6's complete-inputs gate. The reservation owner writes this."""
	return _set_gate(job_slot, gate, _inputs_gate)


func _set_gate(job_slot: int, gate: int, column: PackedByteArray) -> OpResult:
	"""Validate and write one tri-state eligibility gate."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if gate < 0 or gate >= GATE_COUNT:
		return _refuse(REFUSE_INVALID_GATE)
	column[job_slot] = gate
	return _succeed(gate, ref_of(job_slot))


func set_requester(job_slot: int, ref: Vector2i) -> OpResult:
	"""Write Job.requester. Accepts the null reference or a reference the directory validates."""
	return _set_job_ref(job_slot, ref, _requester_slot, _requester_generation)


func set_destination(job_slot: int, ref: Vector2i) -> OpResult:
	"""Write Job.destination. Storing it asserts nothing about reachability -- step 7 is absent."""
	return _set_job_ref(job_slot, ref, _destination_slot, _destination_generation)


func set_source(job_slot: int, ref: Vector2i) -> OpResult:
	"""Write Job.source. Accepts the null reference or a reference the directory validates."""
	return _set_job_ref(job_slot, ref, _source_slot, _source_generation)


func _set_job_ref(job_slot: int, ref: Vector2i, slot_column: PackedInt32Array,
		generation_column: PackedInt32Array) -> OpResult:
	"""Validate and write one Job EntityRef column pair."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _check_reference(ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	_set_ref_columns(job_slot, ref, slot_column, generation_column)
	return _succeed(job_slot, ref)


func set_food_reserve_below_two_days(below: bool) -> void:
	"""Supply §5.3 bucket 2's world condition, "projected reserve<2 days".

	An explicit input with an honest default of false: the projection needs the food-days figure
	and the inventory, and nothing here computes or guesses it.
	"""
	_food_reserve_below_two_days = below


func food_reserve_below_two_days() -> bool:
	"""The currently supplied answer to §5.3 bucket 2's reserve condition."""
	return _food_reserve_below_two_days


# --- JobAgent lifecycle --------------------------------------------------------------------------

func spawn_agent(resident_slot: int) -> OpResult:
	"""Initialize one JobAgent row for a living resident. Refuses an occupied row.

	The resident's persistent ID is cached into the row here because §5.3's stagger is defined on
	it and the per-tick predicate must not allocate to read it.
	"""
	if resident_slot < 0 or resident_slot >= AGENT_CAPACITY:
		return _refuse(REFUSE_INVALID_RESIDENT_SLOT)
	if _agent_present[resident_slot] != 0:
		return _refuse(REFUSE_AGENT_ALREADY_PRESENT)
	if not _residents.is_present(resident_slot):
		return _refuse(REFUSE_RESIDENT_NOT_PRESENT)
	var persistent_id: IntMath.IntResult = _residents.persistent_id_of(resident_slot)
	if not persistent_id.ok:
		return _refuse(REFUSE_RESIDENT_NOT_PRESENT)
	_agent_present[resident_slot] = 1
	_agent_count += 1
	_agent_persistent_id[resident_slot] = persistent_id.value
	_clear_agent_row(resident_slot)
	return _succeed(resident_slot, _residents.ref_of(resident_slot))


func despawn_agent(resident_slot: int) -> OpResult:
	"""Release one JobAgent row. Refuses while the agent still holds a job.

	Refusing is deliberate: a silent despawn would leave the Job row pointing at a worker that no
	longer exists, which is the dangling half of the departure path decision 0017 separates.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _agent_job_slot[resident_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_AGENT_BUSY)
	_agent_present[resident_slot] = 0
	_agent_count -= 1
	_agent_persistent_id[resident_slot] = 0
	_clear_agent_row(resident_slot)
	return _succeed(resident_slot, NULL_REF)


func _clear_agent_row(resident_slot: int) -> void:
	"""Reset one JobAgent row's job, phase, target, reserved columns, cursor and hazard latch."""
	_set_ref_columns(resident_slot, NULL_REF, _agent_job_slot, _agent_job_generation)
	_set_ref_columns(resident_slot, NULL_REF, _agent_target_slot, _agent_target_generation)
	_agent_phase[resident_slot] = 0
	_agent_path_id[resident_slot] = 0
	_agent_path_cursor[resident_slot] = 0
	_agent_lease_expiry[resident_slot] = 0
	_agent_blocked_tick[resident_slot] = 0
	_agent_manual_until[resident_slot] = 0
	_agent_scan_cursor[resident_slot] = 0
	_agent_hazard_locked[resident_slot] = 0


# --- JobAgent readers -----------------------------------------------------------------------------

func is_agent_present(resident_slot: int) -> bool:
	"""True when `resident_slot` is in range and holds a spawned JobAgent row."""
	return _check_agent_slot(resident_slot) == REFUSE_NONE


func agent_count() -> int:
	"""Number of spawned JobAgent rows."""
	return _agent_count


func job_of(resident_slot: int) -> Vector2i:
	"""JobAgent.job, or the null reference while the resident is idle or has no agent row."""
	if not is_agent_present(resident_slot):
		return NULL_REF
	return Vector2i(_agent_job_slot[resident_slot], _agent_job_generation[resident_slot])


func is_agent_idle(resident_slot: int) -> bool:
	"""True when a spawned agent holds no job -- §5.3's "idle residents" for reevaluation."""
	return is_agent_present(resident_slot) and job_of(resident_slot) == NULL_REF


func phase_of(resident_slot: int) -> IntMath.IntResult:
	"""JobAgent.phase as a JobState value. REFUSES while the agent holds no job.

	An idle resident has no phase and §4.3 numbers no idle JobState, so this refuses rather than
	returning a plausible-looking QUEUED that a caller could mistake for a real assignment.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if job_of(resident_slot) == NULL_REF:
		return _read(REFUSE_AGENT_IDLE, 0)
	return _read(REFUSE_NONE, _agent_phase[resident_slot])


func target_of(resident_slot: int) -> Vector2i:
	"""JobAgent.target, or the null reference when unset."""
	if not is_agent_present(resident_slot):
		return NULL_REF
	return Vector2i(_agent_target_slot[resident_slot], _agent_target_generation[resident_slot])


func path_id_of(resident_slot: int) -> IntMath.IntResult:
	"""JobAgent.path_id. Reserved and always 0: no pathfinder exists (header GAPS)."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _agent_path_id[resident_slot] if code == REFUSE_NONE else 0)


func path_cursor_of(resident_slot: int) -> IntMath.IntResult:
	"""JobAgent.path_cursor. Reserved and always 0: no pathfinder exists (header GAPS)."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _agent_path_cursor[resident_slot] if code == REFUSE_NONE else 0)


func lease_expiry_of(resident_slot: int) -> IntMath.IntResult:
	"""JobAgent.lease_expiry. Reserved and always 0: REQ-SET-032 is deferred (header GAPS)."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _agent_lease_expiry[resident_slot] if code == REFUSE_NONE else 0)


func blocked_tick_of(resident_slot: int) -> IntMath.IntResult:
	"""JobAgent.blocked_tick. Reserved and always 0: REQ-SET-033 is deferred (header GAPS)."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _agent_blocked_tick[resident_slot] if code == REFUSE_NONE else 0)


func manual_until_of(resident_slot: int) -> IntMath.IntResult:
	"""JobAgent.manual_until. Reserved and always 0: ManualTask is blocked by U6 (header GAPS)."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _agent_manual_until[resident_slot] if code == REFUSE_NONE else 0)


func scan_cursor_of(resident_slot: int) -> IntMath.IntResult:
	"""§5.3's saved candidate cursor: the live-index position the next pass resumes from."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _agent_scan_cursor[resident_slot] if code == REFUSE_NONE else 0)


func is_hazard_locked(resident_slot: int) -> bool:
	"""REQ-SET-015's latch: true from rest<=500 until rest>=4000, barring hazardous work."""
	return is_agent_present(resident_slot) and _agent_hazard_locked[resident_slot] == 1


# --- worker binding -------------------------------------------------------------------------------

func assign_worker(resident_slot: int, job_slot: int) -> OpResult:
	"""Bind a resident to a QUEUED, unworked job and move it to RESERVED.

	Reserves nothing: REQ-SET-030's atomic input, output and destination-slot reservation belongs
	to the reservation pool, and the caller performs it before calling this.
	"""
	var code: StringName = _check_bind_arguments(resident_slot, job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	var job_ref: Vector2i = ref_of(job_slot)
	_set_ref_columns(job_slot, _residents.ref_of(resident_slot), _worker_slot, _worker_generation)
	_state[job_slot] = JOB_STATE_RESERVED
	_set_ref_columns(resident_slot, job_ref, _agent_job_slot, _agent_job_generation)
	_agent_phase[resident_slot] = JOB_STATE_RESERVED
	return _succeed(job_slot, job_ref)


func _check_bind_arguments(resident_slot: int, job_slot: int) -> StringName:
	"""REFUSE_NONE when an idle agent may take a queued, unworked job."""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return code
	code = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return code
	if job_of(resident_slot) != NULL_REF:
		return REFUSE_AGENT_BUSY
	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return REFUSE_JOB_HAS_WORKER
	if _state[job_slot] != JOB_STATE_QUEUED:
		return REFUSE_JOB_NOT_QUEUED
	return REFUSE_NONE


func release_worker(resident_slot: int) -> OpResult:
	"""Release a worker's assignment, returning their job to the queue.

	Decision 0017: "Worker departure releases that worker's assignment and personal claims only.
	Shared progress, consumed inputs and batch data survive." `remaining_mwu` is therefore left
	exactly as it was -- progress belongs to the job, not to whoever was carrying it.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	var job_ref: Vector2i = job_of(resident_slot)
	if job_ref == NULL_REF:
		return _refuse(REFUSE_AGENT_IDLE)
	var job_slot: int = _directory.get_typed_row(job_ref)
	_set_ref_columns(resident_slot, NULL_REF, _agent_job_slot, _agent_job_generation)
	_agent_phase[resident_slot] = 0
	if job_slot != EntityDirectory.NULL_SLOT and _job_present[job_slot] == 1:
		_set_ref_columns(job_slot, NULL_REF, _worker_slot, _worker_generation)
		_state[job_slot] = JOB_STATE_QUEUED
	return _succeed(resident_slot, NULL_REF)


# --- §5.3 cadence and stagger -------------------------------------------------------------------

func should_evaluate(resident_slot: int, tick: int) -> bool:
	"""True when this idle resident's 30-tick reevaluation falls on `tick`.

	"Reevaluate idle residents every 30 ticks, staggered by resident ID mod 30" (§5.3), on the
	persistent ID (ARCH-JOB-002). Allocation-free: the ID is cached in the agent row.
	"""
	return _check_evaluable(resident_slot, tick) == REFUSE_NONE


func _check_evaluable(resident_slot: int, tick: int) -> StringName:
	"""REFUSE_NONE when a present, idle agent is due for a selection pass on `tick`."""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return code
	if tick < 0:
		return REFUSE_INVALID_TICK
	if job_of(resident_slot) != NULL_REF:
		return REFUSE_AGENT_BUSY
	if tick % REEVALUATION_INTERVAL_TICKS != _agent_persistent_id[resident_slot] % STAGGER_MODULUS:
		return REFUSE_NOT_DUE_THIS_TICK
	return REFUSE_NONE


func stagger_offset_of(resident_slot: int) -> IntMath.IntResult:
	"""The tick offset inside each 30-tick window at which this resident reevaluates."""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _agent_persistent_id[resident_slot] % STAGGER_MODULUS)


# --- §5.3 eligibility ----------------------------------------------------------------------------

func is_eligible(resident_slot: int, job_slot: int) -> OpResult:
	"""Run §5.3's eligibility steps 1-6 for one resident against one job.

	`.ok` true means eligible. `.ok` false carries the code of the FIRST step that rejected it,
	so a caller learns which rule applied rather than a flat refusal. Step 7, "legal destination",
	is not evaluated: no pathfinder exists (header GAPS).
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _load_resident_scratch(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _job_eligibility(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _succeed(job_slot, ref_of(job_slot))


func _load_resident_scratch(resident_slot: int) -> StringName:
	"""Run eligibility steps 1-2 and cache the resident's twelve skills and twelve priorities.

	Everything the candidate loop needs about the resident is read here, once per pass, so the
	loop itself makes no reader call and allocates nothing.
	"""
	var code: StringName = _resident_work_gate(resident_slot)
	if code != REFUSE_NONE:
		return code
	for kind: int in JOB_KIND_COUNT:
		var level: IntMath.IntResult = _residents.skill_level_of(resident_slot, kind)
		if not level.ok:
			return REFUSE_SKILLS_UNAVAILABLE
		_skill_scratch[kind] = level.value
		var priority: IntMath.IntResult = _priorities.priority_of(resident_slot, kind)
		if not priority.ok:
			return REFUSE_PRIORITIES_UNAVAILABLE
		_priority_scratch[kind] = priority.value
	var consent: IntMath.IntResult = _priorities.dangerous_work_of(resident_slot)
	if not consent.ok:
		return REFUSE_PRIORITIES_UNAVAILABLE
	_dangerous_consent_scratch = consent.value == 1
	_hazard_locked_scratch = _agent_hazard_locked[resident_slot] == 1
	return REFUSE_NONE


func _resident_work_gate(resident_slot: int) -> StringName:
	"""Eligibility steps 1 and 2: health/rescue safety, then activity permits work."""
	var code: StringName = _health_and_rescue_gate(resident_slot)
	if code != REFUSE_NONE:
		return code
	var activity: IntMath.IntResult = _schedule.current_activity_of(resident_slot)
	if not activity.ok:
		return REFUSE_ACTIVITY_UNRESOLVED
	if activity.value != ACTIVITY_WORK and activity.value != ACTIVITY_ANYTHING:
		return REFUSE_ACTIVITY_FORBIDS_WORK
	return REFUSE_NONE


func _health_and_rescue_gate(resident_slot: int) -> StringName:
	"""Eligibility step 1: a dead, incapacitated or collapsed resident takes no job.

	REQ-SET-023 replaces an incapacitated resident's own work with a rescue job created for them,
	and REQ-SET-015 cancels ordinary work outright at rest<=500. Both are exclusions, not
	rankings: bucket 0 is about the job that rescues someone, never about the casualty working.
	"""
	var status: IntMath.IntResult = _needs.status_of(resident_slot)
	if not status.ok:
		return REFUSE_NEEDS_UNAVAILABLE
	if status.value == NeedsScript.STATUS_DEAD:
		return REFUSE_RESIDENT_DEAD
	if status.value == NeedsScript.STATUS_INCAPACITATED:
		return REFUSE_RESIDENT_INCAPACITATED
	var rest: IntMath.IntResult = _needs.need_of(resident_slot, NeedsScript.NEED_REST)
	if not rest.ok:
		return REFUSE_NEEDS_UNAVAILABLE
	if rest.value <= REST_COLLAPSE_THRESHOLD:
		return REFUSE_REST_COLLAPSED
	return REFUSE_NONE


func _job_eligibility(job_slot: int) -> StringName:
	"""Eligibility steps 3-6 for one candidate, using the scratch loaded for this pass.

	Candidacy comes first and is not one of the six steps: a job already worked, or in any state
	but QUEUED, is not on offer at all.
	"""
	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return REFUSE_JOB_HAS_WORKER
	if _state[job_slot] != JOB_STATE_QUEUED:
		return REFUSE_JOB_NOT_QUEUED
	var kind: int = _kind[job_slot]
	if _priority_scratch[kind] == PrioritiesScript.PRIORITY_FORBIDDEN:
		return REFUSE_KIND_PRIORITY_FORBIDDEN
	var code: StringName = _station_tool_skill_unlock_gate(job_slot, kind)
	if code != REFUSE_NONE:
		return code
	code = _dangerous_consent_gate(job_slot)
	if code != REFUSE_NONE:
		return code
	if _inputs_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_INPUTS_INCOMPLETE
	return REFUSE_NONE


func _station_tool_skill_unlock_gate(job_slot: int, kind: int) -> StringName:
	"""Eligibility step 4, in §5.3's own order: station, tool, skill, unlock."""
	if _station_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_STATION_BLOCKED
	if _tool_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_TOOL_BLOCKED
	if _skill_scratch[kind] < _required_skill[job_slot]:
		return REFUSE_SKILL_TOO_LOW
	if _unlock_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_UNLOCK_BLOCKED
	return REFUSE_NONE


func _dangerous_consent_gate(job_slot: int) -> StringName:
	"""Eligibility step 5, plus REQ-SET-015's "prevent hazardous work until rest>=4000".

	`schedule.gd`'s header hands that latch here deliberately so one hazard gate exists rather
	than two disagreeing ones. A job that is not dangerous passes both.
	"""
	if _dangerous[job_slot] == 0:
		return REFUSE_NONE
	if not _dangerous_consent_scratch:
		return REFUSE_DANGEROUS_CONSENT
	if _hazard_locked_scratch:
		return REFUSE_HAZARD_LOCKED
	return REFUSE_NONE


func refresh_hazard_latch(resident_slot: int) -> OpResult:
	"""Update REQ-SET-015's hazard latch from the resident's current rest.

	Set at rest<=500, cleared at rest>=4000, held between the two: the thresholds differ, so a
	live comparison would clear the bar 3500 need-points early. `evaluate()` calls this itself.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	var rest: IntMath.IntResult = _needs.need_of(resident_slot, NeedsScript.NEED_REST)
	if not rest.ok:
		return _refuse(REFUSE_NEEDS_UNAVAILABLE)
	if rest.value <= REST_COLLAPSE_THRESHOLD:
		_agent_hazard_locked[resident_slot] = 1
	elif rest.value >= REST_HAZARD_CLEAR_THRESHOLD:
		_agent_hazard_locked[resident_slot] = 0
	return _succeed(_agent_hazard_locked[resident_slot], NULL_REF)


# --- §5.3 selection pass -------------------------------------------------------------------------

func evaluate(resident_slot: int, tick: int) -> OpResult:
	"""Run one §5.3 selection pass for an idle resident and return the winning candidate.

	Refuses REFUSE_NOT_DUE_THIS_TICK off the resident's staggered tick, REFUSE_AGENT_BUSY while
	they already hold a job, and REFUSE_NO_ELIGIBLE_JOB when the examined window offered nothing.
	Mutates only the hazard latch and the saved cursor; binding a worker is `assign_worker()`.
	"""
	var code: StringName = _check_evaluable(resident_slot, tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	var latch: OpResult = refresh_hazard_latch(resident_slot)
	if not latch.ok:
		return _refuse(latch.error)
	code = _load_resident_scratch(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _scan_pass(resident_slot)


func _scan_pass(resident_slot: int) -> OpResult:
	"""Examine at most 32 indexed candidates from the saved cursor, keeping the best of them.

	The cursor resumes after the last candidate examined and wraps over the live index, so every
	eligible job is reached within ceil(live_jobs/32) passes and none is ever made ineligible by
	the budget -- see the header on why the budget is a throughput limit, not a filter.
	"""
	var count: int = _live_count
	if count == 0:
		return _refuse(REFUSE_NO_ELIGIBLE_JOB)
	var start: int = _agent_scan_cursor[resident_slot] % count
	var budget: int = CANDIDATE_BUDGET_PER_PASS if CANDIDATE_BUDGET_PER_PASS < count else count
	_reset_best()
	for step: int in budget:
		var job_slot: int = _live_slots[(start + step) % count]
		if _job_eligibility(job_slot) == REFUSE_NONE:
			_offer_candidate(job_slot)
	_agent_scan_cursor[resident_slot] = (start + budget) % count
	if _best_slot < 0:
		return _refuse(REFUSE_NO_ELIGIBLE_JOB)
	return _succeed(_best_slot, ref_of(_best_slot))


func _reset_best() -> void:
	"""Drop the incumbent candidate before a pass begins."""
	_best_slot = -1
	_best_bucket = 0
	_best_player_priority = 0
	_best_job_priority = 0
	_best_skill_level = 0
	_best_created_tick = 0
	_best_job_id = 0


func _offer_candidate(job_slot: int) -> void:
	"""Compare one eligible candidate against the incumbent and keep the better of the two."""
	var kind: int = _kind[job_slot]
	var bucket: int = _effective_urgency(job_slot)
	var player_priority: int = _priority_scratch[kind]
	var job_priority: int = _priority[job_slot]
	var skill_level: int = _skill_scratch[kind]
	var created_tick: int = _created_tick[job_slot]
	var job_id: int = _directory.get_persistent_id(ref_of(job_slot))
	if _best_slot >= 0 and not _beats_incumbent(bucket, player_priority, job_priority,
			skill_level, created_tick, job_id):
		return
	_best_slot = job_slot
	_best_bucket = bucket
	_best_player_priority = player_priority
	_best_job_priority = job_priority
	_best_skill_level = skill_level
	_best_created_tick = created_tick
	_best_job_id = job_id


func _beats_incumbent(bucket: int, player_priority: int, job_priority: int, skill_level: int,
		created_tick: int, job_id: int) -> bool:
	"""Order two candidates: urgency bucket first, then §5.3's within-bucket sort key.

	Ascending on bucket, player_priority, job_priority, then DESCENDING on skill_level (the key
	writes it as `-skill_level`), then ascending created_tick and job_id. The fourth specified
	term, `estimated_path_cells`, is absent: no pathfinder exists, so candidates that differ only
	in distance fall through to created_tick here (header GAPS). job_id is never reused, so the
	order is total and no two candidates can compare equal.
	"""
	if bucket != _best_bucket:
		return bucket < _best_bucket
	if player_priority != _best_player_priority:
		return player_priority < _best_player_priority
	if job_priority != _best_job_priority:
		return job_priority < _best_job_priority
	if skill_level != _best_skill_level:
		return skill_level > _best_skill_level
	if created_tick != _best_created_tick:
		return created_tick < _best_created_tick
	return job_id < _best_job_id
