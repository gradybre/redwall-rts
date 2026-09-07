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
## its saved per-resident continuation. Step 7 and the sixth sort term are NOT implemented; see
## GAPS.
##
## `is_eligible()` reports the FIRST failing step by its own refusal code, so a caller -- and a
## test -- can tell which of the six rules rejected a job instead of receiving one flat "no".
##
## ---------------------------------------------------------------------------------------
## ENUMERATION VISITS URGENCY BUCKETS, NOT ROW ORDER (decision 0023, superseding the live-row
## scan shipped in 48998c6). The first implementation examined 32 candidates in ascending
## live-row index order, so THIRTY-TWO COSMETIC JOBS COULD HIDE A RESCUE AT POSITION 33 --
## sorting the examined window correctly does nothing for urgency outside it. A pass now walks
## urgency buckets 0 -> 4 and, within the highest bucket that contained an examined eligible
## candidate, picks the best of those it examined by the §5.3 comparison terms. It descends to
## a lower bucket only after exhausting the higher ones without an eligible candidate. At most
## 32 candidates are examined per pass IN TOTAL across every bucket the pass touches.
##
## SAY IT PLAINLY: this deliberately permits APPROXIMATE RANKING WITHIN A BUCKET while
## preserving EXACT URGENCY BETWEEN BUCKETS. If a bucket holds more candidates than the pass has
## budget for, the winner is the best of those examined, not necessarily the best in the bucket;
## but no candidate in a higher bucket is ever passed over for one in a lower bucket.
##
## THE BUDGET IS A THROUGHPUT LIMIT, NOT A FILTER. When the budget expires with no candidate the
## continuation is retained and the resident retries on its next scheduled pass, so every
## eligible job is reached within ceil(live_jobs/32) passes and no job is ever marked ineligible,
## blocked or skipped because enumeration has not arrived. UNEXAMINED MEANS NOT EVALUATED --
## never ineligible, never unreachable, which is exactly what "this budget never changes
## eligibility" forbids. The alternative reading (defer any assignment until a whole sweep
## completes so the choice equals an unbudgeted scan) is rejected: at the 8192-row capacity it
## would leave a resident idle for 256 passes, i.e. 256 real seconds at 1x, and §5.3 says the
## budget continues "when needed", not that selection waits for a full sweep. That reading is a
## judgement call on an ambiguous sentence and is reported as such.
##
## THE CONTINUATION KEY IS `(bucket, job persistent_id)`, NOT A POSITION (decision 0023). The
## earlier positional cursor claimed a deletion costs "one pass"; that is not generally true
## under repeated insertion and deletion, because positions shift and a positional cursor
## therefore changes meaning. Persistent IDs are never reused, so this key does not: a
## continuation names the bucket to resume in and the last job examined there, and the next pass
## resumes at the first job of that bucket whose persistent ID is greater.
##
## A NEWLY AVAILABLE HIGHER-URGENCY JOB INVALIDATES A CONTINUATION INTO LOWER BUCKETS. Every
## event that can make a job available -- creation, an urgency change, a return to QUEUED, a
## worker release, a gate ceasing to block, danger being lifted, and the bucket-2 reserve
## condition -- calls `_admit()`, which resets every continuation that could otherwise have
## walked past the newly available job. Invalidation is exact, not conservative: a continuation
## is reset only when the admitted job sits in a strictly higher bucket than the continuation,
## or in the SAME bucket at a persistent ID the continuation has already walked past.
##
## ---------------------------------------------------------------------------------------
## SELECTION DOES NOT ASSIGN. `evaluate()` returns the winning candidate and mutates nothing
## but the resident's continuation and hazard latch. REQ-SET-030 requires worker, inputs, output
## capacity and destination slot to be reserved atomically before movement, and the reservation
## pool is a different module; `assign_worker()` binds a worker only once its caller has
## obtained whatever reservations that module requires. Nothing here reserves anything.
##
## GATES ARE REVALIDATED AT COMMITMENT (decision 0023). `assign_worker()` is this module's
## commitment point, and it re-runs the whole of eligibility -- reading every gate column
## afresh -- before it binds. A result returned by an earlier `evaluate()` is a NOMINATION, never
## an authorisation: between the two, another job may have reserved the inputs this one counted
## on, a station may have gone offline, or the resident's hour may have turned to SLEEP. A cached
## "inputs satisfied" therefore cannot authorise acceptance, and a caller that ignores the
## refusal cannot bind anyway.
##
## A MISSING SUBSYSTEM READS AS UNAVAILABLE, NEVER AS SATISFIED. GATE_UNAVAILABLE is how an
## owning system says "this job declares this requirement and I cannot currently answer for it";
## it refuses, exactly like GATE_BLOCKED, with its own code so the caller can tell "no" from
## "cannot say". GATE_NOT_REQUIRED remains the default and means the job declares NO such
## requirement -- it is not an absent subsystem reading as ready.
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
## this is not a per-tick-per-resident path. Named, not worked around. `assign_worker()`'s
## revalidation pays the same 27 once per binding, which happens at most once per job taken.
##
## The candidate loop itself allocates nothing: bucket enumeration is a binary search plus a
## two-pointer merge over `_live_slots`, both reading packed columns through plain integers.
## `_admit()` walks the 512 agent rows only when a continuation is at or below the admitted
## bucket, which one integer comparison decides.
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
##
## ---------------------------------------------------------------------------------------
## `required_skill` IS A MINIMUM LEVEL -- SETTLED BY DECISION 0022, no longer a gap:
##     skill_index  = Job.kind
##     skill_passes = resident.skill_level[skill_index] >= Job.required_skill
## 0 means no minimum experience; 1-10 is a minimum level in that job's own skill; a value
## OUTSIDE 0-10 is an INVALID JOB DEFINITION and is refused, never clamped, and so is any job of
## kind RESERVED_3. §4.3 makes JobKind and the skill index the same number, so "which skill"
## carries no information and the field name is kept only for compatibility. The default stays 0:
## no additional minimum is introduced here that no recipe or task definition specifies.
## PARTY MEMBERS ARE CHECKED INDIVIDUALLY -- this test runs against one resident's own column, and
## a crew-average fishing skill belongs to the catch calculation, not to eligibility. No party or
## crew concept exists in this module and none is invented here.
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
##             _live_slots (I32 8192, the live-job index, ordered by declared urgency and then by
##             ascending persistent ID so a bucket is a contiguous run and a continuation key can
##             be located in it by binary search), _job_persistent_id (I32 8192, a cache of the
##             directory's persistent ID so the candidate loop and the ordered index never call
##             back into the directory -- the same trick `_agent_persistent_id` already uses).
##   JobAgent: _present (B8 512), _hazard_locked (B8 512, REQ-SET-015's rest<=500 / rest>=4000
##             latch that `schedule.gd`'s header explicitly hands to this module so exactly one
##             hazard gate exists), _agent_persistent_id (I32 512, a cache of the directory's
##             persistent ID so the stagger test allocates nothing), _continuation_bucket
##             (B8 512, the bucket half of decision 0023's continuation key).
##
## `_job_scan_cursor` IS NOT AN ADDITIONAL ALLOCATION. It is the physical realisation of
## `ResidentRuntime.job_scan_cursor` (`systems_architecture.md` §3, line 245: an I32 column of
## 512 inside a seven-column group already budgeted as "[NEW] Need/job continuation; GDD
## §5.2-5.3"). No ResidentRuntime store object exists yet; when one lands, this column moves into
## it unchanged rather than being duplicated. It is indexed by the RESIDENT typed row, exactly as
## that table specifies, and this module allocates no second buffer for the same logical state.
## Decision 0023's key needs a bucket alongside the ID, and a persistent ID legitimately uses the
## whole int32 range (`entity_directory.gd` refuses at MAX_INT32), so the bucket cannot be packed
## into the same word without inventing an ID cap. It is therefore ONE ADDED BYTE per resident --
## `_continuation_bucket`, 512 bytes in total -- and not a second int32. Named here because
## silently widening a budgeted allocation is exactly what this note exists to prevent.

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
## negative one. An unfurnished world therefore runs the honest behaviour of a settlement with no
## stations rather than a fabricated readiness.
##
## GATE_UNAVAILABLE is decision 0023's "a missing subsystem must never silently read as
## requirement satisfied": it means the job DOES declare this requirement and the system that
## owns it cannot answer -- no Building store, no Equipment store, a station whose row was
## destroyed. It refuses, like GATE_BLOCKED, but with its own code so "cannot say" is never
## mistaken for "no". Both GATE_BLOCKED and GATE_UNAVAILABLE make a job ineligible.
const GATE_NOT_REQUIRED: int = 0
const GATE_SATISFIED: int = 1
const GATE_BLOCKED: int = 2
const GATE_UNAVAILABLE: int = 3
const GATE_COUNT: int = 4

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
# Decision 0023: a declared requirement whose owning system cannot answer refuses as UNAVAILABLE,
# never as satisfied. One code per gate, so "cannot say" never reads as "no".
const REFUSE_STATION_UNAVAILABLE: StringName = &"STEP4_STATION_UNAVAILABLE"
const REFUSE_TOOL_UNAVAILABLE: StringName = &"STEP4_TOOL_UNAVAILABLE"
const REFUSE_UNLOCK_UNAVAILABLE: StringName = &"STEP4_UNLOCK_UNAVAILABLE"
const REFUSE_INPUTS_UNAVAILABLE: StringName = &"STEP6_INPUTS_UNAVAILABLE"
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
## The live-job index, ordered by declared urgency and then by ascending persistent ID.
var _live_slots: PackedInt32Array = PackedInt32Array()
## Cache of the directory's never-reused persistent ID, so the ordered index and the candidate
## loop compare integers out of a packed column instead of calling back into the directory.
var _job_persistent_id: PackedInt32Array = PackedInt32Array()

var _live_count: int = 0

## Half-open bounds of each declared-urgency run inside `_live_slots`: bucket u occupies
## [_bucket_begin[u], _bucket_begin[u + 1]). URGENCY_COUNT + 1 entries, the last one _live_count.
var _bucket_begin: PackedInt32Array = PackedInt32Array()

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
var _agent_hazard_locked: PackedByteArray = PackedByteArray()
var _agent_persistent_id: PackedInt32Array = PackedInt32Array()

## The ID half of decision 0023's `(bucket, job persistent_id)` continuation key: the last job
## examined in the continuation bucket, 0 when no scan is in progress. This IS
## `ResidentRuntime.job_scan_cursor` from `systems_architecture.md` §3, realised here because no
## ResidentRuntime store exists yet -- not a second buffer for the same logical state.
var _job_scan_cursor: PackedInt32Array = PackedInt32Array()
## The bucket half of the same key. One byte per resident; see the header for why it cannot be
## folded into the int32 above.
var _continuation_bucket: PackedByteArray = PackedByteArray()

## An UPPER BOUND on the deepest (numerically largest) bucket any live continuation resumes in,
## and -1 when no resident holds one. `_admit()` compares one integer against it before walking
## the agent rows, so the common case -- an admission while nobody is mid-scan -- costs a single
## comparison. Only `_admit()` tightens it; every other path that clears a continuation leaves it
## high, which is safe because a too-high bound only costs one wasted walk, never a missed
## invalidation.
var _deepest_continuation_bucket: int = -1

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

## The bucket walk in progress. One effective bucket spans at most TWO runs of `_live_slots`,
## because a declared FOOD_FUEL job occupies bucket 3 while the reserve is fine; the two runs are
## merged by ascending persistent ID so a bucket still enumerates in one total order. Plain
## members rather than a returned iterator, so a pass allocates nothing.
var _walk_primary_index: int = 0
var _walk_primary_end: int = 0
var _walk_merged_index: int = 0
var _walk_merged_end: int = 0
var _walk_slot: int = 0
var _walk_job_id: int = 0
## The persistent ID a suspended pass resumes after: the last candidate examined in the bucket it
## was suspended in, or the ID it entered that bucket at when it examined none.
var _walk_last_examined_id: int = 0


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
			_job_ref_slot, _job_ref_generation, _live_slots, _job_persistent_id]:
		column.resize(JOB_CAPACITY)
	for column: PackedInt64Array in [_remaining_mwu, _created_tick]:
		column.resize(JOB_CAPACITY)
	for column: PackedByteArray in [_job_present, _urgency, _dangerous, _station_gate,
			_tool_gate, _unlock_gate, _inputs_gate]:
		column.resize(JOB_CAPACITY)
	_bucket_begin.resize(URGENCY_COUNT + 1)
	_allocate_agent_columns()
	_skill_scratch.resize(JOB_KIND_COUNT)
	_priority_scratch.resize(JOB_KIND_COUNT)


func _allocate_agent_columns() -> void:
	"""Size every JobAgent column exactly once. Split out to keep each function under 30 lines."""
	for column: PackedInt32Array in [_agent_job_slot, _agent_job_generation, _agent_phase,
			_agent_target_slot, _agent_target_generation, _agent_path_id, _agent_path_cursor,
			_job_scan_cursor, _agent_persistent_id]:
		column.resize(AGENT_CAPACITY)
	for column: PackedInt64Array in [_agent_lease_expiry, _agent_blocked_tick,
			_agent_manual_until]:
		column.resize(AGENT_CAPACITY)
	for column: PackedByteArray in [_agent_present, _agent_hazard_locked, _continuation_bucket]:
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
	_job_persistent_id.fill(0)
	_bucket_begin.fill(0)
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
			_job_scan_cursor, _agent_persistent_id]:
		column.fill(0)
	for column: PackedInt64Array in [_agent_lease_expiry, _agent_blocked_tick,
			_agent_manual_until]:
		column.fill(0)
	_agent_present.fill(0)
	_agent_hazard_locked.fill(0)
	_continuation_bucket.fill(0)
	_deepest_continuation_bucket = -1
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

	`required_skill` is the minimum skill LEVEL 0-10 in the job's own kind (decision 0022).
	Refuses without allocating anything on an unknown or reserved kind, an out-of-int32 priority,
	a level outside 0-10, a negative work total or a negative creation tick, and passes a
	directory refusal through with its own ARCH-ID-004 code. Nothing is clamped: an invalid job
	definition is refused, so no row can exist carrying one.
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
	_admit(job_slot)
	return _succeed(job_slot, ref)


func _check_create_arguments(kind: int, priority: int, required_skill: int, remaining_mwu: int,
		created_tick: int) -> StringName:
	"""REFUSE_NONE when every create_job() argument is inside its specified domain.

	The kind and minimum-level halves are decision 0022's definition check, run through the one
	published `validate_job_definition()` so the two can never drift apart.
	"""
	var definition: OpResult = validate_job_definition(kind, required_skill)
	if not definition.ok:
		return definition.error
	if not IntMath.fits_int32(priority):
		return REFUSE_INVALID_PRIORITY
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
	_job_persistent_id[job_slot] = _directory.get_persistent_id(ref)
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
	_job_persistent_id[job_slot] = 0
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
	"""Insert a job into its declared-urgency run, keeping that run in ascending persistent ID.

	A freshly created job holds the largest ID in the store, so the backward walk terminates
	immediately; it only iterates when `set_urgency()` moves an older job into a new run.
	"""
	var bucket: int = _urgency[job_slot]
	var job_id: int = _job_persistent_id[job_slot]
	var index: int = _bucket_begin[bucket + 1]
	while index > _bucket_begin[bucket] and _job_persistent_id[_live_slots[index - 1]] > job_id:
		index -= 1
	var shift: int = _live_count
	while shift > index:
		_live_slots[shift] = _live_slots[shift - 1]
		shift -= 1
	_live_slots[index] = job_slot
	_live_count += 1
	_shift_bucket_begins(bucket, 1)


func _remove_live_slot(job_slot: int) -> void:
	"""Remove a job from its declared-urgency run, closing the gap it leaves."""
	var bucket: int = _urgency[job_slot]
	var index: int = _bucket_begin[bucket]
	var end: int = _bucket_begin[bucket + 1]
	while index < end and _live_slots[index] != job_slot:
		index += 1
	assert(index < end, "a live job must sit inside the run of the urgency it declares")
	if index >= end:
		return
	while index + 1 < _live_count:
		_live_slots[index] = _live_slots[index + 1]
		index += 1
	_live_count -= 1
	_live_slots[_live_count] = 0
	_shift_bucket_begins(bucket, -1)


func _shift_bucket_begins(bucket: int, delta: int) -> void:
	"""Move every run boundary above `bucket` by `delta` after one insertion or removal."""
	for higher: int in range(bucket + 1, URGENCY_COUNT + 1):
		_bucket_begin[higher] += delta


# --- Job readers ----------------------------------------------------------------------------------

func is_job_present(job_slot: int) -> bool:
	"""True when `job_slot` is in range and holds a live Job row."""
	return _check_job_slot(job_slot) == REFUSE_NONE


func job_count() -> int:
	"""Number of live Job rows."""
	return _live_count


func live_job_at(index: int) -> IntMath.IntResult:
	"""The job slot at `index` of the live index, ordered by declared urgency then persistent ID."""
	if index < 0 or index >= _live_count:
		return _read(REFUSE_INVALID_JOB_SLOT, 0)
	return _read(REFUSE_NONE, _live_slots[index])


func ref_of(job_slot: int) -> Vector2i:
	"""The directory reference owning a Job row, or the null reference when it is empty."""
	if not is_job_present(job_slot):
		return NULL_REF
	return Vector2i(_job_ref_slot[job_slot], _job_ref_generation[job_slot])


func job_id_of(job_slot: int) -> IntMath.IntResult:
	"""The never-reused persistent ID: the last tie-break of the §5.3 sort key, and the ID half of
	decision 0023's continuation key.

	Served from the cached column rather than the directory so the candidate loop, the ordered
	live index and this reader all agree on one number.
	"""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _job_persistent_id[job_slot] if code == REFUSE_NONE else 0)


func kind_of(job_slot: int) -> IntMath.IntResult:
	"""JobKind of a Job row, 0-11 and never the reserved index 3."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _kind[job_slot] if code == REFUSE_NONE else 0)


func priority_of(job_slot: int) -> IntMath.IntResult:
	"""Job.priority: the second term of the §5.3 within-bucket sort key, ascending."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _priority[job_slot] if code == REFUSE_NONE else 0)


func required_skill_of(job_slot: int) -> IntMath.IntResult:
	"""Job.required_skill: the MINIMUM LEVEL 0-10 the job's own skill demands (decision 0022)."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _required_skill[job_slot] if code == REFUSE_NONE else 0)


func skill_index_of(job_slot: int) -> IntMath.IntResult:
	"""The skill index eligibility step 4 tests, which decision 0022 fixes as `Job.kind` itself.

	Published as its own reader so a caller never has to rediscover that §4.3 makes JobKind and
	the skill index one enum; `required_skill` names the LEVEL, not the skill.
	"""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _kind[job_slot] if code == REFUSE_NONE else 0)


func validate_job_definition(kind: int, required_skill: int) -> OpResult:
	"""Decision 0022's definition check, without allocating a row: kind and minimum level.

	`required_skill` outside 0-10 is an INVALID JOB DEFINITION and any job of kind RESERVED_3 is
	an invalid productive job kind. Both are refused, never clamped, here and in `create_job()`,
	which runs exactly these tests.
	"""
	if kind < 0 or kind >= JOB_KIND_COUNT:
		return _refuse(REFUSE_INVALID_JOB_KIND)
	if kind == JOB_KIND_RESERVED_INDEX:
		return _refuse(REFUSE_RESERVED_JOB_KIND)
	if required_skill < SKILL_LEVEL_MIN or required_skill > SKILL_LEVEL_MAX:
		return _refuse(REFUSE_INVALID_REQUIRED_SKILL)
	return _succeed(required_skill, NULL_REF)


func skill_requirement_is_met(resident_slot: int, job_slot: int) -> bool:
	"""Decision 0022's test alone: `resident.skill_level[Job.kind] >= Job.required_skill`.

	Every party member is checked INDIVIDUALLY through this one resident-column read. A crew's
	average fishing skill belongs to the catch calculation, never to eligibility, and no party
	aggregate exists in this module.
	"""
	if not is_job_present(job_slot) or not _residents.is_present(resident_slot):
		return false
	var level: IntMath.IntResult = _residents.skill_level_of(resident_slot, _kind[job_slot])
	return level.ok and level.value >= _required_skill[job_slot]


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
	if _job_persistent_id[job_slot] != 0:
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
	var was_queued: bool = _state[job_slot] == JOB_STATE_QUEUED
	_state[job_slot] = state
	if state == JOB_STATE_QUEUED and not was_queued:
		_admit(job_slot)
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

	The job moves between runs of the ordered live index, and the write is an admission into the
	new bucket: any continuation that has already walked past this job's position is reset.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if urgency < 0 or urgency >= URGENCY_COUNT:
		return _refuse(REFUSE_INVALID_URGENCY)
	if urgency != _urgency[job_slot]:
		_remove_live_slot(job_slot)
		_urgency[job_slot] = urgency
		_insert_live_slot(job_slot)
		_admit(job_slot)
	return _succeed(urgency, ref_of(job_slot))


func set_dangerous(job_slot: int, dangerous: bool) -> OpResult:
	"""Mark a job as subject to eligibility step 5 and to REQ-SET-015's hazardous-work bar."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	var was_dangerous: bool = _dangerous[job_slot] == 1
	_dangerous[job_slot] = 1 if dangerous else 0
	if was_dangerous and not dangerous:
		_admit(job_slot)
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
	"""Validate and write one four-state eligibility gate.

	A gate that stops refusing makes the job newly available, so it is an admission: a
	continuation that has already walked past this job must not keep walking past it.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if gate < 0 or gate >= GATE_COUNT:
		return _refuse(REFUSE_INVALID_GATE)
	var was_refusing: bool = _gate_refuses(column[job_slot])
	column[job_slot] = gate
	if was_refusing and not _gate_refuses(gate):
		_admit(job_slot)
	return _succeed(gate, ref_of(job_slot))


func _gate_refuses(gate: int) -> bool:
	"""True for the two gate values that make a job ineligible: BLOCKED and UNAVAILABLE."""
	return gate == GATE_BLOCKED or gate == GATE_UNAVAILABLE


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

	Flipping it moves every declared FOOD_FUEL job between effective buckets 2 and 3 at once, so
	it is an admission into whichever bucket they land in, at the oldest of their persistent IDs.
	"""
	if below == _food_reserve_below_two_days:
		return
	_food_reserve_below_two_days = below
	if _bucket_begin[URGENCY_FOOD_FUEL] == _bucket_begin[URGENCY_FOOD_FUEL + 1]:
		return
	var oldest: int = _job_persistent_id[_live_slots[_bucket_begin[URGENCY_FOOD_FUEL]]]
	_admit_into(URGENCY_FOOD_FUEL if below else URGENCY_ORDINARY, oldest)


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
	"""Reset one JobAgent row: job, phase, target, reserved columns, continuation and hazard latch."""
	_set_ref_columns(resident_slot, NULL_REF, _agent_job_slot, _agent_job_generation)
	_set_ref_columns(resident_slot, NULL_REF, _agent_target_slot, _agent_target_generation)
	_agent_phase[resident_slot] = 0
	_agent_path_id[resident_slot] = 0
	_agent_path_cursor[resident_slot] = 0
	_agent_lease_expiry[resident_slot] = 0
	_agent_blocked_tick[resident_slot] = 0
	_agent_manual_until[resident_slot] = 0
	_job_scan_cursor[resident_slot] = 0
	_continuation_bucket[resident_slot] = 0
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


func continuation_job_id_of(resident_slot: int) -> IntMath.IntResult:
	"""The ID half of decision 0023's continuation key: the last job persistent ID examined.

	This is `ResidentRuntime.job_scan_cursor`. It is a job IDENTITY, never a position: persistent
	IDs are never reused, so insertions and deletions elsewhere in the index cannot change what a
	saved key means. 0 means no scan is in progress.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _job_scan_cursor[resident_slot] if code == REFUSE_NONE else 0)


func continuation_bucket_of(resident_slot: int) -> IntMath.IntResult:
	"""The bucket half of the continuation key: the urgency bucket the next pass resumes in."""
	var code: StringName = _check_agent_slot(resident_slot)
	return _read(code, _continuation_bucket[resident_slot] if code == REFUSE_NONE else 0)


func has_continuation(resident_slot: int) -> bool:
	"""True while a suspended scan is waiting to resume, i.e. the key is not (bucket 0, ID 0)."""
	if not is_agent_present(resident_slot):
		return false
	return _continuation_bucket[resident_slot] != 0 or _job_scan_cursor[resident_slot] != 0


func is_hazard_locked(resident_slot: int) -> bool:
	"""REQ-SET-015's latch: true from rest<=500 until rest>=4000, barring hazardous work."""
	return is_agent_present(resident_slot) and _agent_hazard_locked[resident_slot] == 1


# --- worker binding -------------------------------------------------------------------------------

func assign_worker(resident_slot: int, job_slot: int) -> OpResult:
	"""Bind a resident to a QUEUED, unworked job and move it to RESERVED.

	COMMITMENT REVALIDATES (decision 0023). Eligibility is re-run here, reading every gate column
	afresh, because a candidate nominated by an earlier `evaluate()` may have been overtaken:
	another job may have reserved its inputs, a station may have gone offline, or the resident's
	hour may have turned. A cached "inputs satisfied" cannot authorise this acceptance.

	Reserves nothing: REQ-SET-030's atomic input, output and destination-slot reservation belongs
	to the reservation pool, and the caller performs it before calling this.
	"""
	var code: StringName = _check_bind_arguments(resident_slot, job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _revalidate_for_commitment(resident_slot, job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	var job_ref: Vector2i = ref_of(job_slot)
	_set_ref_columns(job_slot, _residents.ref_of(resident_slot), _worker_slot, _worker_generation)
	_state[job_slot] = JOB_STATE_RESERVED
	_set_ref_columns(resident_slot, job_ref, _agent_job_slot, _agent_job_generation)
	_agent_phase[resident_slot] = JOB_STATE_RESERVED
	return _succeed(job_slot, job_ref)


func _revalidate_for_commitment(resident_slot: int, job_slot: int) -> StringName:
	"""Re-run the hazard latch and eligibility steps 1-6 at the moment of commitment.

	Every value is read from its column again here; nothing is carried over from the pass that
	nominated this job. The hazard latch is refreshed first because eligibility step 5 consults
	it, and a latch left over from an earlier tick would authorise hazardous work on stale rest.
	"""
	var latch: OpResult = refresh_hazard_latch(resident_slot)
	if not latch.ok:
		return latch.error
	var code: StringName = _load_resident_scratch(resident_slot)
	if code != REFUSE_NONE:
		return code
	return _job_eligibility(job_slot)


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
		_admit(job_slot)
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
	if _inputs_gate[job_slot] == GATE_UNAVAILABLE:
		return REFUSE_INPUTS_UNAVAILABLE
	return REFUSE_NONE


func _station_tool_skill_unlock_gate(job_slot: int, kind: int) -> StringName:
	"""Eligibility step 4, in §5.3's own order: station, tool, skill, unlock.

	Decision 0022 fixes the skill half: the skill index IS the job's kind, and the test is
	`resident.skill_level[kind] >= Job.required_skill`, a MINIMUM LEVEL. `create_job()` has
	already refused any definition outside 0-10, so no clamp is applied here.
	"""
	if _station_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_STATION_BLOCKED
	if _station_gate[job_slot] == GATE_UNAVAILABLE:
		return REFUSE_STATION_UNAVAILABLE
	if _tool_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_TOOL_BLOCKED
	if _tool_gate[job_slot] == GATE_UNAVAILABLE:
		return REFUSE_TOOL_UNAVAILABLE
	if _skill_scratch[kind] < _required_skill[job_slot]:
		return REFUSE_SKILL_TOO_LOW
	if _unlock_gate[job_slot] == GATE_BLOCKED:
		return REFUSE_UNLOCK_BLOCKED
	if _unlock_gate[job_slot] == GATE_UNAVAILABLE:
		return REFUSE_UNLOCK_UNAVAILABLE
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
	they already hold a job, and REFUSE_NO_ELIGIBLE_JOB when the candidates it examined offered
	nothing. Mutates only the hazard latch and the resident's continuation; the result is a
	NOMINATION that `assign_worker()` revalidates before it binds anything.
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
	"""Walk urgency buckets 0 -> 4 from the saved continuation, examining at most 32 candidates.

	The pass stops at the FIRST bucket that yielded an examined eligible candidate and returns the
	best of that bucket's examined candidates, so no lower-bucket job can ever be taken while a
	higher-bucket one was eligible. It descends only after exhausting a bucket without one. When
	the 32-candidate budget runs out first the continuation is saved and the pass refuses; nothing
	it failed to reach is marked ineligible.
	"""
	var bucket: int = _continuation_bucket[resident_slot]
	var after_id: int = _job_scan_cursor[resident_slot]
	var budget: int = CANDIDATE_BUDGET_PER_PASS
	_reset_best()
	while bucket < URGENCY_COUNT:
		budget = _examine_bucket(bucket, after_id, budget)
		if _best_slot >= 0:
			return _finish_scan(resident_slot)
		if budget <= 0:
			return _suspend_scan(resident_slot, bucket)
		bucket += 1
		after_id = 0
	return _finish_scan(resident_slot)


func _examine_bucket(bucket: int, after_id: int, budget: int) -> int:
	"""Examine one bucket's candidates in ascending persistent ID and return the budget left.

	Offers every eligible one to the incumbent comparison, so the winner is the best of those
	EXAMINED in this bucket -- approximate within the bucket, exact between buckets.
	"""
	_begin_bucket_walk(bucket, after_id)
	_walk_last_examined_id = after_id
	var remaining: int = budget
	while remaining > 0 and _advance_bucket_walk():
		remaining -= 1
		_walk_last_examined_id = _walk_job_id
		if _job_eligibility(_walk_slot) == REFUSE_NONE:
			_offer_candidate(_walk_slot)
	return remaining


func _finish_scan(resident_slot: int) -> OpResult:
	"""End a completed scan: clear the continuation and return the winner or an explicit refusal."""
	_job_scan_cursor[resident_slot] = 0
	_continuation_bucket[resident_slot] = 0
	if _best_slot < 0:
		return _refuse(REFUSE_NO_ELIGIBLE_JOB)
	return _succeed(_best_slot, ref_of(_best_slot))


func _suspend_scan(resident_slot: int, bucket: int) -> OpResult:
	"""Save `(bucket, last examined persistent ID)` and refuse, so the next pass resumes there.

	§5.3's budget "continues next pass when needed": the candidates this pass did not reach are
	UNEXAMINED, which is not the same as ineligible, and the next scheduled pass takes them up.
	"""
	_continuation_bucket[resident_slot] = bucket
	_job_scan_cursor[resident_slot] = _walk_last_examined_id
	if bucket > _deepest_continuation_bucket:
		_deepest_continuation_bucket = bucket
	return _refuse(REFUSE_NO_ELIGIBLE_JOB)


func _begin_bucket_walk(bucket: int, after_id: int) -> void:
	"""Position the walk at the first job of an EFFECTIVE bucket with a persistent ID > after_id.

	`_live_slots` is ordered by DECLARED urgency, so one effective bucket can span two runs: while
	the reserve is fine, declared FOOD_FUEL jobs rank as ordinary production and bucket 3 is the
	merge of runs 2 and 3. Bucket 2 is then empty -- no job occupies it at all.
	"""
	_walk_primary_index = 0
	_walk_primary_end = 0
	_walk_merged_index = 0
	_walk_merged_end = 0
	if bucket == URGENCY_FOOD_FUEL and not _food_reserve_below_two_days:
		return
	_walk_primary_index = _first_index_after(bucket, after_id)
	_walk_primary_end = _bucket_begin[bucket + 1]
	if bucket == URGENCY_ORDINARY and not _food_reserve_below_two_days:
		_walk_merged_index = _first_index_after(URGENCY_FOOD_FUEL, after_id)
		_walk_merged_end = _bucket_begin[URGENCY_FOOD_FUEL + 1]


func _first_index_after(run: int, after_id: int) -> int:
	"""Binary-search one run of the live index for the first entry with persistent ID > after_id."""
	var low: int = _bucket_begin[run]
	var high: int = _bucket_begin[run + 1]
	while low < high:
		var middle: int = low + ((high - low) >> 1)
		if _job_persistent_id[_live_slots[middle]] <= after_id:
			low = middle + 1
		else:
			high = middle
	return low


func _advance_bucket_walk() -> bool:
	"""Take the next job of the bucket in ascending persistent ID. False once it is exhausted.

	Two-pointer merge over the at most two runs an effective bucket spans, so the bucket still
	enumerates in one total order and the continuation key stays meaningful across the seam.
	"""
	var has_primary: bool = _walk_primary_index < _walk_primary_end
	var has_merged: bool = _walk_merged_index < _walk_merged_end
	if not has_primary and not has_merged:
		return false
	var take_primary: bool = has_primary
	if has_primary and has_merged:
		take_primary = _job_persistent_id[_live_slots[_walk_primary_index]] \
			< _job_persistent_id[_live_slots[_walk_merged_index]]
	if take_primary:
		_walk_slot = _live_slots[_walk_primary_index]
		_walk_primary_index += 1
	else:
		_walk_slot = _live_slots[_walk_merged_index]
		_walk_merged_index += 1
	_walk_job_id = _job_persistent_id[_walk_slot]
	return true


func _admit(job_slot: int) -> void:
	"""Record that a job became available, invalidating every continuation that could skip it."""
	_admit_into(_effective_urgency(job_slot), _job_persistent_id[job_slot])


func _admit_into(bucket: int, job_id: int) -> void:
	"""Reset every continuation a job admitted at `(bucket, job_id)` would otherwise be missed by.

	Decision 0023: "a newly available higher-urgency job invalidates a continuation into lower
	buckets". A continuation resuming in a LOWER-urgency (numerically larger) bucket has already
	descended past this one; a continuation in the SAME bucket has walked past every ID up to its
	key. Anything else would reach the job on its own, and is left alone so a resident scanning a
	long queue still makes progress. The single comparison below skips the walk entirely in the
	common case, where no resident is mid-scan at all.
	"""
	if bucket > _deepest_continuation_bucket:
		return
	var deepest: int = -1
	for slot: int in AGENT_CAPACITY:
		if _agent_present[slot] == 0:
			continue
		var resume_bucket: int = _continuation_bucket[slot]
		var resume_id: int = _job_scan_cursor[slot]
		if resume_bucket == 0 and resume_id == 0:
			continue
		if resume_bucket > bucket or (resume_bucket == bucket and job_id <= resume_id):
			_continuation_bucket[slot] = 0
			_job_scan_cursor[slot] = 0
		elif resume_bucket > deepest:
			deepest = resume_bucket
	_deepest_continuation_bucket = deepest


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
	var job_id: int = _job_persistent_id[job_slot]
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
