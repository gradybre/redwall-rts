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
## ---------------------------------------------------------------------------------------
## DECISION 0017'S COORDINATOR JOB IS BUILT HERE. A shared activity has one coordinator Job
## that outlives any individual worker, plus one member Job per worker:
##   * The coordinator has `worker = null` (`make_coordinator()` refuses a job that already has
##     one, and `assign_worker()` refuses a coordinator), CANNOT BE SELECTED BY A RESIDENT
##     (eligibility refuses it before any of the six steps, as a categorical exclusion rather
##     than a failed rule), and contributes no work -- `work.gd` computes a contribution only
##     from a member Job's own bound worker, never from the coordinator row.
##   * Member Jobs reference the coordinator through `_coordinator_slot/_coordinator_generation`,
##     an EntityRef pair like every other reference column here, and their SHARED-PHASE
##     `remaining_mwu` stays ZERO. That is enforced, not documented: `set_coordinator()` refuses
##     a member carrying progress, and `set_remaining_mwu()` refuses a nonzero write while a job
##     is a member. Members therefore cannot hold a copy of shared progress, which is the
##     mechanism by which per-member inflation -- the failure 0017 exists to prevent -- becomes
##     unrepresentable rather than merely untested. INTERPRETATION, NAMED: 0017 qualifies the
##     rule with "shared-phase", so a member Job with its OWN later personal phase (hauling an
##     output, say) is not addressed by the decision; this file takes the strict reading and a
##     caller that needs a personal allocation must `clear_coordinator()` first.
##   * Worker departure (`release_worker()`) touches the member's assignment only. Shared
##     progress lives on the coordinator row, so nothing here can discard it, and the member
##     link survives a departure: a shared-capable activity keeps its coordinator even when it
##     is down to one worker, or to none.
##   * `destroy_job()` refuses a coordinator that still has members, so no member can be left
##     pointing at a released row; destroying a member unlinks it from its coordinator first.
##   * ONLY THE COORDINATOR RECORDS COMPLETION -- this AMENDS ARCH-JOB-005, which gives
##     completion to every member Job. `work.gd` writes JOB_STATE_COMPLETE on the coordinator
##     and on nothing else, so a party of any size produces exactly one completion.
##
## Members are enumerated through an intrusive singly-linked list, `_member_head` on the
## coordinator row and `_member_next` on each member, so a party tick walks its own members with
## no allocation and no scan of the 8192 rows. Insertion is at the head, which is why the list
## order is arbitrary; nothing depends on it, because 0017's leftover tie-break is on ASCENDING
## RESIDENT PERSISTENT ID and `work.gd` applies that explicitly rather than relying on any
## enumeration order.
##
## A COORDINATOR STAYS IN THE LIVE CANDIDATE INDEX and is refused by eligibility, rather than
## being withheld from enumeration. It therefore costs a candidate from the 32-per-pass budget
## like any ineligible job. Named as a cost, not hidden: withholding it would put `job_count()`,
## `_bucket_begin` and every continuation key on two different notions of "live", and the budget
## is a throughput limit rather than a filter (above), so the only effect is that a settlement
## with many coordinators reaches a given job in more passes -- never that it cannot reach it.
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
## THIS STORE PUBLISHES `_into` FORMS FOR EVERY READER `work.gd` TAKES PER PRODUCTIVE TICK:
## `remaining_mwu_into()`, `state_into()`, `kind_into()`, `tool_gate_into()`,
## `resident_may_work_into()`, `agent_persistent_id_into()`, `first_member_into()` and
## `next_member_into()`. Each writes into a caller-owned IntResult and returns `out.ok`. The
## `tool_gate_of()` is written as a delegation to `tool_gate_into()` so the two cannot drift into
## disagreeing about a validation order or a refusal code. The older pairs still read their column
## twice through the shared `_read()` helper; converting them is a separate, unblocking change and
## is deliberately not made here.
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
##     live in `work.gd`, which owns the per-tick arithmetic, the retained remainders and the
##     0017 party split. This file owns the storage and the coordinator structure it runs on:
##     `remaining_mwu` is decremented ONLY through `consume_remaining_mwu_into()`, which refuses
##     to take more than the row holds, so no path here can drive a job's work total negative.
##   * REQ-SET-034's "finish at most the current 30-WU safe work segment" needs a segment
##     boundary that neither §5.3 nor ARCH-JOB-001 defines against the WU model, and is not
##     implemented. Nothing here or in `work.gd` claims a safe interruption point.
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
##             back into the directory -- the same trick `_agent_persistent_id` already uses),
##             and decision 0017's four coordinator columns: _is_coordinator (B8 8192),
##             _coordinator_slot/_coordinator_generation (I32 8192 x2, the member's EntityRef to
##             its coordinator -- "Member Jobs reference the coordinator"), and _member_head /
##             _member_next (I32 8192 x2, the intrusive member list that lets a party tick
##             enumerate its own members without allocating or scanning 8192 rows). 0017 states
##             that coordinator and member Jobs "both count against the existing 8192-row
##             capacity", which they do; the five columns are the per-row cost of that record.
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
# Decision 0017 coordinator refusals.
const REFUSE_COORDINATOR_JOB: StringName = &"COORDINATOR_JOB_NOT_SELECTABLE"
const REFUSE_NOT_A_COORDINATOR: StringName = &"JOB_IS_NOT_A_COORDINATOR"
const REFUSE_ALREADY_A_COORDINATOR: StringName = &"JOB_IS_ALREADY_A_COORDINATOR"
const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_A_PARTY_MEMBER"
const REFUSE_JOB_NOT_MEMBER: StringName = &"JOB_IS_NOT_A_PARTY_MEMBER"
const REFUSE_COORDINATOR_HAS_MEMBERS: StringName = &"COORDINATOR_STILL_HAS_MEMBERS"
const REFUSE_MEMBER_HOLDS_PROGRESS: StringName = &"MEMBER_MAY_NOT_HOLD_SHARED_PROGRESS"
const REFUSE_SELF_COORDINATION: StringName = &"JOB_MAY_NOT_COORDINATE_ITSELF"
const REFUSE_NO_MEMBERS: StringName = &"COORDINATOR_HAS_NO_MEMBERS"
const REFUSE_END_OF_MEMBERS: StringName = &"END_OF_MEMBER_LIST"
const REFUSE_MWU_UNDERFLOW: StringName = &"REMAINING_MWU_UNDERFLOW"
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
## Decision 0017. `_is_coordinator` flags the one Job per shared activity that owns the shared
## `remaining_mwu`, the lifecycle and completion; `_coordinator_slot/_coordinator_generation` is
## each member's EntityRef back to it; `_member_head` and `_member_next` are the intrusive list
## that enumerates a coordinator's members without allocating.
var _is_coordinator: PackedByteArray = PackedByteArray()
var _coordinator_slot: PackedInt32Array = PackedInt32Array()
var _coordinator_generation: PackedInt32Array = PackedInt32Array()
var _member_head: PackedInt32Array = PackedInt32Array()
var _member_next: PackedInt32Array = PackedInt32Array()
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
## Caller-owned reader output for internal eligibility paths. Values are consumed before reuse;
## no callback or signal can re-enter this module while one is live.
var _math: IntMath.IntResult = IntMath.IntResult.new()

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
## The bulk-column namespace's own refusal code (decision 0132). Category 3: not state, not
## persisted, and excluded from `state_bytes()` so a refusal cannot alter the image that proves
## it changed nothing.
var _last_column_refusal: StringName = REFUSE_NONE


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
			_job_ref_slot, _job_ref_generation, _live_slots, _job_persistent_id,
			_coordinator_slot, _coordinator_generation, _member_head, _member_next]:
		column.resize(JOB_CAPACITY)
	for column: PackedInt64Array in [_remaining_mwu, _created_tick]:
		column.resize(JOB_CAPACITY)
	for column: PackedByteArray in [_job_present, _urgency, _dangerous, _station_gate,
			_tool_gate, _unlock_gate, _inputs_gate, _is_coordinator]:
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
	_clear_job_columns()
	_clear_job_references()
	_clear_agents()
	_food_reserve_below_two_days = false
	_reset_best()


func _clear_job_columns() -> void:
	"""Refill every scalar Job column with its empty-row default. Split out to stay under 30."""
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
	_is_coordinator.fill(0)
	_member_head.fill(EntityDirectory.NULL_SLOT)
	_member_next.fill(EntityDirectory.NULL_SLOT)
	_live_slots.fill(0)
	_job_persistent_id.fill(0)
	_bucket_begin.fill(0)
	_live_count = 0


func _clear_job_references() -> void:
	"""Refill every Job EntityRef column pair with the null reference."""
	for column: PackedInt32Array in [_requester_slot, _destination_slot, _source_slot,
			_worker_slot, _job_ref_slot, _coordinator_slot]:
		column.fill(EntityDirectory.NULL_SLOT)
	for column: PackedInt32Array in [_requester_generation, _destination_generation,
			_source_generation, _worker_generation, _job_ref_generation,
			_coordinator_generation]:
		column.fill(EntityDirectory.NULL_GENERATION)


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
	_is_coordinator[job_slot] = 0
	_member_head[job_slot] = EntityDirectory.NULL_SLOT
	_member_next[job_slot] = EntityDirectory.NULL_SLOT
	_set_ref_columns(job_slot, NULL_REF, _coordinator_slot, _coordinator_generation)
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

	A coordinator that still has members is refused for the same reason: releasing it would
	leave every member Job pointing at a dead row, and 0017 requires shared progress and batch
	data to survive a departure, not to be deleted out from under the party. A member is
	unlinked from its coordinator here, which is the only structural change a destroy makes.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_JOB_HAS_WORKER)
	if _member_head[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_COORDINATOR_HAS_MEMBERS)
	if _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT:
		_unlink_member(job_slot)
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
	_is_coordinator[job_slot] = 0
	_member_head[job_slot] = EntityDirectory.NULL_SLOT
	_member_next[job_slot] = EntityDirectory.NULL_SLOT
	_set_ref_columns(job_slot, NULL_REF, _coordinator_slot, _coordinator_generation)
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
	"""Eligibility step 4's tool gate. No Equipment store exists; see the header.

	The ALLOCATING form. It delegates to `tool_gate_into()` rather than repeating the column read,
	so the per-tick caller and the convenience caller cannot ever answer differently: there is one
	validation order, one column and one refusal code between them.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	tool_gate_into(job_slot, out)
	return out


func tool_gate_into(job_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `tool_gate_of()`: write the tool gate into `out` and return out.ok.

	Decision 0110 records why this exists. `work.gd` must consult §5.3's tool gate ONCE PER
	CONTRIBUTOR PER PRODUCTIVE TICK to know whether a job requires a tool at all, and the
	allocating reader builds an `IntResult` on every one of those calls -- AGENTS.md's
	no-allocation-on-hot-paths rule forbids it, so until this form existed the gate simply was
	not read and a tool-required job whose worker held no binding produced work and wore nothing.

	The result is CALLER-OWNED: the caller passes its own long-lived scratch and this writes into
	it. An invalid slot or a row holding no live Job is an EXPLICIT REFUSAL carrying `out.error`,
	never GATE_NOT_REQUIRED -- the `false` return must not be read as a valid zero, because
	GATE_NOT_REQUIRED is itself 0 and "this job needs no tool" and "there is no job here" are
	opposite answers that a sentinel would merge.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_tool_gate[job_slot])


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
	if _is_coordinator[job_slot] != 0 or _member_head[job_slot] != EntityDirectory.NULL_SLOT:
		return false
	if _member_next[job_slot] != EntityDirectory.NULL_SLOT:
		return false
	if coordinator_of(job_slot) != NULL_REF:
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
	"""Write Job.remaining_mwu. Refuses a negative total rather than clamping it to zero.

	Decision 0017: a member Job's shared-phase `remaining_mwu` stays ZERO, so a nonzero write to
	a member is refused rather than stored. That is what makes per-member inflation
	unrepresentable: shared progress exists in exactly one row, the coordinator's.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if remaining_mwu < 0:
		return _refuse(REFUSE_INVALID_MWU)
	if remaining_mwu != 0 and _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_MEMBER_HOLDS_PROGRESS)
	_remaining_mwu[job_slot] = remaining_mwu
	return _succeed(remaining_mwu, ref_of(job_slot))


func remaining_mwu_into(job_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `remaining_mwu_of()`: write the outstanding work into `out`, return out.ok.

	`work.gd` reads this once per job per productive tick, so it publishes an `_into` form per
	AGENTS.md's no-allocation-on-hot-paths rule.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_remaining_mwu[job_slot])


func consume_remaining_mwu_into(job_slot: int, amount: int, out: IntMath.IntResult) -> bool:
	"""Subtract accepted milli-WU from a job's outstanding work; write the new total into `out`.

	THE ONLY DECREMENTING PATH. It refuses an amount larger than the row holds instead of
	clamping to zero or wrapping negative: decision 0017 caps acceptance at
	`min(remaining_mwu, sum(potential_i))`, so a caller asking for more has already miscomputed
	acceptance, and silently absorbing that would hide exactly the per-member inflation the
	coordinator exists to prevent. Refuses a negative amount for the same reason.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if amount < 0:
		return out.refuse(String(REFUSE_INVALID_MWU))
	if amount > _remaining_mwu[job_slot]:
		return out.refuse(String(REFUSE_MWU_UNDERFLOW))
	_remaining_mwu[job_slot] -= amount
	return out.succeed(_remaining_mwu[job_slot])


func state_into(job_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `state_of()`: write Job.state into `out` and return out.ok."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_state[job_slot])


func kind_into(job_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `kind_of()`: write Job.kind into `out` and return out.ok."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_kind[job_slot])


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


# --- decision 0017: the coordinator Job ----------------------------------------------------------

func make_coordinator(job_slot: int) -> OpResult:
	"""Promote a Job to decision 0017's coordinator: the row that owns a shared activity.

	A coordinator holds the sole authoritative `remaining_mwu` for the activity, survives worker
	replacement, and records the one completion. It has `worker = null` and cannot be selected,
	so a job that already has a worker, or that is itself a member of another party, is refused
	rather than converted. Idempotent conversion is refused too: promoting twice is a caller
	error, not a no-op to be swallowed.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _is_coordinator[job_slot] == 1:
		return _refuse(REFUSE_ALREADY_A_COORDINATOR)
	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_JOB_HAS_WORKER)
	if _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_JOB_IS_MEMBER)
	_is_coordinator[job_slot] = 1
	return _succeed(job_slot, ref_of(job_slot))


func is_coordinator(job_slot: int) -> bool:
	"""True when this live Job row is a shared activity's coordinator."""
	return _check_job_slot(job_slot) == REFUSE_NONE and _is_coordinator[job_slot] == 1


func is_member(job_slot: int) -> bool:
	"""True when this live Job row is a member of some coordinator's party."""
	if _check_job_slot(job_slot) != REFUSE_NONE:
		return false
	return _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT


func coordinator_of(job_slot: int) -> Vector2i:
	"""The EntityRef of this member's coordinator, or the null reference when it has none."""
	return _ref_of_columns(job_slot, _coordinator_slot, _coordinator_generation)


func set_coordinator(member_slot: int, coordinator_slot: int) -> OpResult:
	"""Attach a member Job to a coordinator, per decision 0017.

	Refuses a member that carries shared progress (`remaining_mwu != 0`), a member that is
	already in a party, a job coordinating itself, a coordinator that is not one, and a member
	that is itself a coordinator. Every one of those would put shared progress or lifecycle
	ownership in two places at once, which is the state 0017 exists to make unreachable.
	"""
	var code: StringName = _check_coordinator_link(member_slot, coordinator_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	_set_ref_columns(member_slot, ref_of(coordinator_slot), _coordinator_slot,
		_coordinator_generation)
	_member_next[member_slot] = _member_head[coordinator_slot]
	_member_head[coordinator_slot] = member_slot
	return _succeed(coordinator_slot, ref_of(coordinator_slot))


func _check_coordinator_link(member_slot: int, coordinator_slot: int) -> StringName:
	"""REFUSE_NONE when `member_slot` may legally join `coordinator_slot`'s party."""
	var code: StringName = _check_job_slot(member_slot)
	if code != REFUSE_NONE:
		return code
	code = _check_job_slot(coordinator_slot)
	if code != REFUSE_NONE:
		return code
	if member_slot == coordinator_slot:
		return REFUSE_SELF_COORDINATION
	if _is_coordinator[coordinator_slot] == 0:
		return REFUSE_NOT_A_COORDINATOR
	if _is_coordinator[member_slot] == 1:
		return REFUSE_ALREADY_A_COORDINATOR
	if _coordinator_slot[member_slot] != EntityDirectory.NULL_SLOT:
		return REFUSE_JOB_IS_MEMBER
	if _remaining_mwu[member_slot] != 0:
		return REFUSE_MEMBER_HOLDS_PROGRESS
	return REFUSE_NONE


func clear_coordinator(member_slot: int) -> OpResult:
	"""Detach a member Job from its party without touching the shared progress it never held."""
	var code: StringName = _check_job_slot(member_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _coordinator_slot[member_slot] == EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_JOB_NOT_MEMBER)
	_unlink_member(member_slot)
	return _succeed(member_slot, ref_of(member_slot))


func _unlink_member(member_slot: int) -> void:
	"""Remove one member from its coordinator's intrusive list and clear its coordinator ref."""
	var coordinator: int = _directory.get_typed_row(coordinator_of(member_slot))
	if coordinator != EntityDirectory.NULL_SLOT and _job_present[coordinator] == 1:
		var cursor: int = _member_head[coordinator]
		if cursor == member_slot:
			_member_head[coordinator] = _member_next[member_slot]
		else:
			while cursor != EntityDirectory.NULL_SLOT and _member_next[cursor] != member_slot:
				cursor = _member_next[cursor]
			if cursor != EntityDirectory.NULL_SLOT:
				_member_next[cursor] = _member_next[member_slot]
	_member_next[member_slot] = EntityDirectory.NULL_SLOT
	_set_ref_columns(member_slot, NULL_REF, _coordinator_slot, _coordinator_generation)


func first_member_into(coordinator_slot: int, out: IntMath.IntResult) -> bool:
	"""Write the first member's job slot into `out`; refuse REFUSE_NO_MEMBERS on an empty party.

	Paired with `next_member_into()` this walks a party allocation-free. An empty party is an
	explicit refusal, never a -1 slot masquerading as a row.
	"""
	var code: StringName = _check_job_slot(coordinator_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if _is_coordinator[coordinator_slot] == 0:
		return out.refuse(String(REFUSE_NOT_A_COORDINATOR))
	if _member_head[coordinator_slot] == EntityDirectory.NULL_SLOT:
		return out.refuse(String(REFUSE_NO_MEMBERS))
	return out.succeed(_member_head[coordinator_slot])


func next_member_into(member_slot: int, out: IntMath.IntResult) -> bool:
	"""Write the next member's job slot into `out`; refuse REFUSE_END_OF_MEMBERS at the tail."""
	var code: StringName = _check_job_slot(member_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if _member_next[member_slot] == EntityDirectory.NULL_SLOT:
		return out.refuse(String(REFUSE_END_OF_MEMBERS))
	return out.succeed(_member_next[member_slot])


func member_count_of(coordinator_slot: int) -> IntMath.IntResult:
	"""How many member Jobs this coordinator currently holds, by walking its member list."""
	var code: StringName = _check_job_slot(coordinator_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if _is_coordinator[coordinator_slot] == 0:
		return _read(REFUSE_NOT_A_COORDINATOR, 0)
	var count: int = 0
	var cursor: int = _member_head[coordinator_slot]
	while cursor != EntityDirectory.NULL_SLOT:
		count += 1
		cursor = _member_next[cursor]
	return _read(REFUSE_NONE, count)


func resident_may_work(resident_slot: int) -> OpResult:
	"""§5.3 eligibility step 1 as a published predicate: dead, incapacitated or collapsed refuses.

	`work.gd` needs the same gate on the PRODUCTIVE tick that selection applies at assignment --
	REQ-SET-015 cancels ordinary work at rest<=500 and REQ-SET-023 replaces an incapacitated
	resident's work with a rescue -- and publishing the one implementation is what stops a
	second, disagreeing copy of step 1 existing in another file.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not resident_may_work_into(resident_slot, out):
		return _refuse(StringName(out.error))
	return _succeed(out.value, _residents.ref_of(resident_slot))


func resident_may_work_into(resident_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `resident_may_work()`, preserving step 1's explicit refusal code in `out`."""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	code = _health_and_rescue_gate(resident_slot, out)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(resident_slot)


func agent_persistent_id_of(resident_slot: int) -> IntMath.IntResult:
	"""The never-reused persistent ID cached in this resident's JobAgent row.

	Decision 0017 breaks a leftover-milli-WU tie by ASCENDING RESIDENT PERSISTENT ID, and this
	is the copy that costs no directory call. Allocating; `agent_persistent_id_into()` is the
	form the tick path uses.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _agent_persistent_id[resident_slot])


func agent_persistent_id_into(resident_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `agent_persistent_id_of()`: write the cached ID into `out`, return out.ok.

	Decision 0024 makes this a LEFTOVER-ONLY read: `work.gd` calls it only on a finishing tick
	that actually has milli-WU left over after flooring, and never on an ordinary tick. It is an
	`_into` form all the same, so the one path that does need it allocates nothing per member.
	"""
	var code: StringName = _check_agent_slot(resident_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_agent_persistent_id[resident_slot])


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
	if _is_coordinator[job_slot] == 1:
		return REFUSE_COORDINATOR_JOB
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
	var code: StringName = _health_and_rescue_gate(resident_slot, _math)
	if code != REFUSE_NONE:
		return code
	var activity: IntMath.IntResult = _schedule.current_activity_of(resident_slot)
	if not activity.ok:
		return REFUSE_ACTIVITY_UNRESOLVED
	if activity.value != ACTIVITY_WORK and activity.value != ACTIVITY_ANYTHING:
		return REFUSE_ACTIVITY_FORBIDS_WORK
	return REFUSE_NONE


func _health_and_rescue_gate(resident_slot: int, out: IntMath.IntResult) -> StringName:
	"""Eligibility step 1: a dead, incapacitated or collapsed resident takes no job.

	REQ-SET-023 replaces an incapacitated resident's own work with a rescue job created for them,
	and REQ-SET-015 cancels ordinary work outright at rest<=500. Both are exclusions, not
	rankings: bucket 0 is about the job that rescues someone, never about the casualty working.
	"""
	if not _needs.status_into(resident_slot, out):
		return REFUSE_NEEDS_UNAVAILABLE
	if out.value == NeedsScript.STATUS_DEAD:
		return REFUSE_RESIDENT_DEAD
	if out.value == NeedsScript.STATUS_INCAPACITATED:
		return REFUSE_RESIDENT_INCAPACITATED
	if not _needs.need_into(resident_slot, NeedsScript.NEED_REST, out):
		return REFUSE_NEEDS_UNAVAILABLE
	if out.value <= REST_COLLAPSE_THRESHOLD:
		return REFUSE_REST_COLLAPSED
	return REFUSE_NONE


func _job_eligibility(job_slot: int) -> StringName:
	"""Eligibility steps 3-6 for one candidate, using the scratch loaded for this pass.

	Candidacy comes first and is not one of the six steps: a job already worked, or in any state
	but QUEUED, is not on offer at all. Decision 0017's coordinator is excluded ahead of even
	that, as a CATEGORICAL exclusion -- "cannot be selected by a resident" is a property of the
	record, not a rule it happens to fail, and it carries its own code so a caller is never told
	a coordinator was merely busy or unqueued.
	"""
	if _is_coordinator[job_slot] == 1:
		return REFUSE_COORDINATOR_JOB
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
	if not _needs.need_into(resident_slot, NeedsScript.NEED_REST, _math):
		return _refuse(REFUSE_NEEDS_UNAVAILABLE)
	if _math.value <= REST_COLLAPSE_THRESHOLD:
		_agent_hazard_locked[resident_slot] = 1
	elif _math.value >= REST_HAZARD_CLEAR_THRESHOLD:
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


# --- ARCH-SAVE-002 sections 4 and 5 bulk column API (decision 0132) ---------------------------
#
# This store owns rows in TWO sections and the registry numbers them in two separate ordinal
# spaces: §4 COMPONENT_COLUMNS carries thirty-eight columns and §5 CHILD_ARENAS carries the four
# coordinator/member columns of decision 0017. One `Columns` object carries both, because a
# restore of either half alone is not a state this store can hold: the member chain is only
# meaningful against the Job rows it links, and a half-applied pair is the worst outcome
# ARCH-SAVE-003 names. The two ORDER tables stay separate, so neither section's ordinals can
# drift into the other's.
#
# Before these landed a codec could read a job only through `kind_of()` and its siblings, which
# refuse a row whose `_job_present` is 0 -- so a released row's retained bytes, and the fact that
# `_clear_job_row()` really did leave no residue, were unreachable without reaching into
# `_kind` from another file. No module here reads another's private columns.
#
# CATEGORY 2, REBUILT AND NEVER CARRIED (the §8 JOB_INDEXES rows of this store):
# `_job_persistent_id` and `_agent_persistent_id` are caches of the directory's never-reused
# identity and are refilled from §3; `_live_slots` and `_bucket_begin` are the ordered index and
# are rebuilt ascending; `_live_count`, `_agent_count` and `_deepest_continuation_bucket` are
# counts of the columns above. None is read from the caller.
#
# ORDER OF RESTORE, WHICH IS A REAL DEPENDENCY AND NOT A PREFERENCE. §3 ENTITY_DIRECTORY must be
# restored before this call, because every live Job row's identity is resolved through the
# directory and `_job_persistent_id` is refilled from it. `residents.gd` must be restored before
# it too, because a JobAgent row exists only for a present resident and `_agent_persistent_id`
# comes from that store. Both are checked, not assumed: a reference the directory does not
# honour, or an agent on an absent resident, refuses.
#
# GENERATION NAMESPACES. `_job_ref_*`, `_requester_*`, `_destination_*`, `_source_*`,
# `_worker_*`, `_agent_job_*`, `_agent_target_*` and `_coordinator_*` are all DIRECTORY
# generations. This store holds no inventory container or lot handle and no navigation route
# handle, so none of the other three namespaces appears in any column here.

const COLUMN_TYPE_U8: int = 0
const COLUMN_TYPE_I32: int = 2
const COLUMN_TYPE_I64: int = 4

## The thirty-eight §4 COMPONENT_COLUMNS category-1 columns, in the registry's ordinal order.
const SECTION4_COLUMN_COUNT: int = 38
const SECTION4_COLUMN_KEYS: Array[StringName] = [
	&"_job_present", &"_agent_present", &"_kind", &"_requester_slot", &"_requester_generation",
	&"_destination_slot", &"_destination_generation", &"_source_slot", &"_source_generation",
	&"_priority", &"_required_skill", &"_state", &"_worker_slot", &"_worker_generation",
	&"_remaining_mwu", &"_created_tick", &"_job_ref_slot", &"_job_ref_generation",
	&"_urgency", &"_dangerous", &"_station_gate", &"_tool_gate", &"_unlock_gate",
	&"_inputs_gate", &"_is_coordinator", &"_agent_job_slot", &"_agent_job_generation",
	&"_agent_phase", &"_agent_target_slot", &"_agent_target_generation", &"_agent_path_id",
	&"_agent_path_cursor", &"_agent_lease_expiry", &"_agent_blocked_tick",
	&"_agent_manual_until", &"_agent_hazard_locked", &"_job_scan_cursor",
	&"_continuation_bucket",
]
const SECTION4_COLUMN_TYPE_CODES: Array[int] = [
	COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I64, COLUMN_TYPE_I64, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_U8,
	COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I32, COLUMN_TYPE_I64, COLUMN_TYPE_I64,
	COLUMN_TYPE_I64, COLUMN_TYPE_U8, COLUMN_TYPE_I32,
	COLUMN_TYPE_U8,
]
const SECTION4_COLUMN_EXTENTS: Array[int] = [
	JOB_CAPACITY, AGENT_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY,
	JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY,
	JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY,
	JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY,
	JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY,
	JOB_CAPACITY, JOB_CAPACITY, AGENT_CAPACITY, AGENT_CAPACITY,
	AGENT_CAPACITY, AGENT_CAPACITY, AGENT_CAPACITY, AGENT_CAPACITY,
	AGENT_CAPACITY, AGENT_CAPACITY, AGENT_CAPACITY,
	AGENT_CAPACITY, AGENT_CAPACITY, AGENT_CAPACITY,
	AGENT_CAPACITY,
]

## The four §5 CHILD_ARENAS category-1 columns, in that section's own ordinal order.
const SECTION5_COLUMN_COUNT: int = 4
const SECTION5_COLUMN_KEYS: Array[StringName] = [
	&"_coordinator_slot", &"_coordinator_generation", &"_member_head", &"_member_next",
]
const SECTION5_COLUMN_TYPE_CODES: Array[int] = [
	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
]
const SECTION5_COLUMN_EXTENTS: Array[int] = [
	JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY, JOB_CAPACITY,
]

## Bulk column refusals, read through `last_column_refusal()` and never through an OpResult.
## Every code is prefixed `COLUMN_`, so a load cannot clobber the reason a `create_job()` or an
## `assign_worker()` was refused before its caller read it, and no value is shared with those.
const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSE_COLUMN_PRESENT_BYTE: StringName = &"COLUMN_PRESENT_BYTE"
const REFUSE_COLUMN_FLAG_BYTE: StringName = &"COLUMN_FLAG_BYTE"
const REFUSE_COLUMN_URGENCY: StringName = &"COLUMN_URGENCY"
const REFUSE_COLUMN_GATE: StringName = &"COLUMN_GATE"
const REFUSE_COLUMN_JOB_DEFINITION: StringName = &"COLUMN_JOB_DEFINITION"
const REFUSE_COLUMN_JOB_STATE: StringName = &"COLUMN_JOB_STATE"
const REFUSE_COLUMN_NEGATIVE_MWU: StringName = &"COLUMN_NEGATIVE_MWU"
const REFUSE_COLUMN_NEGATIVE_TICK: StringName = &"COLUMN_NEGATIVE_TICK"
const REFUSE_COLUMN_REF_SHAPE: StringName = &"COLUMN_REF_SHAPE"
const REFUSE_COLUMN_DIRECTORY_REF: StringName = &"COLUMN_DIRECTORY_REF"
const REFUSE_COLUMN_FREE_JOB_ROW: StringName = &"COLUMN_FREE_JOB_ROW"
const REFUSE_COLUMN_FREE_AGENT_ROW: StringName = &"COLUMN_FREE_AGENT_ROW"
const REFUSE_COLUMN_AGENT_RESIDENT: StringName = &"COLUMN_AGENT_RESIDENT"
const REFUSE_COLUMN_RESERVED_NONZERO: StringName = &"COLUMN_RESERVED_NONZERO"
const REFUSE_COLUMN_CONTINUATION: StringName = &"COLUMN_CONTINUATION"
const REFUSE_COLUMN_WORKER_BINDING: StringName = &"COLUMN_WORKER_BINDING"
const REFUSE_COLUMN_COORDINATOR: StringName = &"COLUMN_COORDINATOR"
const REFUSE_COLUMN_MEMBER_CHAIN: StringName = &"COLUMN_MEMBER_CHAIN"


class Columns:
	"""Caller-owned image of the forty-two category-1 columns of sections 4 and 5.

	One object per save or per load, never one per job or per agent. Field order is the two
	ordinal tables above, §4 first and §5 last.
	"""
	var job_present: PackedByteArray = PackedByteArray()
	var agent_present: PackedByteArray = PackedByteArray()
	var kind: PackedInt32Array = PackedInt32Array()
	var requester_slot: PackedInt32Array = PackedInt32Array()
	var requester_generation: PackedInt32Array = PackedInt32Array()
	var destination_slot: PackedInt32Array = PackedInt32Array()
	var destination_generation: PackedInt32Array = PackedInt32Array()
	var source_slot: PackedInt32Array = PackedInt32Array()
	var source_generation: PackedInt32Array = PackedInt32Array()
	var priority: PackedInt32Array = PackedInt32Array()
	var required_skill: PackedInt32Array = PackedInt32Array()
	var state: PackedInt32Array = PackedInt32Array()
	var worker_slot: PackedInt32Array = PackedInt32Array()
	var worker_generation: PackedInt32Array = PackedInt32Array()
	var remaining_mwu: PackedInt64Array = PackedInt64Array()
	var created_tick: PackedInt64Array = PackedInt64Array()
	var job_ref_slot: PackedInt32Array = PackedInt32Array()
	var job_ref_generation: PackedInt32Array = PackedInt32Array()
	var urgency: PackedByteArray = PackedByteArray()
	var dangerous: PackedByteArray = PackedByteArray()
	var station_gate: PackedByteArray = PackedByteArray()
	var tool_gate: PackedByteArray = PackedByteArray()
	var unlock_gate: PackedByteArray = PackedByteArray()
	var inputs_gate: PackedByteArray = PackedByteArray()
	var is_coordinator: PackedByteArray = PackedByteArray()
	var agent_job_slot: PackedInt32Array = PackedInt32Array()
	var agent_job_generation: PackedInt32Array = PackedInt32Array()
	var agent_phase: PackedInt32Array = PackedInt32Array()
	var agent_target_slot: PackedInt32Array = PackedInt32Array()
	var agent_target_generation: PackedInt32Array = PackedInt32Array()
	var agent_path_id: PackedInt32Array = PackedInt32Array()
	var agent_path_cursor: PackedInt32Array = PackedInt32Array()
	var agent_lease_expiry: PackedInt64Array = PackedInt64Array()
	var agent_blocked_tick: PackedInt64Array = PackedInt64Array()
	var agent_manual_until: PackedInt64Array = PackedInt64Array()
	var agent_hazard_locked: PackedByteArray = PackedByteArray()
	var job_scan_cursor: PackedInt32Array = PackedInt32Array()
	var continuation_bucket: PackedByteArray = PackedByteArray()
	var coordinator_slot: PackedInt32Array = PackedInt32Array()
	var coordinator_generation: PackedInt32Array = PackedInt32Array()
	var member_head: PackedInt32Array = PackedInt32Array()
	var member_next: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Size all forty-two columns to their declared extents. The only place this resizes."""
		for column: PackedInt32Array in [kind, requester_slot, requester_generation,
				destination_slot, destination_generation, source_slot, source_generation,
				priority, required_skill, state, worker_slot, worker_generation, job_ref_slot,
				job_ref_generation, coordinator_slot, coordinator_generation, member_head,
				member_next]:
			column.resize(JOB_CAPACITY)
		for column: PackedInt64Array in [remaining_mwu, created_tick]:
			column.resize(JOB_CAPACITY)
		for column: PackedByteArray in [job_present, urgency, dangerous, station_gate, tool_gate,
				unlock_gate, inputs_gate, is_coordinator]:
			column.resize(JOB_CAPACITY)
		for column: PackedInt32Array in [agent_job_slot, agent_job_generation, agent_phase,
				agent_target_slot, agent_target_generation, agent_path_id, agent_path_cursor,
				job_scan_cursor]:
			column.resize(AGENT_CAPACITY)
		for column: PackedInt64Array in [agent_lease_expiry, agent_blocked_tick,
				agent_manual_until]:
			column.resize(AGENT_CAPACITY)
		for column: PackedByteArray in [agent_present, agent_hazard_locked, continuation_bucket]:
			column.resize(AGENT_CAPACITY)
		clear()

	func clear() -> void:
		"""Refill every column with the value this store's own `clear()` leaves, not with zero."""
		for column: PackedInt32Array in [priority, required_skill, agent_phase, agent_path_id,
				agent_path_cursor, job_scan_cursor]:
			column.fill(0)
		for column: PackedInt64Array in [remaining_mwu, created_tick, agent_lease_expiry,
				agent_blocked_tick, agent_manual_until]:
			column.fill(0)
		for column: PackedByteArray in [job_present, agent_present, dangerous, is_coordinator,
				agent_hazard_locked, continuation_bucket]:
			column.fill(0)
		for column: PackedByteArray in [station_gate, tool_gate, unlock_gate, inputs_gate]:
			column.fill(GATE_NOT_REQUIRED)
		kind.fill(JOB_KIND_HAUL)
		state.fill(JOB_STATE_QUEUED)
		urgency.fill(URGENCY_ORDINARY)
		for column: PackedInt32Array in [member_head, member_next]:
			column.fill(EntityDirectory.NULL_SLOT)
		for column: PackedInt32Array in [requester_slot, destination_slot, source_slot,
				worker_slot, job_ref_slot, coordinator_slot, agent_job_slot, agent_target_slot]:
			column.fill(EntityDirectory.NULL_SLOT)
		for column: PackedInt32Array in [requester_generation, destination_generation,
				source_generation, worker_generation, job_ref_generation,
				coordinator_generation, agent_job_generation, agent_target_generation]:
			column.fill(EntityDirectory.NULL_GENERATION)

	func equals(other: Columns) -> bool:
		"""True when all forty-two columns are byte-identical. Proves a refusal changed nothing."""
		return _job_columns_equal(other) and _agent_columns_equal(other) \
			and coordinator_slot == other.coordinator_slot \
			and coordinator_generation == other.coordinator_generation \
			and member_head == other.member_head and member_next == other.member_next

	func _job_columns_equal(other: Columns) -> bool:
		"""The twenty-five Job-indexed §4 columns, compared. Split to stay under 30 lines."""
		return job_present == other.job_present and kind == other.kind \
			and requester_slot == other.requester_slot \
			and requester_generation == other.requester_generation \
			and destination_slot == other.destination_slot \
			and destination_generation == other.destination_generation \
			and source_slot == other.source_slot \
			and source_generation == other.source_generation \
			and priority == other.priority and required_skill == other.required_skill \
			and state == other.state and worker_slot == other.worker_slot \
			and worker_generation == other.worker_generation \
			and remaining_mwu == other.remaining_mwu and created_tick == other.created_tick \
			and job_ref_slot == other.job_ref_slot \
			and job_ref_generation == other.job_ref_generation \
			and urgency == other.urgency and dangerous == other.dangerous \
			and station_gate == other.station_gate and tool_gate == other.tool_gate \
			and unlock_gate == other.unlock_gate and inputs_gate == other.inputs_gate \
			and is_coordinator == other.is_coordinator

	func _agent_columns_equal(other: Columns) -> bool:
		"""The thirteen JobAgent-indexed §4 columns, compared."""
		return agent_present == other.agent_present \
			and agent_job_slot == other.agent_job_slot \
			and agent_job_generation == other.agent_job_generation \
			and agent_phase == other.agent_phase \
			and agent_target_slot == other.agent_target_slot \
			and agent_target_generation == other.agent_target_generation \
			and agent_path_id == other.agent_path_id \
			and agent_path_cursor == other.agent_path_cursor \
			and agent_lease_expiry == other.agent_lease_expiry \
			and agent_blocked_tick == other.agent_blocked_tick \
			and agent_manual_until == other.agent_manual_until \
			and agent_hazard_locked == other.agent_hazard_locked \
			and job_scan_cursor == other.job_scan_cursor \
			and continuation_bucket == other.continuation_bucket


func last_column_refusal() -> StringName:
	"""The code from the most recent refused bulk column call, or REFUSE_NONE after a success.

	A SEPARATE channel from the OpResult every mutator returns. A caller reads a `create_job()`
	refusal off its own result; a save or load writing into that channel would make one operation
	report another's problem. Every code reachable here is prefixed `COLUMN_`.
	"""
	return _last_column_refusal


func copy_columns_into(out: Columns) -> bool:
	"""Copy the forty-two §4 and §5 category-1 columns into caller-owned buffers. False refuses.

	The capture step for both sections, and the ONLY way to read a released Job or JobAgent row's
	retained bytes: every reader here refuses a row whose occupancy byte is 0.

	The copies are snapshots; mutating `out` afterwards cannot reach a column.
	"""
	if not _columns_are_capacity_sized(out):
		_last_column_refusal = REFUSE_COLUMN_SHAPE
		return false
	_copy_job_columns_into(out)
	_copy_agent_columns_into(out)
	_refill_i32(out.coordinator_slot, _coordinator_slot)
	_refill_i32(out.coordinator_generation, _coordinator_generation)
	_refill_i32(out.member_head, _member_head)
	_refill_i32(out.member_next, _member_next)
	_last_column_refusal = REFUSE_NONE
	return true


func _copy_job_columns_into(out: Columns) -> void:
	"""Refill the twenty-five Job-indexed §4 buffers. Split out to stay under 30 lines."""
	_refill_bytes(out.job_present, _job_present)
	_refill_i32(out.kind, _kind)
	_refill_i32(out.requester_slot, _requester_slot)
	_refill_i32(out.requester_generation, _requester_generation)
	_refill_i32(out.destination_slot, _destination_slot)
	_refill_i32(out.destination_generation, _destination_generation)
	_refill_i32(out.source_slot, _source_slot)
	_refill_i32(out.source_generation, _source_generation)
	_refill_i32(out.priority, _priority)
	_refill_i32(out.required_skill, _required_skill)
	_refill_i32(out.state, _state)
	_refill_i32(out.worker_slot, _worker_slot)
	_refill_i32(out.worker_generation, _worker_generation)
	_refill_i64(out.remaining_mwu, _remaining_mwu)
	_refill_i64(out.created_tick, _created_tick)
	_refill_i32(out.job_ref_slot, _job_ref_slot)
	_refill_i32(out.job_ref_generation, _job_ref_generation)
	_refill_bytes(out.urgency, _urgency)
	_refill_bytes(out.dangerous, _dangerous)
	_refill_bytes(out.station_gate, _station_gate)
	_refill_bytes(out.tool_gate, _tool_gate)
	_refill_bytes(out.unlock_gate, _unlock_gate)
	_refill_bytes(out.inputs_gate, _inputs_gate)
	_refill_bytes(out.is_coordinator, _is_coordinator)


func _copy_agent_columns_into(out: Columns) -> void:
	"""Refill the thirteen JobAgent-indexed §4 buffers."""
	_refill_bytes(out.agent_present, _agent_present)
	_refill_i32(out.agent_job_slot, _agent_job_slot)
	_refill_i32(out.agent_job_generation, _agent_job_generation)
	_refill_i32(out.agent_phase, _agent_phase)
	_refill_i32(out.agent_target_slot, _agent_target_slot)
	_refill_i32(out.agent_target_generation, _agent_target_generation)
	_refill_i32(out.agent_path_id, _agent_path_id)
	_refill_i32(out.agent_path_cursor, _agent_path_cursor)
	_refill_i64(out.agent_lease_expiry, _agent_lease_expiry)
	_refill_i64(out.agent_blocked_tick, _agent_blocked_tick)
	_refill_i64(out.agent_manual_until, _agent_manual_until)
	_refill_bytes(out.agent_hazard_locked, _agent_hazard_locked)
	_refill_i32(out.job_scan_cursor, _job_scan_cursor)
	_refill_bytes(out.continuation_bucket, _continuation_bucket)


func restore_columns(columns: Columns) -> bool:
	"""Replace all forty-two columns and rebuild every derived index. False refuses.

	The apply step for sections 4 and 5 together. The store becomes the world these columns
	describe; a job slot taken before the call belongs to a different world.

	REBUILT, NEVER READ FROM THE CALLER: `_job_persistent_id` and `_agent_persistent_id` come back
	from §3 through the directory and the resident store, `_live_slots` and `_bucket_begin` are
	refilled in declared-urgency runs ordered by ascending persistent ID exactly as
	`_insert_live_slot()` keeps them, and `_live_count`, `_agent_count` and
	`_deepest_continuation_bucket` are recounted.

	THE REBUILD IS A VALIDATOR, not a repair. A live Job row's `(_job_ref_slot,
	_job_ref_generation)` must resolve through the directory to a live KIND_JOB slot whose typed
	row is this row: a directory slot owns exactly one typed row, so two Job rows claiming one
	slot cannot both satisfy it and neither can a row the directory has forgotten. The worker
	binding is checked in BOTH directions, because a job naming a worker who does not hold it and
	an agent holding a job that does not name it are different corruptions and one does not imply
	the other.

	Allocate before consume (decision 0059): every rule is checked before the first write, so a
	refusal leaves the store byte-identical and `state_bytes()` proves it by comparison.
	"""
	var refusal: StringName = _restore_column_refusal(columns)
	if refusal != REFUSE_NONE:
		_last_column_refusal = refusal
		return false
	_install_columns(columns)
	_rebuild_indexes()
	_last_column_refusal = REFUSE_NONE
	return true


func state_bytes() -> PackedByteArray:
	"""Diagnostic image of every member a restore can reach, for byte-identical rollback checks.

	NOT A PRODUCTION CALL: it allocates. Included: the forty-two persisted columns, both rebuilt
	persistent-ID caches, the live index over its live prefix, the bucket bounds and the three
	counters. Excluded: `_live_slots` beyond `_live_count`, which is stale residue two identical
	stores can disagree on, every `_best_*`/`_walk_*` scratch, and `_last_column_refusal`.
	"""
	var image: PackedByteArray = PackedByteArray()
	image.append_array(_job_present)
	image.append_array(_agent_present)
	for column: PackedInt32Array in [_kind, _requester_slot, _requester_generation,
			_destination_slot, _destination_generation, _source_slot, _source_generation,
			_priority, _required_skill, _state, _worker_slot, _worker_generation, _job_ref_slot,
			_job_ref_generation, _agent_job_slot, _agent_job_generation, _agent_phase,
			_agent_target_slot, _agent_target_generation, _agent_path_id, _agent_path_cursor,
			_job_scan_cursor, _coordinator_slot, _coordinator_generation, _member_head,
			_member_next, _job_persistent_id, _agent_persistent_id, _bucket_begin]:
		image.append_array(column.to_byte_array())
	for column: PackedInt64Array in [_remaining_mwu, _created_tick, _agent_lease_expiry,
			_agent_blocked_tick, _agent_manual_until]:
		image.append_array(column.to_byte_array())
	for column: PackedByteArray in [_urgency, _dangerous, _station_gate, _tool_gate,
			_unlock_gate, _inputs_gate, _is_coordinator, _agent_hazard_locked,
			_continuation_bucket]:
		image.append_array(column)
	image.append_array(_live_slots.slice(0, _live_count).to_byte_array())
	image.append_array(PackedInt64Array([_live_count, _agent_count,
		_deepest_continuation_bucket]).to_byte_array())
	return image


func _columns_are_capacity_sized(columns: Columns) -> bool:
	"""True when every one of the forty-two buffers is exactly its declared extent."""
	for column: PackedInt32Array in [columns.kind, columns.requester_slot,
			columns.requester_generation, columns.destination_slot,
			columns.destination_generation, columns.source_slot, columns.source_generation,
			columns.priority, columns.required_skill, columns.state, columns.worker_slot,
			columns.worker_generation, columns.job_ref_slot, columns.job_ref_generation,
			columns.coordinator_slot, columns.coordinator_generation, columns.member_head,
			columns.member_next]:
		if column.size() != JOB_CAPACITY:
			return false
	for column: PackedInt64Array in [columns.remaining_mwu, columns.created_tick]:
		if column.size() != JOB_CAPACITY:
			return false
	for column: PackedByteArray in [columns.job_present, columns.urgency, columns.dangerous,
			columns.station_gate, columns.tool_gate, columns.unlock_gate, columns.inputs_gate,
			columns.is_coordinator]:
		if column.size() != JOB_CAPACITY:
			return false
	return _agent_columns_are_capacity_sized(columns)


func _agent_columns_are_capacity_sized(columns: Columns) -> bool:
	"""True when every JobAgent-indexed buffer is exactly AGENT_CAPACITY long."""
	for column: PackedInt32Array in [columns.agent_job_slot, columns.agent_job_generation,
			columns.agent_phase, columns.agent_target_slot, columns.agent_target_generation,
			columns.agent_path_id, columns.agent_path_cursor, columns.job_scan_cursor]:
		if column.size() != AGENT_CAPACITY:
			return false
	for column: PackedInt64Array in [columns.agent_lease_expiry, columns.agent_blocked_tick,
			columns.agent_manual_until]:
		if column.size() != AGENT_CAPACITY:
			return false
	for column: PackedByteArray in [columns.agent_present, columns.agent_hazard_locked,
			columns.continuation_bucket]:
		if column.size() != AGENT_CAPACITY:
			return false
	return true


func _restore_column_refusal(columns: Columns) -> StringName:
	"""Every rule a restored column set must satisfy, checked before a single column is written."""
	if not _columns_are_capacity_sized(columns):
		return REFUSE_COLUMN_SHAPE
	var bytes: StringName = _column_byte_domain_refusal(columns)
	if bytes != REFUSE_NONE:
		return bytes
	var free_jobs: StringName = _column_free_job_refusal(columns)
	if free_jobs != REFUSE_NONE:
		return free_jobs
	var live_jobs: StringName = _column_live_job_refusal(columns)
	if live_jobs != REFUSE_NONE:
		return live_jobs
	var agents: StringName = _column_agent_refusal(columns)
	if agents != REFUSE_NONE:
		return agents
	var binding: StringName = _column_worker_binding_refusal(columns)
	if binding != REFUSE_NONE:
		return binding
	return _column_member_chain_refusal(columns)


func _column_byte_domain_refusal(columns: Columns) -> StringName:
	"""Every byte column holds only values its own enumeration declares (ARCH-SAVE-005)."""
	for column: PackedByteArray in [columns.job_present, columns.agent_present]:
		if not _byte_column_below(column, 2):
			return REFUSE_COLUMN_PRESENT_BYTE
	for column: PackedByteArray in [columns.dangerous, columns.is_coordinator,
			columns.agent_hazard_locked]:
		if not _byte_column_below(column, 2):
			return REFUSE_COLUMN_FLAG_BYTE
	for column: PackedByteArray in [columns.urgency, columns.continuation_bucket]:
		if not _byte_column_below(column, URGENCY_COUNT):
			return REFUSE_COLUMN_URGENCY
	for column: PackedByteArray in [columns.station_gate, columns.tool_gate, columns.unlock_gate,
			columns.inputs_gate]:
		if not _byte_column_below(column, GATE_COUNT):
			return REFUSE_COLUMN_GATE
	return REFUSE_NONE


func _column_free_job_refusal(columns: Columns) -> StringName:
	"""Every `_job_present == 0` row carries exactly what `_clear_job_row()` leaves behind.

	The same residue `inactive_job_row_is_clear()` asserts on the LIVE store, checked here on the
	incoming columns because nothing may be installed before it holds. `test_jobs.gd` runs that
	public reader over every free row after a successful restore, so the two cannot drift apart
	without a test failing.
	"""
	var slot: int = columns.job_present.find(0, 0)
	while slot >= 0:
		if not _free_job_row_is_clear(columns, slot):
			return REFUSE_COLUMN_FREE_JOB_ROW
		slot = columns.job_present.find(0, slot + 1)
	return REFUSE_NONE


func _free_job_row_is_clear(columns: Columns, slot: int) -> bool:
	"""True when one released Job row holds no residue of the job that last occupied it."""
	if columns.kind[slot] != JOB_KIND_HAUL or columns.priority[slot] != 0:
		return false
	if columns.required_skill[slot] != 0 or columns.state[slot] != JOB_STATE_QUEUED:
		return false
	if columns.remaining_mwu[slot] != 0 or columns.created_tick[slot] != 0:
		return false
	if columns.urgency[slot] != URGENCY_ORDINARY or columns.dangerous[slot] != 0:
		return false
	if columns.station_gate[slot] != GATE_NOT_REQUIRED:
		return false
	if columns.tool_gate[slot] != GATE_NOT_REQUIRED:
		return false
	if columns.unlock_gate[slot] != GATE_NOT_REQUIRED:
		return false
	if columns.inputs_gate[slot] != GATE_NOT_REQUIRED:
		return false
	if columns.is_coordinator[slot] != 0:
		return false
	if columns.member_head[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.member_next[slot] != EntityDirectory.NULL_SLOT:
		return false
	return _free_job_references_are_null(columns, slot)


func _free_job_references_are_null(columns: Columns, slot: int) -> bool:
	"""True when all six of a released Job row's reference pairs are the §4.1 null pair."""
	if columns.coordinator_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.coordinator_generation[slot] != EntityDirectory.NULL_GENERATION:
		return false
	if columns.job_ref_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.job_ref_generation[slot] != EntityDirectory.NULL_GENERATION:
		return false
	if columns.requester_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.destination_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.source_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	return columns.worker_slot[slot] == EntityDirectory.NULL_SLOT


func _column_live_job_refusal(columns: Columns) -> StringName:
	"""Each present Job row's definition, progress, reference shape and DIRECTORY identity."""
	var slot: int = columns.job_present.find(1, 0)
	while slot >= 0:
		var definition: OpResult = validate_job_definition(columns.kind[slot],
			columns.required_skill[slot])
		if not definition.ok:
			return REFUSE_COLUMN_JOB_DEFINITION
		if columns.state[slot] < 0 or columns.state[slot] >= JOB_STATE_COUNT:
			return REFUSE_COLUMN_JOB_STATE
		if columns.remaining_mwu[slot] < 0:
			return REFUSE_COLUMN_NEGATIVE_MWU
		if columns.created_tick[slot] < 0:
			return REFUSE_COLUMN_NEGATIVE_TICK
		if not _live_job_references_are_shaped(columns, slot):
			return REFUSE_COLUMN_REF_SHAPE
		var ref: Vector2i = Vector2i(columns.job_ref_slot[slot], columns.job_ref_generation[slot])
		if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_JOB):
			return REFUSE_COLUMN_DIRECTORY_REF
		if _directory.get_typed_row(ref) != slot:
			return REFUSE_COLUMN_DIRECTORY_REF
		slot = columns.job_present.find(1, slot + 1)
	return REFUSE_NONE


func _live_job_references_are_shaped(columns: Columns, slot: int) -> bool:
	"""True when a live Job row's five optional DIRECTORY pairs are null or well formed."""
	if not _is_well_formed_pair(columns.requester_slot[slot], columns.requester_generation[slot]):
		return false
	if not _is_well_formed_pair(columns.destination_slot[slot],
			columns.destination_generation[slot]):
		return false
	if not _is_well_formed_pair(columns.source_slot[slot], columns.source_generation[slot]):
		return false
	if not _is_well_formed_pair(columns.worker_slot[slot], columns.worker_generation[slot]):
		return false
	return _is_well_formed_pair(columns.coordinator_slot[slot],
		columns.coordinator_generation[slot])


func _is_well_formed_pair(slot: int, generation: int) -> bool:
	"""True for the §4.1 null pair `(-1, 0)` or any pair with slot >= 0 and generation > 0."""
	if slot == EntityDirectory.NULL_SLOT:
		return generation == EntityDirectory.NULL_GENERATION
	return slot >= 0 and generation > 0


func _column_agent_refusal(columns: Columns) -> StringName:
	"""Every JobAgent row: occupancy against the resident store, free-row residue, reserved zeros.

	A present agent requires a PRESENT RESIDENT, which is why `residents.gd` must be restored
	before this call; `_agent_persistent_id` is refilled from that store immediately afterwards.
	"""
	for slot: int in AGENT_CAPACITY:
		if columns.agent_present[slot] == 0:
			if not _free_agent_row_is_clear(columns, slot):
				return REFUSE_COLUMN_FREE_AGENT_ROW
			continue
		if not _residents.is_present(slot):
			return REFUSE_COLUMN_AGENT_RESIDENT
		if not _residents.persistent_id_of(slot).ok:
			return REFUSE_COLUMN_AGENT_RESIDENT
		var reserved: StringName = _reserved_agent_column_refusal(columns, slot)
		if reserved != REFUSE_NONE:
			return reserved
		if columns.agent_phase[slot] < 0 or columns.job_scan_cursor[slot] < 0:
			return REFUSE_COLUMN_CONTINUATION
		if not _is_well_formed_pair(columns.agent_job_slot[slot],
				columns.agent_job_generation[slot]):
			return REFUSE_COLUMN_REF_SHAPE
		if not _is_well_formed_pair(columns.agent_target_slot[slot],
				columns.agent_target_generation[slot]):
			return REFUSE_COLUMN_REF_SHAPE
	return REFUSE_NONE


func _reserved_agent_column_refusal(columns: Columns, slot: int) -> StringName:
	"""The five RESERVED-ALLOCATION-ONLY agent columns must be zero, as the registry states.

	`_agent_path_id`, `_agent_path_cursor`, `_agent_lease_expiry`, `_agent_blocked_tick` and
	`_agent_manual_until` have no writer: no pathfinder exists and REQ-SET-032/033 leases and
	ManualTask are unimplemented (blocker U6), so the registry says section 4 "must write them as
	zeros and MUST NOT repurpose these v1 bytes". Refusing a non-zero one is that rule enforced,
	not a new one; the rule moves the day those owners land, and this refusal is where it moves.
	"""
	if columns.agent_path_id[slot] != 0 or columns.agent_path_cursor[slot] != 0:
		return REFUSE_COLUMN_RESERVED_NONZERO
	if columns.agent_lease_expiry[slot] != 0 or columns.agent_blocked_tick[slot] != 0:
		return REFUSE_COLUMN_RESERVED_NONZERO
	if columns.agent_manual_until[slot] != 0:
		return REFUSE_COLUMN_RESERVED_NONZERO
	return REFUSE_NONE


func _free_agent_row_is_clear(columns: Columns, slot: int) -> bool:
	"""True when one released JobAgent row holds exactly what `_clear_agent_row()` leaves."""
	if columns.agent_job_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.agent_job_generation[slot] != EntityDirectory.NULL_GENERATION:
		return false
	if columns.agent_target_slot[slot] != EntityDirectory.NULL_SLOT:
		return false
	if columns.agent_target_generation[slot] != EntityDirectory.NULL_GENERATION:
		return false
	if columns.agent_phase[slot] != 0 or columns.agent_path_id[slot] != 0:
		return false
	if columns.agent_path_cursor[slot] != 0 or columns.agent_lease_expiry[slot] != 0:
		return false
	if columns.agent_blocked_tick[slot] != 0 or columns.agent_manual_until[slot] != 0:
		return false
	if columns.job_scan_cursor[slot] != 0 or columns.continuation_bucket[slot] != 0:
		return false
	return columns.agent_hazard_locked[slot] == 0


func _column_worker_binding_refusal(columns: Columns) -> StringName:
	"""The worker binding, checked in BOTH directions so neither half can be corrupt alone.

	A Job naming a worker who does not hold it, and an agent holding a Job that does not name it,
	are different corruptions and neither walk catches the other's. Both resolve through the
	directory and the resident store rather than trusting a stored pair.

	THERE IS NO THIRD CHECK, and the absence is deliberate. A count of bound agents against a
	count of worked jobs was written here first and then removed: each walk already proves its
	own row's opposite half resolves back to it, so the two maps are inverse wherever they are
	defined and the totals can never disagree. Mutation testing found it: deleting the comparison
	failed nothing, because nothing could reach it. An unfalsifiable check is not a validator.
	"""
	for slot: int in AGENT_CAPACITY:
		if columns.agent_present[slot] == 0:
			continue
		if columns.agent_job_slot[slot] == EntityDirectory.NULL_SLOT:
			continue
		var job_ref: Vector2i = Vector2i(columns.agent_job_slot[slot],
			columns.agent_job_generation[slot])
		if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
			return REFUSE_COLUMN_WORKER_BINDING
		var job_slot: int = _directory.get_typed_row(job_ref)
		if columns.job_present[job_slot] != 1:
			return REFUSE_COLUMN_WORKER_BINDING
		if Vector2i(columns.worker_slot[job_slot],
				columns.worker_generation[job_slot]) != _residents.ref_of(slot):
			return REFUSE_COLUMN_WORKER_BINDING
	return _column_job_worker_refusal(columns)


func _column_job_worker_refusal(columns: Columns) -> StringName:
	"""The other direction: every live Job naming a worker is held by exactly that agent.

	A worker pair that resolves to a present resident whose agent row names this very Job is the
	whole rule. `slot_of_ref()` refuses a stale or wrong-kind pair, so a Job naming a resident
	who has since been replaced in that slot is caught here and not merely counted.

	A resident with NO agent row at all needs no separate test, and the second mutation run that
	found the first redundancy found this one too: `_column_agent_refusal()` has already proved
	every `_agent_present == 0` row carries the null job pair, and a live Job's own reference is
	never null, so the comparison below refuses that case on its own. The ordering is therefore
	load-bearing -- agents are checked before the binding is -- and it is stated here rather than
	guarded by a line no input can reach.

	Only the SLOT half of the agent's job reference is compared, for the same reason. The walk
	above has already resolved that agent's full pair through the directory, and a directory slot
	carries exactly one live generation, so an equal slot with a different generation is a state
	the first walk refuses before this one runs. A third mutation run confirmed the generation
	comparison here could be deleted without failing anything.
	"""
	var slot: int = columns.job_present.find(1, 0)
	while slot >= 0:
		if columns.worker_slot[slot] != EntityDirectory.NULL_SLOT:
			var worker: Vector2i = Vector2i(columns.worker_slot[slot],
				columns.worker_generation[slot])
			var resident: IntMath.IntResult = _residents.slot_of_ref(worker)
			if not resident.ok:
				return REFUSE_COLUMN_WORKER_BINDING
			if columns.agent_job_slot[resident.value] != columns.job_ref_slot[slot]:
				return REFUSE_COLUMN_WORKER_BINDING
		slot = columns.job_present.find(1, slot + 1)
	return REFUSE_NONE


func _column_member_chain_refusal(columns: Columns) -> StringName:
	"""Decision 0017's party structure: every member is in exactly one coordinator's chain.

	Walked rather than counted, with a step cap of JOB_CAPACITY so a cycle refuses instead of
	hanging. A member appears in at most one chain because its own `_coordinator_slot` can name
	only one coordinator, and the totals then prove no member was left out of every chain. This
	is the §5 half of the same "the walk is the validator" property §3's owner map has.
	"""
	var walked: int = 0
	var slot: int = columns.job_present.find(1, 0)
	while slot >= 0:
		if columns.member_head[slot] != EntityDirectory.NULL_SLOT \
				and columns.is_coordinator[slot] != 1:
			return REFUSE_COLUMN_COORDINATOR
		if columns.is_coordinator[slot] == 1:
			var counted: int = _chain_length(columns, slot)
			if counted < 0:
				return REFUSE_COLUMN_MEMBER_CHAIN
			walked += counted
		slot = columns.job_present.find(1, slot + 1)
	if walked != _member_reference_count(columns):
		return REFUSE_COLUMN_MEMBER_CHAIN
	return REFUSE_NONE


func _chain_length(columns: Columns, coordinator: int) -> int:
	"""Members reachable from one coordinator, or -1 when the chain is malformed or cyclic."""
	var cursor: int = columns.member_head[coordinator]
	var steps: int = 0
	while cursor != EntityDirectory.NULL_SLOT:
		if cursor < 0 or cursor >= JOB_CAPACITY or columns.job_present[cursor] != 1:
			return -1
		if cursor == coordinator or columns.is_coordinator[cursor] == 1:
			return -1
		if _directory.get_typed_row(Vector2i(columns.coordinator_slot[cursor],
				columns.coordinator_generation[cursor])) != coordinator:
			return -1
		steps += 1
		if steps > JOB_CAPACITY:
			return -1
		cursor = columns.member_next[cursor]
	return steps


func _member_reference_count(columns: Columns) -> int:
	"""Live Job rows that name a coordinator, which every chain walk together must reach."""
	var total: int = 0
	var slot: int = columns.job_present.find(1, 0)
	while slot >= 0:
		if columns.coordinator_slot[slot] != EntityDirectory.NULL_SLOT:
			total += 1
		slot = columns.job_present.find(1, slot + 1)
	return total


func _install_columns(columns: Columns) -> void:
	"""Take a private copy of each validated column. `duplicate()` so the caller cannot alias one."""
	_kind = columns.kind.duplicate()
	_requester_slot = columns.requester_slot.duplicate()
	_requester_generation = columns.requester_generation.duplicate()
	_destination_slot = columns.destination_slot.duplicate()
	_destination_generation = columns.destination_generation.duplicate()
	_source_slot = columns.source_slot.duplicate()
	_source_generation = columns.source_generation.duplicate()
	_priority = columns.priority.duplicate()
	_required_skill = columns.required_skill.duplicate()
	_state = columns.state.duplicate()
	_worker_slot = columns.worker_slot.duplicate()
	_worker_generation = columns.worker_generation.duplicate()
	_remaining_mwu = columns.remaining_mwu.duplicate()
	_created_tick = columns.created_tick.duplicate()
	_job_present = columns.job_present.duplicate()
	_job_ref_slot = columns.job_ref_slot.duplicate()
	_job_ref_generation = columns.job_ref_generation.duplicate()
	_install_flag_columns(columns)
	_install_agent_columns(columns)


func _install_flag_columns(columns: Columns) -> void:
	"""Take a private copy of the eligibility flags and the four §5 chain columns."""
	_urgency = columns.urgency.duplicate()
	_dangerous = columns.dangerous.duplicate()
	_station_gate = columns.station_gate.duplicate()
	_tool_gate = columns.tool_gate.duplicate()
	_unlock_gate = columns.unlock_gate.duplicate()
	_inputs_gate = columns.inputs_gate.duplicate()
	_is_coordinator = columns.is_coordinator.duplicate()
	_coordinator_slot = columns.coordinator_slot.duplicate()
	_coordinator_generation = columns.coordinator_generation.duplicate()
	_member_head = columns.member_head.duplicate()
	_member_next = columns.member_next.duplicate()


func _install_agent_columns(columns: Columns) -> void:
	"""Take a private copy of every JobAgent-indexed column."""
	_agent_job_slot = columns.agent_job_slot.duplicate()
	_agent_job_generation = columns.agent_job_generation.duplicate()
	_agent_phase = columns.agent_phase.duplicate()
	_agent_target_slot = columns.agent_target_slot.duplicate()
	_agent_target_generation = columns.agent_target_generation.duplicate()
	_agent_path_id = columns.agent_path_id.duplicate()
	_agent_path_cursor = columns.agent_path_cursor.duplicate()
	_agent_lease_expiry = columns.agent_lease_expiry.duplicate()
	_agent_blocked_tick = columns.agent_blocked_tick.duplicate()
	_agent_manual_until = columns.agent_manual_until.duplicate()
	_agent_present = columns.agent_present.duplicate()
	_agent_hazard_locked = columns.agent_hazard_locked.duplicate()
	_job_scan_cursor = columns.job_scan_cursor.duplicate()
	_continuation_bucket = columns.continuation_bucket.duplicate()


func _rebuild_indexes() -> void:
	"""Refill every category-2 member from the INSTALLED columns, never from an input."""
	_rebuild_persistent_ids()
	_rebuild_live_index()
	_agent_count = _agent_present.count(1)
	_rebuild_deepest_continuation()
	_reset_best()


func _rebuild_persistent_ids() -> void:
	"""Refill both identity caches from §3: the directory for jobs, the resident store for agents.

	These are caches of the directory's never-reused persistent ID and are explicitly not carried
	in the section bytes. A free row caches 0, exactly as `_clear_job_row()` and
	`despawn_agent()` leave it.
	"""
	_job_persistent_id.fill(0)
	var slot: int = _job_present.find(1, 0)
	while slot >= 0:
		_job_persistent_id[slot] = _directory.get_persistent_id(
			Vector2i(_job_ref_slot[slot], _job_ref_generation[slot]))
		slot = _job_present.find(1, slot + 1)
	_agent_persistent_id.fill(0)
	var agent: int = _agent_present.find(1, 0)
	while agent >= 0:
		_agent_persistent_id[agent] = _residents.persistent_id_of(agent).value
		agent = _agent_present.find(1, agent + 1)


func _rebuild_live_index() -> void:
	"""Refill `_live_slots` and `_bucket_begin` in declared-urgency runs, ascending persistent ID.

	The arrangement `_insert_live_slot()` maintains, rebuilt rather than carried: a run's order
	depends on the SET of live jobs and their IDs, not on the insertion history, so a restored
	store offers candidates in the same order as the one that saved it. The sort key packs
	`(urgency, persistent id, slot)` into one int64 -- 3 bits, 31 bits and 13 bits -- so one sort
	orders every run at once. `keys` is cold-path local scratch, freed on return, not a column.
	"""
	var keys: PackedInt64Array = PackedInt64Array()
	var slot: int = _job_present.find(1, 0)
	while slot >= 0:
		keys.append((_urgency[slot] << 44) | (_job_persistent_id[slot] << 13) | slot)
		slot = _job_present.find(1, slot + 1)
	keys.sort()
	_live_slots.fill(0)
	_live_count = keys.size()
	for index: int in keys.size():
		_live_slots[index] = int(keys[index] & 0x1FFF)
	_bucket_begin.fill(_live_count)
	for bucket: int in range(URGENCY_COUNT, -1, -1):
		for index: int in range(_live_count - 1, -1, -1):
			if _urgency[_live_slots[index]] >= bucket:
				_bucket_begin[bucket] = index
	_bucket_begin[URGENCY_COUNT] = _live_count


func _rebuild_deepest_continuation() -> void:
	"""Recompute the upper bound on the deepest live continuation, exactly as `_admit_into()` does.

	A key of `(bucket 0, ID 0)` is no continuation at all, which is the same test the admission
	path applies; anything else contributes its bucket. -1 when no agent holds one.
	"""
	_deepest_continuation_bucket = -1
	var slot: int = _agent_present.find(1, 0)
	while slot >= 0:
		var bucket: int = _continuation_bucket[slot]
		if bucket != 0 or _job_scan_cursor[slot] != 0:
			if bucket > _deepest_continuation_bucket:
				_deepest_continuation_bucket = bucket
		slot = _agent_present.find(1, slot + 1)


func _byte_column_below(column: PackedByteArray, bound: int) -> bool:
	"""True when every byte is in [0, bound). One C++ count per legal value, no per-row loop."""
	var total: int = 0
	for value: int in range(bound):
		total += column.count(value)
	return total == column.size()


func _refill_bytes(out: PackedByteArray, source: PackedByteArray) -> void:
	"""Refill a caller's byte buffer in place with a snapshot of one column. One C++ copy."""
	out.clear()
	out.append_array(source)


func _refill_i32(out: PackedInt32Array, source: PackedInt32Array) -> void:
	"""Refill a caller's int32 buffer in place with a snapshot of one column. One C++ copy."""
	out.clear()
	out.append_array(source)


func _refill_i64(out: PackedInt64Array, source: PackedInt64Array) -> void:
	"""Refill a caller's int64 buffer in place with a snapshot of one column. One C++ copy."""
	out.clear()
	out.append_array(source)
