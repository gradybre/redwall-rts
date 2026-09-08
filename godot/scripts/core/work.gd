extends RefCounted
## The GDD §5.2 work-unit model, §5.3 skill XP, and decision 0017's shared-party acceptance.
##
## ---------------------------------------------------------------------------------------
## THE PER-TICK FORMULA, verbatim from GDD §5.2:
##
##   "Skill factor=`1000+50*level`; total work factor=clamp(floor(skill*mood*health/1000000),
##    300,1800). Each work tick produces 80 milli-WU x factor/1000 with retained remainder;
##    travel/eating/social/sleep do not produce job output."
##
## THE FACTOR IS NOT RECOMPUTED HERE. `needs.gd` already publishes `work_factor(skill_level,
## mood, health)` -- with `skill_factor()`, `mood_factor()` and `health_factor()` under it -- and
## that implementation is verified against the §7.1 mood fixture. This file calls it. There is no
## second copy of 1000+50*level, of the five mood bands, or of the 300/1800 clamp anywhere in
## this module, so the two can never disagree.
##
## THE RETAINED REMAINDER. `80 * factor` is a numerator over 1000, and at every factor except a
## multiple of 12.5 it is not a whole number of milli-WU. §5.2 says "with retained remainder", so
## the leftover is carried, exactly as `needs.gd`'s `_integrate_step()` carries the sub-point
## remainder of an hourly need rate -- THE SAME DISCIPLINE AT A DIFFERENT DENOMINATOR. Needs
## divides an hourly rate by 750 ticks x 1000 milli-points; work divides a PER-TICK numerator by
## the factor's own 1000, because §5.2 states the work rate per tick and the need rates per game
## hour. Nothing here is per hour and nothing here divides by 750.
##
##   accumulator = retained + 80 * factor        (retained is 0..999, in milli-WU/1000)
##   produced    = accumulator / 1000            (whole milli-WU released this tick)
##   retained    = accumulator - produced * 1000
##
## Every term is nonnegative -- the factor clamp floors at 300 -- so truncation and floor agree
## and no signed-remainder case arises. The accumulator peaks at 999 + 80*1800 = 144999, far
## inside int32, which is why the carry is a packed int32 column rather than an object per
## resident. THE CARRY IS PER RESIDENT, not per job: BAL-NUM-001 requires a rate's fraction to
## survive "ticks, task switches, saves, and worker changes", and it is a property of how fast
## that worker works, not of what they are working on.
##
## ---------------------------------------------------------------------------------------
## XP, from GDD §5.3: "XP is 10 per completed productive WU in the corresponding job skill."
##
## A whole WU is 1000 milli-WU, and a tick contributes at most 144 of them, so XP MUST NOT be
## credited from a fractional contribution. Each (resident, skill) pair keeps its own milli-WU
## accumulator; XP is awarded only on the tick the 1000 threshold is genuinely crossed, and the
## surplus stays in the accumulator for the next WU. Crediting `10 * accepted / 1000` per tick
## would round every partial tick to zero and lose XP outright; crediting 10 per tick with work
## in it would inflate it roughly sevenfold. Neither is what §5.3 says.
##
## The accumulator is PER RESIDENT AND PER SKILL (decision 0017, "retain fractional XP progress
## separately per resident and skill"), so switching from COOK to CRAFT does not spend cooking
## progress on crafting. Skills never decay, so nothing here ever subtracts XP; `residents.gd`
## owns the XP columns and the §5.3 level curve and re-derives the level on every write.
##
## XP COMES FROM ACCEPTED WORK ONLY (0017). On a finishing tick the party's potential exceeds
## what the activity still needs, and the excess is not work anyone did on it.
##
## ---------------------------------------------------------------------------------------
## DECISION 0017, THE PARTY MODEL, implemented exactly as ruled:
##
##   potential_i    = each worker's contribution per BAL-WORK-001
##   accepted_total = min(remaining_mwu, sum(potential_i))
##   remaining_mwu -= accepted_total
##
## `remaining_mwu` is read from and written to the COORDINATOR row and nowhere else, so a party
## of eight advances a 120-WU activity at eight workers' combined rate, never eight times over.
## PER-MEMBER INFLATION IS UNREPRESENTABLE, not merely untested: `jobs.gd` refuses a nonzero
## `remaining_mwu` on any member row, so there is no second place for shared progress to live.
##
## On the finishing tick -- the only tick where `accepted_total < sum(potential_i)` -- acceptance
## is allocated proportionally: `floor(accepted_total * potential_i / sum)` each, then the
## leftover milli-WU are handed out by LARGEST FRACTIONAL REMAINDER, ties broken by ASCENDING
## RESIDENT PERSISTENT ID. Persistent IDs are never reused, so that tie-break is total and
## reproducible across a save. On every other tick acceptance equals the sum of the potentials
## and each worker is credited their own, with no division performed at all.
##
## IDENTITIES ARE READ LAZILY (decision 0024). A persistent ID decides nothing except a tie
## between two equal fractional remainders, so it is fetched only on a finishing tick that still
## has milli-WU left over after flooring, and then exactly once per frozen contributor into the
## scratch column that already existed for it. An ordinary tick performs ZERO identity reads, and
## so does a finishing tick whose floored shares happen to leave nothing over.
##
## WHERE THAT FETCH SITS, AND WHY. `_commit()` consumes the coordinator's outstanding work BEFORE
## the leftover is handed out. A read that can refuse therefore cannot live in
## `_distribute_leftover()`, which runs after that subtraction: a refusal there would abandon a
## tick whose shared progress had already been spent. `_allocate_shares()` runs BEFORE the
## subtraction, computes the floored shares, learns the leftover and loads the identities there,
## so every identity-read refusal is resolved while the activity's remaining work and every XP
## column are still untouched. The order of store mutations -- consume, then XP, then completion
## -- is exactly what it was.
##
## PASSIVE WAITING NEVER ACCELERATES WITH CREW SIZE, and cannot here: work is produced only from
## a member Job's own bound worker in JOB_STATE_WORK, so a coordinator with no contributing
## member produces nothing however many rows point at it.
##
## COMPLETION BELONGS TO THE COORDINATOR -- THIS AMENDS ARCH-JOB-005, which gives completion to
## every member Job. `_finish()` writes JOB_STATE_COMPLETE on the coordinator row and on no
## other, and a second tick against a completed coordinator is refused rather than producing a
## second completion. Worker departure releases that worker's member assignment only: shared
## progress lives on the coordinator, which no departure path touches. Only explicit
## cancellation invokes refunds, and no refund path exists in this file at all.
##
## ---------------------------------------------------------------------------------------
## WHAT COUNTS AS A PRODUCTIVE TICK. §5.2: "travel/eating/social/sleep do not produce job
## output." A contribution is computed only when ALL of these hold, and each is read from its
## own column at the moment of the tick:
##   * the Job is in JOB_STATE_WORK -- JOB_STATE_TRAVEL, RESERVED and HAUL_OUTPUT are the same
##     row in a non-producing phase, and eating, social and sleep are not Jobs at all,
##   * the Job has a live bound worker with a live JobAgent row,
##   * `jobs.resident_may_work_into()` passes -- §5.3 eligibility step 1, the ONE implementation,
##     called rather than copied, so REQ-SET-015's rest<=500 cancellation and REQ-SET-023's
##     incapacity exclusion apply on the productive tick and not only at assignment.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md "do not invent a constant"):
##   * BAL-WORK-001'S WEATHER, DARKNESS AND WORKSHOP FACTORS ARE NOT APPLIED. That rule ends
##     "Apply weather, darkness, and workshop factors as additional rational factors with one
##     final floor and retained remainder", and no weather store, lighting model or workshop
##     store exists in this milestone. Neither §5.9 nor §5.10 fixes their numerators, so no value
##     is invented for them and none is silently defaulted to 1000 inside the arithmetic: the
##     numerator here is `80 * F` and nothing else. The structure is the one that rule requires
##     -- ONE floor over the whole product, with the residue retained -- so those factors extend
##     `_produce_potential()`'s single numerator when they land, rather than adding a second
##     division that would floor twice and lose work each tick.
##   * ARCH-JOB-001 says passive wait is "a saved phase within WORK", and §5.3 says passive waits
##     "advance calendar time once and do not accelerate with crew count". NO PASSIVE-WAIT FLAG
##     EXISTS on the Job row and neither document fixes one, so this file cannot distinguish an
##     actively worked WORK tick from a passively waiting one. A caller that has a passive wait
##     must not call these functions for it; nothing here can detect the difference. Reported,
##     not papered over with an invented column.
##   * §5.2's purpose restoration, "+320/hour of completed useful labor", is a needs input:
##     `needs.set_purpose_source()` owns it and this file does not write it. Wiring productive
##     work to that source needs the activity/task layer, and `needs.gd` is not this task's file.
##   * REQ-SET-034's "finish at most the current 30-WU safe work segment" needs a segment
##     boundary that no document defines against this model; no interruption point is claimed.
##   * §5.3's "A completed batch's quality uses its lead worker's level at batch start" needs a
##     lead-worker field and a batch/recipe store, neither of which exists. `_finish()` records
##     completion and nothing else -- no outputs, no cycle wear, no cycle roll -- which is the
##     honest subset of 0017's "only the coordinator creates outputs ... and records completion"
##     that is implementable with no production system in the milestone.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. Every column is sized once in `_init()` and nothing outside `_allocate_columns()`
## calls `resize()`. The party walk, acceptance arithmetic, proportional split and remainder
## carries run on packed columns through one reused IntResult. The factor and resident work-gate
## reader chains use caller-owned `_into` forms; each live value is copied into an integer before
## that scratch is reused, so nested reads cannot alias an input. The leftover-only persistent-ID
## read uses `jobs.agent_persistent_id_into()` and allocates nothing either. The escaping
## TickResult and the XP mutator result retain their existing allocations. Allocating reader
## wrappers remain fresh for cold paths and callers that keep a result.
##
## REFUSAL, NOT SENTINELS. Every operation returns a TickResult or an OpResult whose `.ok` must
## be inspected, and a refusal carries zero work, zero contributors and `completed = false`. "No
## contributor this tick" is REFUSE_NO_CONTRIBUTORS, never a silent zero that a caller could read
## as progress.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")

# --- capacities -----------------------------------------------------------------------------

## One carry per resident row; `_init()` asserts this equals the needs store's capacity.
const RESIDENT_CAPACITY: int = NeedsScript.RESIDENT_CAPACITY
## GDD §4.3's twelve skill/job kinds; the XP accumulator is one row per resident per skill.
const SKILL_COUNT: int = ResidentsScript.SKILL_COUNT
## §5.1 fixes index 3 at XP and level 0; `residents.gd` refuses a write to it and so does this.
const SKILL_RESERVED_INDEX: int = ResidentsScript.SKILL_RESERVED_INDEX
## A party cannot exceed one contributing worker per resident row: a JobAgent holds at most one
## active job, so no more than RESIDENT_CAPACITY member Jobs can be producing at once.
const PARTY_CAPACITY: int = RESIDENT_CAPACITY

# --- GDD §5.2 / §5.3 constants ----------------------------------------------------------------

## §5.2 "Each work tick produces 80 milli-WU x factor/1000".
const BASE_MWU_PER_TICK: int = 80
## The denominator of that factor, which `needs.gd` scales to 1000.
const WORK_FACTOR_DENOMINATOR: int = NeedsScript.MOOD_FACTOR_DENOMINATOR
## §5.3's WU, in the milli-WU the Job column stores.
const MILLI_WU_PER_WU: int = 1000
## §5.3 "XP is 10 per completed productive WU in the corresponding job skill."
const XP_PER_WU: int = 10
## §5.2's factor clamp, borrowed rather than restated, and the potential ceiling it implies.
const WORK_FACTOR_MIN: int = NeedsScript.WORK_FACTOR_MIN
const WORK_FACTOR_MAX: int = NeedsScript.WORK_FACTOR_MAX
const MAX_POTENTIAL_MWU: int = BASE_MWU_PER_TICK * WORK_FACTOR_MAX / WORK_FACTOR_DENOMINATOR

const JOB_STATE_WORK: int = JobsScript.JOB_STATE_WORK
const JOB_STATE_COMPLETE: int = JobsScript.JOB_STATE_COMPLETE
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- refusal codes ---------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_RESIDENT_SLOT: StringName = &"INVALID_RESIDENT_SLOT"
const REFUSE_INVALID_SKILL: StringName = &"INVALID_SKILL"
const REFUSE_RESERVED_SKILL: StringName = &"RESERVED_SKILL_INDEX"
const REFUSE_INVALID_MEMORY_TOTAL: StringName = &"INVALID_MEMORY_TOTAL"
const REFUSE_JOB_IS_COORDINATOR: StringName = &"JOB_IS_A_COORDINATOR"
const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_A_PARTY_MEMBER"
const REFUSE_NOT_A_COORDINATOR: StringName = &"JOB_IS_NOT_A_COORDINATOR"
const REFUSE_JOB_NOT_WORKING: StringName = &"JOB_NOT_IN_WORK_STATE"
const REFUSE_JOB_HAS_NO_WORKER: StringName = &"JOB_HAS_NO_WORKER"
const REFUSE_NO_WORK_REMAINING: StringName = &"NO_WORK_REMAINING"
const REFUSE_NO_CONTRIBUTORS: StringName = &"NO_CONTRIBUTING_WORKER"
const REFUSE_PARTY_TOO_LARGE: StringName = &"PARTY_EXCEEDS_CAPACITY"
const REFUSE_MEMBER_MISLINKED: StringName = &"MEMBER_LINKS_TO_ANOTHER_COORDINATOR"
const REFUSE_NEEDS_UNAVAILABLE: StringName = &"NEEDS_ROW_UNAVAILABLE"
const REFUSE_SKILLS_UNAVAILABLE: StringName = &"SKILLS_ROW_UNAVAILABLE"
const REFUSE_FACTOR_UNAVAILABLE: StringName = &"WORK_FACTOR_UNAVAILABLE"
const REFUSE_XP_WRITE_FAILED: StringName = &"SKILL_XP_WRITE_REFUSED"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"


class TickResult:
	"""Outcome of one productive tick against one activity.

	`.ok` MUST be inspected before any other field. A refusal carries zero accepted work, zero
	contributors and `completed = false`, so an ignored refusal cannot read as quiet progress.
	"""
	var ok: bool
	var error: StringName
	var accepted_mwu: int
	var remaining_mwu: int
	var contributor_count: int
	var completed: bool

	func _init(p_ok: bool, p_error: StringName) -> void:
		"""Build a result in its refused shape; a success fills the fields afterwards."""
		ok = p_ok
		error = p_error
		accepted_mwu = 0
		remaining_mwu = 0
		contributor_count = 0
		completed = false


class OpResult:
	"""Outcome of one non-tick operation: success flag, refusal code, produced value."""
	var ok: bool
	var error: StringName
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value


# --- collaborating stores ---------------------------------------------------------------------

var _jobs: JobsScript = null
var _residents: ResidentsScript = null
var _needs: NeedsScript = null
var _directory: EntityDirectory = null

# --- simulation state (ARCH-MEM-001: packed, allocated once) -----------------------------------

## §5.2's retained work remainder, in milli-WU/1000, one per resident. Always 0..999.
var _potential_remainder: PackedInt32Array = PackedInt32Array()
## §5.3's fractional XP progress, in milli-WU, one per (resident, skill). Always 0..999.
var _xp_remainder: PackedInt32Array = PackedInt32Array()
## REQ-SET-020's `sum(memory_values)` for each resident, an explicit input with an honest default
## of 0. `needs.mood_of()` takes it as an argument because blocker U6 leaves the MoodMemory child
## store's owner-major index formula unspecified and no such store exists; carrying it here is
## the same convention `jobs.gd` uses for its four eligibility gates, NOT a second source of
## truth for memories -- there is no first one yet.
var _memory_total: PackedInt32Array = PackedInt32Array()

# --- per-tick scratch (not simulation state) ---------------------------------------------------

## The contributing members of the party being ticked, filled by `_collect_contributors()` and
## consumed before that call's caller returns. Packed so a party tick allocates nothing.
var _party_job: PackedInt32Array = PackedInt32Array()
var _party_resident: PackedInt32Array = PackedInt32Array()
var _party_skill: PackedInt32Array = PackedInt32Array()
var _party_persistent_id: PackedInt32Array = PackedInt32Array()
var _party_potential: PackedInt32Array = PackedInt32Array()
var _party_share: PackedInt64Array = PackedInt64Array()
## `accepted_total * potential_i mod sum_potential`, the fractional part of a proportional share,
## which decides who receives a leftover milli-WU. -1 marks a share already topped up.
var _party_fraction: PackedInt64Array = PackedInt64Array()

var _party_count: int = 0
## How many rows of `_party_persistent_id` `_load_identities()` filled for the tick in progress.
## Zero on every tick that needed no identity, which is every ordinary tick and every finishing
## tick whose floored shares left nothing over.
var _party_identity_count: int = 0
## The milli-WU that flooring left over, computed by `_allocate_shares()` before any progress is
## consumed and handed out by `_distribute_leftover()` after it. Always 0..`_party_count - 1`.
var _pending_leftover: int = 0
var _factor_out: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_jobs: JobsScript = null) -> void:
	"""Bind the Job store this module works against, assert its capacities, and allocate once.

	Passing an existing store shares it; passing nothing builds a private, consistent set in
	which the residents, needs and directory stores are the ones that store already owns.
	"""
	_jobs = p_jobs if p_jobs != null else JobsScript.new()
	_residents = _jobs.residents()
	_needs = _jobs.needs()
	_directory = _jobs.directory()
	assert(RESIDENT_CAPACITY == JobsScript.AGENT_CAPACITY,
		"the work carries are one row per JobAgent row")
	assert(SKILL_COUNT == JobsScript.JOB_KIND_COUNT,
		"GDD §4.3 makes JobKind and the skill index one enum")
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	_potential_remainder.resize(RESIDENT_CAPACITY)
	_memory_total.resize(RESIDENT_CAPACITY)
	_xp_remainder.resize(RESIDENT_CAPACITY * SKILL_COUNT)
	for column: PackedInt32Array in [_party_job, _party_resident, _party_skill,
			_party_persistent_id, _party_potential]:
		column.resize(PARTY_CAPACITY)
	for column: PackedInt64Array in [_party_share, _party_fraction]:
		column.resize(PARTY_CAPACITY)


func clear() -> void:
	"""Return every carry and input to its default without reallocating a column."""
	_potential_remainder.fill(0)
	_xp_remainder.fill(0)
	_memory_total.fill(0)
	_party_job.fill(0)
	_party_resident.fill(0)
	_party_skill.fill(0)
	_party_persistent_id.fill(0)
	_party_potential.fill(0)
	_party_share.fill(0)
	_party_fraction.fill(0)
	_party_count = 0
	_party_identity_count = 0
	_pending_leftover = 0
	_factor_out = 0


# --- results ------------------------------------------------------------------------------------

func _refuse_tick(code: StringName) -> TickResult:
	"""Build a refused TickResult. It carries no work, no contributors and no completion."""
	return TickResult.new(false, code)


func _succeed(value: int) -> OpResult:
	"""Build a successful OpResult carrying a value."""
	return OpResult.new(true, REFUSE_NONE, value)


func _refuse(code: StringName) -> OpResult:
	"""Build a refusal. It always carries 0, never a stale number."""
	return OpResult.new(false, code, 0)


func _read(code: StringName, value: int) -> IntMath.IntResult:
	"""Build a reader's IntResult: the value on success, an explicit refusal otherwise."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if code != REFUSE_NONE:
		out.refuse(String(code))
	else:
		out.succeed(value)
	return out


# --- collaborators --------------------------------------------------------------------------------

func jobs() -> JobsScript:
	"""The Job store whose rows this module advances."""
	return _jobs


func residents() -> ResidentsScript:
	"""The residents store that owns the skill XP columns and the §5.3 level curve."""
	return _residents


func needs() -> NeedsScript:
	"""The needs store that owns mood, health and the §5.2 work factor."""
	return _needs


# --- address checks --------------------------------------------------------------------------------

func _check_resident_slot(resident_slot: int) -> StringName:
	"""REFUSE_NONE when `resident_slot` addresses a row of the per-resident carries."""
	if resident_slot < 0 or resident_slot >= RESIDENT_CAPACITY:
		return REFUSE_INVALID_RESIDENT_SLOT
	return REFUSE_NONE


func _check_skill(skill: int) -> StringName:
	"""REFUSE_NONE for one of the eleven active skill indices; the reserved index refuses."""
	if skill < 0 or skill >= SKILL_COUNT:
		return REFUSE_INVALID_SKILL
	if skill == SKILL_RESERVED_INDEX:
		return REFUSE_RESERVED_SKILL
	return REFUSE_NONE


# --- inputs and readers ----------------------------------------------------------------------------

func set_memory_total(resident_slot: int, total: int) -> OpResult:
	"""Supply REQ-SET-020's `sum(memory_values)` for one resident, mood's memory term.

	An explicit input with an honest default of 0: no MoodMemory store exists (blocker U6), and
	a fabricated total would silently move every work factor derived from it.
	"""
	var code: StringName = _check_resident_slot(resident_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if not IntMath.fits_int32(total):
		return _refuse(REFUSE_INVALID_MEMORY_TOTAL)
	_memory_total[resident_slot] = total
	return _succeed(total)


func memory_total_of(resident_slot: int) -> IntMath.IntResult:
	"""The currently supplied memory total for one resident."""
	var code: StringName = _check_resident_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _memory_total[resident_slot])


func potential_remainder_of(resident_slot: int) -> IntMath.IntResult:
	"""§5.2's retained work remainder for one resident, in milli-WU/1000."""
	var code: StringName = _check_resident_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _potential_remainder[resident_slot])


func xp_remainder_of(resident_slot: int, skill: int) -> IntMath.IntResult:
	"""Fractional XP progress toward the next whole WU, in milli-WU, for one resident and skill."""
	var code: StringName = _check_resident_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	code = _check_skill(skill)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _xp_remainder[resident_slot * SKILL_COUNT + skill])


func work_factor_of(resident_slot: int, skill: int) -> IntMath.IntResult:
	"""§5.2's total work factor for one resident in one skill, from `needs.work_factor()`.

	Published so a caller -- and a test -- can read the factor a tick will use without ticking,
	and without a second copy of the formula existing to read it from.
	"""
	var code: StringName = _check_resident_slot(resident_slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	code = _check_skill(skill)
	if code != REFUSE_NONE:
		return _read(code, 0)
	code = _compute_factor(resident_slot, skill)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _factor_out)


# --- the §5.2 per-tick core -------------------------------------------------------------------------

func _compute_factor(resident_slot: int, skill: int) -> StringName:
	"""Read skill level, mood and health, and leave `needs.work_factor()`'s answer in _factor_out.

	Nothing is derived here. Every band, weight and clamp lives in `needs.gd`; this assembles the
	three arguments from their owning columns and passes them straight through.
	"""
	if not _residents.skill_level_into(resident_slot, skill, _math):
		return REFUSE_SKILLS_UNAVAILABLE
	var level: int = _math.value
	if not _needs.health_into(resident_slot, _math):
		return REFUSE_NEEDS_UNAVAILABLE
	var health: int = _math.value
	if not _needs.mood_into(resident_slot, _memory_total[resident_slot], _math):
		return REFUSE_NEEDS_UNAVAILABLE
	var mood: int = _math.value
	if not _needs.work_factor_into(level, mood, health, _math):
		return REFUSE_FACTOR_UNAVAILABLE
	assert(_math.value >= WORK_FACTOR_MIN and _math.value <= WORK_FACTOR_MAX,
		"§5.2 clamps the work factor to 300..1800")
	_factor_out = _math.value
	return REFUSE_NONE


func _produce_potential(resident_slot: int, factor: int) -> int:
	"""One tick of §5.2's `80 milli-WU x factor/1000 with retained remainder`.

	Returns the whole milli-WU released this tick and updates the resident's retained carry.
	Every term is nonnegative, so truncation and floor agree; the accumulator peaks at
	999 + 80*1800 and cannot approach int32. THE CARRY IS CONSUMED HERE whether or not the work
	is later accepted -- the worker spent the tick either way, and acceptance is the activity's
	limit, not the worker's rate.
	"""
	var accumulator: int = _potential_remainder[resident_slot] + BASE_MWU_PER_TICK * factor
	var produced: int = accumulator / WORK_FACTOR_DENOMINATOR
	_potential_remainder[resident_slot] = accumulator - produced * WORK_FACTOR_DENOMINATOR
	assert(produced <= MAX_POTENTIAL_MWU, "a tick cannot release more than the clamped ceiling")
	return produced


# --- productive ticks ---------------------------------------------------------------------------

func tick_solo(job_slot: int) -> TickResult:
	"""Advance one single-worker Job by one productive tick and credit its worker's XP.

	Refuses a coordinator and refuses a member Job: a member holds no shared progress, so a
	party -- even a party of one -- must be ticked through `tick_party()` on its coordinator.
	"""
	if _jobs.is_coordinator(job_slot):
		return _refuse_tick(REFUSE_JOB_IS_COORDINATOR)
	if _jobs.is_member(job_slot):
		return _refuse_tick(REFUSE_JOB_IS_MEMBER)
	var code: StringName = _check_progress_row(job_slot)
	if code != REFUSE_NONE:
		return _refuse_tick(code)
	_begin_contributors()
	code = _offer_contributor(job_slot)
	if code != REFUSE_NONE:
		return _refuse_tick(code)
	if _party_count == 0:
		return _refuse_tick(REFUSE_NO_CONTRIBUTORS)
	return _commit(job_slot)


func tick_party(coordinator_slot: int) -> TickResult:
	"""Advance one shared activity by one productive tick, per decision 0017.

	Acceptance is `min(remaining_mwu, sum(potential_i))` against the COORDINATOR's row, allocated
	proportionally on the finishing tick, and completion is written on the coordinator alone.
	Members that have lost their worker, or that are not in JOB_STATE_WORK, contribute nothing
	and are skipped rather than failing the party's tick -- a departure must not stop the crew.
	"""
	if not _jobs.is_coordinator(coordinator_slot):
		return _refuse_tick(REFUSE_NOT_A_COORDINATOR)
	var code: StringName = _check_progress_row(coordinator_slot)
	if code != REFUSE_NONE:
		return _refuse_tick(code)
	code = _collect_contributors(coordinator_slot)
	if code != REFUSE_NONE:
		return _refuse_tick(code)
	if _party_count == 0:
		return _refuse_tick(REFUSE_NO_CONTRIBUTORS)
	return _commit(coordinator_slot)


func _check_progress_row(job_slot: int) -> StringName:
	"""REFUSE_NONE when this row may take work: live, in JOB_STATE_WORK, with work outstanding."""
	if not _jobs.state_into(job_slot, _math):
		return StringName(_math.error)
	if _math.value != JOB_STATE_WORK:
		return REFUSE_JOB_NOT_WORKING
	if not _jobs.remaining_mwu_into(job_slot, _math):
		return StringName(_math.error)
	if _math.value <= 0:
		return REFUSE_NO_WORK_REMAINING
	return REFUSE_NONE


func _collect_contributors(coordinator_slot: int) -> StringName:
	"""Walk the coordinator's members and fill the party scratch with those producing this tick.

	Allocation-free: `jobs.gd`'s `first_member_into()`/`next_member_into()` write into the one
	reused IntResult, and the walk terminates on their explicit end-of-list refusal rather than
	on a slot value that could be mistaken for a row.
	"""
	_begin_contributors()
	if not _jobs.first_member_into(coordinator_slot, _math):
		return REFUSE_NONE
	var member: int = _math.value
	var walking: bool = true
	while walking:
		var code: StringName = _offer_contributor(member)
		if code != REFUSE_NONE and code != REFUSE_JOB_NOT_WORKING \
				and code != REFUSE_JOB_HAS_NO_WORKER:
			return code
		walking = _jobs.next_member_into(member, _math)
		if walking:
			member = _math.value
	return REFUSE_NONE


func _begin_contributors() -> void:
	"""Start a fresh contributor set for one tick: no members, no identities, nothing left over.

	`_party_identity_count` must be cleared here and not only in `clear()`: it is the record that
	the persistent IDs in the scratch belong to THIS tick's frozen membership, and a stale count
	would let `_distribute_leftover()` rank a party against another tick's identities.
	"""
	_party_count = 0
	_party_identity_count = 0
	_pending_leftover = 0


func _offer_contributor(job_slot: int) -> StringName:
	"""Compute one Job's potential for this tick and append it to the party scratch.

	Refuses REFUSE_JOB_NOT_WORKING or REFUSE_JOB_HAS_NO_WORKER for a row that simply is not
	producing; `_collect_contributors()` treats those two as "skip", and every other code as a
	genuine failure that must stop the tick instead of quietly shrinking the crew.
	"""
	if not _jobs.state_into(job_slot, _math) or _math.value != JOB_STATE_WORK:
		return REFUSE_JOB_NOT_WORKING
	var worker: Vector2i = _jobs.worker_of(job_slot)
	if worker == NULL_REF:
		return REFUSE_JOB_HAS_NO_WORKER
	var resident_slot: int = _directory.get_typed_row(worker)
	if resident_slot == EntityDirectory.NULL_SLOT:
		return REFUSE_JOB_HAS_NO_WORKER
	if not _jobs.resident_may_work_into(resident_slot, _math):
		return REFUSE_JOB_NOT_WORKING
	if not _jobs.kind_into(job_slot, _math):
		return StringName(_math.error)
	return _append_contributor(job_slot, resident_slot, _math.value)


func _append_contributor(job_slot: int, resident_slot: int, skill: int) -> StringName:
	"""Compute this worker's potential milli-WU and write one row of the party scratch.

	NO IDENTITY IS READ HERE (decision 0024). The persistent ID decides nothing but a tie between
	equal fractional remainders, which can only arise on a finishing tick that has milli-WU left
	over after flooring, so `_allocate_shares()` fetches it there and an ordinary tick pays
	nothing for it. `_party_persistent_id` therefore holds a value from an earlier tick until
	`_load_identities()` refills it, and `_party_identity_count` records that it has.
	"""
	var code: StringName = _check_skill(skill)
	if code != REFUSE_NONE:
		return code
	if _party_count >= PARTY_CAPACITY:
		return REFUSE_PARTY_TOO_LARGE
	code = _compute_factor(resident_slot, skill)
	if code != REFUSE_NONE:
		return code
	_party_job[_party_count] = job_slot
	_party_resident[_party_count] = resident_slot
	_party_skill[_party_count] = skill
	_party_potential[_party_count] = _produce_potential(resident_slot, _factor_out)
	_party_count += 1
	return REFUSE_NONE


# --- decision 0017 acceptance and allocation -----------------------------------------------------

func _commit(progress_slot: int) -> TickResult:
	"""Apply `accepted_total = min(remaining_mwu, sum(potential_i))` and settle the party.

	The whole of 0017's per-tick rule lives in these few lines: acceptance is capped by the
	activity's own outstanding work, subtracted from the ONE row that holds it, allocated to the
	workers, and turned into XP from the accepted amounts alone.
	"""
	if not _jobs.remaining_mwu_into(progress_slot, _math):
		return _refuse_tick(StringName(_math.error))
	var remaining: int = _math.value
	var potential_total: int = 0
	for index: int in _party_count:
		potential_total += _party_potential[index]
	var accepted: int = potential_total if potential_total < remaining else remaining
	var code: StringName = _allocate_shares(accepted, potential_total)
	if code != REFUSE_NONE:
		return _refuse_tick(code)
	if not _jobs.consume_remaining_mwu_into(progress_slot, accepted, _math):
		return _refuse_tick(StringName(_math.error))
	var left: int = _math.value
	_distribute_leftover(_pending_leftover)
	code = _award_all_xp()
	if code != REFUSE_NONE:
		return _refuse_tick(code)
	return _finish(progress_slot, accepted, left)


func _allocate_shares(accepted: int, potential_total: int) -> StringName:
	"""Split `accepted` across the party in proportion to each worker's potential.

	On every tick but the last, `accepted == potential_total` and each worker keeps exactly their
	own potential, with no division performed. On the finishing tick each share is floored and
	the leftover milli-WU are recorded in `_pending_leftover`, to be distributed by largest
	fractional remainder, ties by ascending resident persistent ID (decision 0017).

	THIS RUNS BEFORE ANY PROGRESS IS CONSUMED, which is why the identity fetch it may need lives
	here rather than in `_distribute_leftover()`. `_commit()` spends the coordinator's remaining
	work between this call and that one, so a read that can refuse must refuse while the row is
	still untouched -- decision 0024's named hazard. Nothing here mutates a collaborating store.

	`accepted <= potential_total <= PARTY_CAPACITY * MAX_POTENTIAL_MWU` (512*144), so the
	proportional numerator cannot exceed about 1.1e7 and no checked multiplication is needed.
	"""
	_pending_leftover = 0
	if accepted == potential_total:
		for index: int in _party_count:
			_party_share[index] = _party_potential[index]
		return REFUSE_NONE
	var distributed: int = 0
	for index: int in _party_count:
		var numerator: int = accepted * _party_potential[index]
		var share: int = numerator / potential_total
		_party_share[index] = share
		_party_fraction[index] = numerator - share * potential_total
		distributed += share
	_pending_leftover = accepted - distributed
	if _pending_leftover == 0:
		return REFUSE_NONE
	return _load_identities()


func _load_identities() -> StringName:
	"""Fetch each frozen contributor's persistent ID exactly once, into the party scratch.

	Reached only when flooring left milli-WU to hand out -- the sole condition under which
	decision 0017's tie-break reads an identity at all. The contributor set is already frozen by
	`_collect_contributors()`/`_offer_contributor()` and is not re-walked here, so the identities
	loaded belong to exactly the workers whose shares were just computed and whose XP is about to
	be credited.

	A refusal returns REFUSE_SKILLS_UNAVAILABLE -- the code `_append_contributor()` used for this
	same read before decision 0024 moved it -- and reaches `_commit()` before
	`consume_remaining_mwu_into()`, so the activity's outstanding work and every XP column are
	still exactly as the tick found them.
	"""
	for index: int in _party_count:
		if not _jobs.agent_persistent_id_into(_party_resident[index], _math):
			return REFUSE_SKILLS_UNAVAILABLE
		_party_persistent_id[index] = _math.value
	_party_identity_count = _party_count
	return REFUSE_NONE


func _distribute_leftover(leftover: int) -> void:
	"""Hand out the milli-WU that flooring left over, largest fraction first, ties by lowest ID.

	`leftover` is strictly below the party size, so this runs at most `_party_count - 1` times
	and only ever on a finishing tick. A share that has received its extra milli-WU has its
	fraction set to -1, which no real fraction can equal, so it cannot be chosen twice.

	`_beats()` reads `_party_persistent_id`, which only `_load_identities()` fills, so a nonzero
	`leftover` here without that call would compare identities from an earlier tick.
	"""
	assert(leftover == 0 or _party_identity_count == _party_count,
		"the tie-break may only read persistent IDs this tick loaded")
	for _pass_index: int in leftover:
		var best: int = -1
		for index: int in _party_count:
			if _party_fraction[index] < 0:
				continue
			if best < 0 or _beats(index, best):
				best = index
		if best < 0:
			return
		_party_share[best] += 1
		_party_fraction[best] = -1


func _beats(candidate: int, incumbent: int) -> bool:
	"""True when `candidate` outranks `incumbent`: larger fraction, then lower persistent ID."""
	if _party_fraction[candidate] != _party_fraction[incumbent]:
		return _party_fraction[candidate] > _party_fraction[incumbent]
	return _party_persistent_id[candidate] < _party_persistent_id[incumbent]


func _award_all_xp() -> StringName:
	"""Credit every contributor's accepted milli-WU toward §5.3 XP in their own job skill."""
	for index: int in _party_count:
		var code: StringName = _credit_xp(_party_resident[index], _party_skill[index],
			_party_share[index])
		if code != REFUSE_NONE:
			return code
	return REFUSE_NONE


func _credit_xp(resident_slot: int, skill: int, accepted: int) -> StringName:
	"""Accumulate accepted milli-WU and award 10 XP per WHOLE WU the threshold actually crosses.

	The fractional part is retained per resident and per skill, so no partial contribution ever
	leaks XP early and none is ever lost. Nothing is written when no whole WU completed, which
	is what keeps the common tick free of a `residents.gd` call.
	"""
	var index: int = resident_slot * SKILL_COUNT + skill
	var accumulator: int = _xp_remainder[index] + accepted
	var whole: int = accumulator / MILLI_WU_PER_WU
	_xp_remainder[index] = accumulator - whole * MILLI_WU_PER_WU
	if whole == 0:
		return REFUSE_NONE
	if not _residents.skill_xp_into(resident_slot, skill, _math):
		return REFUSE_SKILLS_UNAVAILABLE
	var current: int = _math.value
	if not IntMath.checked_add_into(current, whole * XP_PER_WU, _math):
		return REFUSE_OVERFLOW
	if not _residents.set_skill_xp(resident_slot, skill, _math.value).ok:
		return REFUSE_XP_WRITE_FAILED
	return REFUSE_NONE


func _finish(progress_slot: int, accepted: int, left: int) -> TickResult:
	"""Build the tick's result and, when the work total reaches zero, record ONE completion.

	The completion is written on `progress_slot` -- the coordinator for a party, the job itself
	for a solo job -- and on no member row. THIS AMENDS ARCH-JOB-005, which gives completion to
	every member Job; decision 0017 gives it to the coordinator alone.
	"""
	var out: TickResult = TickResult.new(true, REFUSE_NONE)
	out.accepted_mwu = accepted
	out.remaining_mwu = left
	out.contributor_count = _party_count
	if left == 0:
		if not _jobs.set_state(progress_slot, JOB_STATE_COMPLETE).ok:
			return _refuse_tick(REFUSE_JOB_NOT_WORKING)
		out.completed = true
	return out
