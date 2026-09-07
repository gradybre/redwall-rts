extends RefCounted
## The Priorities component: one player-set priority per job kind per resident, plus the two
## per-resident work-policy flags.
##
## GDD §4.2 fixes the row shape this module owns and nothing else:
##   Priorities: job_priority: byte[12], auto_fallback: bool, dangerous_work: bool
##               "Priority 0-4; default dangerous=false"
## `systems_architecture.md` §2.2 fixes the packed layout: `job_priority[owner*12+kind]` as a B8
## column of 6144 bytes (512 owners x 12 kinds), and `auto_fallback`/`dangerous_work` as two B8
## flag columns of 512. Rows are indexed by the RESIDENT typed row `entity_directory.gd`
## allocates; this module never allocates slots.
##
## ---------------------------------------------------------------------------------------
## THE 12-WIDE STRIDE IS PHYSICAL, NOT LOGICAL. `residents.gd` already stripes Skills as
## `_skill_xp[slot * 12 + skill]` and refuses writes to index 3. This column uses the identical
## formula and the identical refusal, because JobKind is one enum: skill index and job-priority
## index are the same number for the same kind (§4.3, "JobKind/skill index").
## `setting_rules_amendment.md` renamed `HUNT=3` to `RESERVED_3=3` with "priority initialised to
## 0 and assignment prohibited, keeping the 12-column physical stride", and REQ-ADM-007 adds
## "when job controls or mastery checks enumerate skills, the system shall omit RESERVED_3 and
## preserve the remaining numeric indices". So the byte exists, is 0, and cannot be written.
##
## ---------------------------------------------------------------------------------------
## VALUES COME FROM catalog.gd. JobKind is one of GDD §4.3's explicitly numbered enums, so per
## decision 0018 its numbers live in `catalog.gd`'s protected table and are read here as
## constant expressions. There is no second copy of HAUL=0 or RESERVED_3=3 in this file.
##
## ---------------------------------------------------------------------------------------
## REQ-SET-026, "apply the change at the next job-selection boundary". A write lands in the
## column immediately; the deferral is a property of the READER, not of this store. §5.3 states
## job selection reevaluates idle residents every 30 ticks staggered by resident ID, and a
## worker already holding a job keeps it, so a priority written mid-job is first consulted at
## that resident's next selection pass -- which is exactly the requirement. No pending-write
## buffer is introduced here: that would need a boundary signal this module does not own and
## task 2.11 item 4 has not yet defined.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. Every column is a packed array sized once in _init(); clear() refills the
## existing buffers. No mutator or reader allocates anything except the small result object it
## returns, and `fallback_priority_allows()` allocates nothing beyond its IntResult.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md "do not invent a constant"):
##   * Job SELECTION is task 2.11 item 4 and is not here: no eligibility order, no urgency
##     bucket, no `(player_priority, job_priority, -skill_level, ...)` sort key. This module is
##     the data those rules read.
##   * REQ-SET-028's fallback set is "HAUL, KEEP, and low-risk FORAGE".
##     `fallback_priority_allows()` answers the priority-and-flag half of that condition only:
##     "low-risk" is a HarvestZone danger test and no HarvestZone store exists in this
##     milestone, so a caller granting fallback FORAGE must still apply the zone-risk test
##     itself. The function is named for what it actually decides rather than pretending to
##     settle the whole requirement.
##   * `dangerous_work` is stored and defaulted false per §4.2/§5.1; the consent CHECK
##     ("dangerous consent" in §5.3's eligibility order) belongs to item 4.
##   * §5.1's initial cohort values are written by spawn(); which residents receive
##     them, and in what order, is `residents.gd`'s business. This module is per-slot only.

const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")

## Rows, one per RESIDENT typed row. _init() asserts this equals the needs store's own capacity
## rather than restating an independent number.
const PRIORITY_CAPACITY: int = 512

# --- GDD §4.3 JobKind, read from catalog.gd's protected table (decision 0018) ------------------

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
## `setting_rules_amendment.md`: HUNT=3 became RESERVED_3=3, priority 0, assignment prohibited.
## REQ-ADM-007: job controls omit it and preserve every other numeric index, so there is no
## JOB_KIND_ constant naming it as a workable kind -- only this reserved-index guard.
const JOB_KIND_RESERVED_INDEX: int = Catalog.JOB_KIND["RESERVED_3"]

# --- REQ-SET-026 priority scale ----------------------------------------------------------------

## "accept 0=forbidden, 1=highest, 2=high, 3=normal, 4=low".
const PRIORITY_FORBIDDEN: int = 0
const PRIORITY_HIGHEST: int = 1
const PRIORITY_HIGH: int = 2
const PRIORITY_NORMAL: int = 3
const PRIORITY_LOW: int = 4
const PRIORITY_MIN: int = 0
const PRIORITY_MAX: int = 4

# --- GDD §5.1 initial values -------------------------------------------------------------------

## "Initial priorities are HAUL=2, RESERVED_3=0 and all other active jobs=3, auto_fallback=true,
## dangerous_work=false".
const INITIAL_HAUL_PRIORITY: int = PRIORITY_HIGH
const INITIAL_ACTIVE_PRIORITY: int = PRIORITY_NORMAL
const INITIAL_RESERVED_PRIORITY: int = PRIORITY_FORBIDDEN
const INITIAL_AUTO_FALLBACK: bool = true
const INITIAL_DANGEROUS_WORK: bool = false

# --- REQ-SET-028 automatic fallback -------------------------------------------------------------

## "the system shall allow HAUL, KEEP, and low-risk FORAGE at priority 4 only when their
## configured priority is nonzero". A set, not a ranking: ordering belongs to job selection.
const FALLBACK_JOB_KINDS: Array[int] = [JOB_KIND_HAUL, JOB_KIND_KEEP, JOB_KIND_FORAGE]
const FALLBACK_PRIORITY: int = PRIORITY_LOW

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
const REFUSE_NOT_PRESENT: StringName = &"PRIORITIES_NOT_PRESENT"
const REFUSE_ALREADY_PRESENT: StringName = &"PRIORITIES_ALREADY_PRESENT"
const REFUSE_INVALID_JOB_KIND: StringName = &"INVALID_JOB_KIND"
const REFUSE_INVALID_PRIORITY: StringName = &"INVALID_PRIORITY"
const REFUSE_RESERVED_JOB_KIND: StringName = &"RESERVED_JOB_KIND"


class OpResult:
	"""Outcome of one priorities operation: success flag, refusal code, produced value.

	`.ok` MUST be inspected before `.value` is used. A refusal carries 0 and never a partially
	applied effect: every mutator validates completely before it writes a byte.
	"""
	var ok: bool
	var error: StringName
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value


# --- authoritative columns (ARCH-MEM-001: packed, allocated once) -------------------------------

## Priorities.job_priority, owner-major: `_job_priority[slot*12 + kind]` (§2.2), the same
## formula residents.gd uses for `_skill_xp[slot*12 + skill]`.
var _job_priority: PackedByteArray = PackedByteArray()
var _auto_fallback: PackedByteArray = PackedByteArray()
var _dangerous_work: PackedByteArray = PackedByteArray()
var _present: PackedByteArray = PackedByteArray()

var _present_count: int = 0


func _init() -> void:
	"""Assert the shared capacity and JobKind stride, then allocate every column once."""
	assert(PRIORITY_CAPACITY == NeedsScript.RESIDENT_CAPACITY,
		"priority columns must match the needs store's resident capacity")
	assert(Catalog.JOB_KIND.size() == JOB_KIND_COUNT,
		"GDD §4.3 JobKind has exactly twelve values, including the reserved gap")
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	_job_priority.resize(PRIORITY_CAPACITY * JOB_KIND_COUNT)
	_auto_fallback.resize(PRIORITY_CAPACITY)
	_dangerous_work.resize(PRIORITY_CAPACITY)
	_present.resize(PRIORITY_CAPACITY)


func clear() -> void:
	"""Return every row to the empty state, refilling the existing buffers without reallocating."""
	_job_priority.fill(PRIORITY_FORBIDDEN)
	_auto_fallback.fill(0)
	_dangerous_work.fill(0)
	_present.fill(0)
	_present_count = 0


# --- results -------------------------------------------------------------------------------------

func _result(code: StringName, value: int) -> OpResult:
	"""Build one OpResult. A refusal always carries 0, so an ignored refusal reveals no number."""
	if code != REFUSE_NONE:
		return OpResult.new(false, code, 0)
	return OpResult.new(true, REFUSE_NONE, value)


func _read(code: StringName, value: int) -> IntMath.IntResult:
	"""Build a reader's IntResult: the value on success, an explicit refusal otherwise."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if code != REFUSE_NONE:
		out.refuse(String(code))
	else:
		out.succeed(value)
	return out


# --- address checks --------------------------------------------------------------------------

func _check_present_slot(slot: int) -> StringName:
	"""REFUSE_NONE when `slot` is in range and holds a spawned priorities row."""
	if slot < 0 or slot >= PRIORITY_CAPACITY:
		return REFUSE_INVALID_SLOT
	if _present[slot] == 0:
		return REFUSE_NOT_PRESENT
	return REFUSE_NONE


func _check_kind_address(slot: int, kind: int) -> StringName:
	"""REFUSE_NONE when (slot, kind) names a real JobKind column of a spawned row."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if kind < 0 or kind >= JOB_KIND_COUNT:
		return REFUSE_INVALID_JOB_KIND
	return REFUSE_NONE


# --- lifecycle -----------------------------------------------------------------------------------

func spawn(slot: int) -> OpResult:
	"""Initialize one priorities row to the GDD §5.1 start state. Refuses an occupied row.

	"Initial priorities are HAUL=2, RESERVED_3=0 and all other active jobs=3,
	auto_fallback=true, dangerous_work=false."
	"""
	if slot < 0 or slot >= PRIORITY_CAPACITY:
		return _result(REFUSE_INVALID_SLOT, 0)
	if _present[slot] != 0:
		return _result(REFUSE_ALREADY_PRESENT, 0)
	_present[slot] = 1
	_present_count += 1
	_write_initial_row(slot)
	return _result(REFUSE_NONE, slot)


func _write_initial_row(slot: int) -> void:
	"""Write the §5.1 initial priorities and flags into one already-claimed row."""
	var base: int = slot * JOB_KIND_COUNT
	for kind: int in JOB_KIND_COUNT:
		if kind == JOB_KIND_RESERVED_INDEX:
			_job_priority[base + kind] = INITIAL_RESERVED_PRIORITY
		elif kind == JOB_KIND_HAUL:
			_job_priority[base + kind] = INITIAL_HAUL_PRIORITY
		else:
			_job_priority[base + kind] = INITIAL_ACTIVE_PRIORITY
	_auto_fallback[slot] = 1 if INITIAL_AUTO_FALLBACK else 0
	_dangerous_work[slot] = 1 if INITIAL_DANGEROUS_WORK else 0


func despawn(slot: int) -> OpResult:
	"""Release one priorities row back to the empty state. Refuses a row that is not present."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code, 0)
	_present[slot] = 0
	_present_count -= 1
	var base: int = slot * JOB_KIND_COUNT
	for kind: int in JOB_KIND_COUNT:
		_job_priority[base + kind] = PRIORITY_FORBIDDEN
	_auto_fallback[slot] = 0
	_dangerous_work[slot] = 0
	return _result(REFUSE_NONE, slot)


# --- readers ---------------------------------------------------------------------------------

func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a spawned priorities row."""
	return slot >= 0 and slot < PRIORITY_CAPACITY and _present[slot] == 1


func present_count() -> int:
	"""Number of spawned priorities rows."""
	return _present_count


func inactive_row_is_clear(slot: int) -> bool:
	"""True when an absent row holds no residue of the resident who last occupied it.

	Two logically identical worlds must serialize to identical columns, so despawn() returns a
	row to exactly the state clear() produces rather than leaving the departed resident's job
	priorities in an inactive row where they would change the canonical hash. A save or
	validation pass checks this; readers of an active row never need it. False for a present row.
	"""
	if slot < 0 or slot >= PRIORITY_CAPACITY or _present[slot] != 0:
		return false
	if _auto_fallback[slot] != 0 or _dangerous_work[slot] != 0:
		return false
	var base: int = slot * JOB_KIND_COUNT
	for kind: int in JOB_KIND_COUNT:
		if _job_priority[base + kind] != PRIORITY_FORBIDDEN:
			return false
	return true


func priority_of(slot: int, kind: int) -> IntMath.IntResult:
	"""One job kind's configured priority, 0-4. Index 3 always reads 0 (RESERVED_3)."""
	var code: StringName = _check_kind_address(slot, kind)
	return _read(code, _job_priority[slot * JOB_KIND_COUNT + kind] if code == REFUSE_NONE else 0)


func auto_fallback_of(slot: int) -> IntMath.IntResult:
	"""Priorities.auto_fallback as 1 or 0 (REQ-SET-028/029). Default 1 per §5.1."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _auto_fallback[slot] if code == REFUSE_NONE else 0)


func dangerous_work_of(slot: int) -> IntMath.IntResult:
	"""Priorities.dangerous_work as 1 or 0. Default 0 per §4.2 and §5.1."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _dangerous_work[slot] if code == REFUSE_NONE else 0)


static func is_fallback_kind(kind: int) -> bool:
	"""True for REQ-SET-028's HAUL/KEEP/FORAGE fallback set; see the header on "low-risk"."""
	return FALLBACK_JOB_KINDS.has(kind)


func fallback_priority_allows(slot: int, kind: int) -> IntMath.IntResult:
	"""REQ-SET-028's priority-and-flag test only: 1 when automatic fallback could offer `kind`.

	1 requires auto_fallback enabled, `kind` in the HAUL/KEEP/FORAGE set, and its configured
	priority nonzero. REQ-SET-029 makes every kind 0 while fallback is disabled. This does NOT
	decide FORAGE's "low-risk" zone condition (no HarvestZone store exists yet) and does not
	decide whether any permitted job was available -- both belong to job selection, item 4.
	"""
	var code: StringName = _check_kind_address(slot, kind)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if _auto_fallback[slot] == 0:
		return _read(REFUSE_NONE, 0)
	if not is_fallback_kind(kind):
		return _read(REFUSE_NONE, 0)
	var configured: int = _job_priority[slot * JOB_KIND_COUNT + kind]
	return _read(REFUSE_NONE, 1 if configured != PRIORITY_FORBIDDEN else 0)


# --- mutators --------------------------------------------------------------------------------

func set_priority(slot: int, kind: int, priority: int) -> OpResult:
	"""REQ-SET-026: write one job kind's priority, accepting 0-4 only.

	Refuses the reserved index 3, which the amendment fixes at 0 with assignment prohibited,
	exactly as residents.gd refuses reserved-index XP. Refuses any value outside 0-4 rather
	than clamping: a clamped 7 would silently become "low" instead of reporting the bug.
	"""
	var code: StringName = _check_kind_address(slot, kind)
	if code != REFUSE_NONE:
		return _result(code, 0)
	if kind == JOB_KIND_RESERVED_INDEX:
		return _result(REFUSE_RESERVED_JOB_KIND, 0)
	if priority < PRIORITY_MIN or priority > PRIORITY_MAX:
		return _result(REFUSE_INVALID_PRIORITY, 0)
	_job_priority[slot * JOB_KIND_COUNT + kind] = priority
	return _result(REFUSE_NONE, priority)


func set_auto_fallback(slot: int, enabled: bool) -> OpResult:
	"""REQ-SET-028/029: enable or disable automatic fallback for one resident."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code, 0)
	_auto_fallback[slot] = 1 if enabled else 0
	return _result(REFUSE_NONE, _auto_fallback[slot])


func set_dangerous_work(slot: int, allowed: bool) -> OpResult:
	"""Record one resident's dangerous-work consent. The eligibility check itself is item 4."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code, 0)
	_dangerous_work[slot] = 1 if allowed else 0
	return _result(REFUSE_NONE, _dangerous_work[slot])
