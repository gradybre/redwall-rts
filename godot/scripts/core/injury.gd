extends RefCounted
## The aggregate Injury component: GDD §4.2's `Injury` row and its care/rescue lifecycle.
##
## GDD §4.2 fixes the row shape this module owns, and nothing else:
##   Injury: kind: enum, severity: int32, untreated_hours: int32, care_progress_mwu: int64,
##           rescuer: EntityRef
##   "At most 1 aggregate injury/resident; worse severity replaces, damage still accumulates"
## One row exists per RESIDENT typed row, indexed exactly as `needs.gd` indexes its own, so
## this module allocates no slots: `entity_directory.gd` owns those and `needs.gd` owns the
## resident's needs and health.
##
## INTEGER ONLY. There is no float anywhere in this file.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS IS *NOT*.
##
##   * NOT a second health path. Every health change this module causes -- one-shot incident
##     damage and REQ-SET-173's +10 treatment restore -- goes through
##     `needs.apply_health_event()`, and the per-hour untreated drain is a term of
##     `needs._health_rate_per_hour()`. SET-MOVE-ECON-001 HAZ-002 is explicit: "Never run
##     separate rounded health clocks." This module holds no health value and no health
##     remainder.
##   * NOT a new injury-kind domain. `InjuryKind` is GDD §4.3's, already numbered
##     NONE=0, CUT=1, BITE=2, FALL=3, EXPOSURE=4, EXHAUSTION=5, and HAZ-001 says so in as many
##     words. The constants below are that domain, not a parallel one.
##   * NOT a combat or damage model. There is no attack, no weapon and no per-tick roll here.
##     Incidents arrive from the already-specified settlement sources: §5.4 fishing, §5.5
##     foraging, HAZ-002 airless exposure, HAZ-003 exhaustion and declared falls.
##   * NOT a rescue router. It owns the `rescuer` reference of the Injury row and the
##     one-patient-per-rescuer rule. Route safety, carrying speed, the combined envelope, the
##     landing choice and the HAUL work are the movement and work owners'.
##
## ---------------------------------------------------------------------------------------
## WHERE `InjuryKind` LIVES, AND WHY IT IS DECLARED HERE.
##
## Decision 0018's rule is that a module needing one of §4.3's explicitly numbered enums reads
## it from `catalog.gd` so there is exactly one copy. `catalog.gd` does NOT carry `InjuryKind`:
## its header names `InjuryKind` among the five §4.3 enums it "does not yet carry" and states
## that adding one "is an intentional artifact/digest change, not a fix". That change belongs
## to the catalog owner, and making it here would silently move the compiled-catalog digest.
##
## BLOCKER (reported, not worked around): `InjuryKind` must migrate into `catalog.gd`'s
## PROTECTED_ENUM_DOMAINS, after which `KIND_*` below become `Catalog.INJURY_KIND[...]` reads.
## Until then these six constants transcribe GDD §4.3 line 215 verbatim, in its order, and
## `test_injury.gd` asserts each numeric value so a renumbering fails a test rather than
## quietly re-labelling every saved injury.
##
## `severity` is a plain int32 1..2 from the §4.2 Injury row and from REQ-SET-172. It is NOT
## `Catalog.SEVERITY`, which is the alert domain INFO/ADVISORY/WARNING/CRITICAL.
##
## ---------------------------------------------------------------------------------------
## THE MERGE RULE (GDD §4.2, HAZ-004). One aggregate injury per resident:
##   * no active injury            -> the incoming incident becomes the aggregate;
##   * incoming severity is worse  -> it replaces both kind and severity;
##   * incoming severity is lower  -> the aggregate is unchanged;
##   * equal severity, differing kind -> "retain the lower InjuryKind ID deterministically".
## In every case `untreated_ticks` and `care_progress_mwu` are LEFT ALONE: HAZ-004 states that
## "a new incident does not erase untreated elapsed time, remainders or already paid care work".
## The drain is therefore per aggregate severity and never one copy per incident.
##
## ONE-SHOT EVENTS ARE DEDUPLICATED BY ORDINAL. HAZ-004: "Genuine one-shot health events still
## apply once each; deduplicate by incident identity/event ordinal." Each incident carries a
## strictly increasing per-resident ordinal; a replayed or retried call with an ordinal already
## seen REFUSES as a duplicate instead of charging the damage twice.
##
## ---------------------------------------------------------------------------------------
## DEATH IS STRUCTURALLY IRREVERSIBLE, NOT CHECKED AFTER THE FACT.
##
## `needs.apply_health_event()` validates through `_check_live_slot()` and refuses
## RESIDENT_DEAD before writing anything. `complete_treatment()` makes that call BEFORE it
## clears the aggregate injury, so a resident whose health reached 0 cannot be healed by a
## later treatment: the heal is refused and the clear never runs. The ordering is the
## guarantee; there is no post-hoc "was it alive?" re-check that a future edit could reorder
## past. HAZ-004: "a completed treatment cannot undo it."
##
## ---------------------------------------------------------------------------------------
## ALLOCATE BEFORE CONSUME (decision 0059). Every mutator validates completely -- its own row,
## its arguments, the collaborating needs row -- before any column is written. A refusal
## leaves this store AND `needs.gd` byte-identical, which `test_injury.gd` asserts by
## comparing `state_bytes()` images rather than by inspection.
##
## ARCH-MEM-001/005: every column is packed and allocated once in `_init()`. `resize()` is
## called only by `_allocate_columns()`; `clear()` refills the existing buffers. No per-tick
## call allocates.
##
## ---------------------------------------------------------------------------------------
## DELIBERATELY NOT IMPLEMENTED HERE, with the owner named:
##   * The scheduler binding that calls `tick_all()` each fixed tick. G02/task08 owns the
##     phase order; this module publishes the sweep and does not install itself anywhere.
##   * Treatment INPUT consumption (herb 1000 + cloth 500 milli-U, REQ-SET-173). The costs are
##     published below for the job owner; `inventory.gd` performs the debit, and
##     `complete_treatment()` is called only after it has committed.
##   * The HEAL and rescue HAUL work accrual itself (`work.gd`), the rescue route, the carry
##     speed and the landing choice (`movement.gd`, EH-05 -- blocked).
##   * PC-04 child/elder coefficients. No life-stage term appears here and none is invented.
##   * MoodMemory's `untreated_injury` entry: blocker U6 leaves that store's index formula
##     unspecified, exactly as `needs.gd` records.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Needs := preload("res://scripts/core/needs.gd")

# --- capacity -------------------------------------------------------------------------------

## One row per RESIDENT typed row. `_init()` asserts this against `needs.gd` rather than
## restating the directory's number a third time.
const RESIDENT_CAPACITY: int = 512

# --- InjuryKind (GDD §4.3 line 215; HAZ-001 restates it) ------------------------------------

const KIND_NONE: int = 0
const KIND_CUT: int = 1
const KIND_BITE: int = 2
const KIND_FALL: int = 3
const KIND_EXPOSURE: int = 4
const KIND_EXHAUSTION: int = 5
const KIND_COUNT: int = 6

# --- severity (GDD §4.2 Injury.severity, REQ-SET-172) ---------------------------------------

const SEVERITY_NONE: int = 0
const SEVERITY_MINOR: int = 1
const SEVERITY_SERIOUS: int = 2

# --- clocks ---------------------------------------------------------------------------------

## GDD §5.1 REQ-SET-006. `untreated_hours` is the floor of the tick counter over this, exactly
## as `needs.gd` exposes `starving_hours` from `_starving_ticks`: storing ticks makes the
## counter its own remainder, so no second accumulator is needed and none is invented.
const TICKS_PER_HOUR: int = Needs.TICKS_PER_HOUR
const TICKS_PER_SECOND: int = 30
const UNITS_PER_METRE: int = 1024

# --- treatment (REQ-SET-173, REQ-SET-174, HAZ-004) ------------------------------------------

## "treatment consumes herb 1+cloth 0.5 and completes 60 WU ... restore 10 health, capped 100".
## Quantities are milli-U and work is milli-WU (AGENTS.md), so 60 WU is 60000 milli-WU.
const CARE_WORK_MWU: int = 60000
## REQ-SET-174: "the last resident ... self-treatment at 120 WU".
const SELF_CARE_WORK_MWU: int = 120000
const CARE_HERB_MILLI: int = 1000
const CARE_CLOTH_MILLI: int = 500
const CARE_HEALTH_RESTORE: int = 10

# --- HAZ-002 airless exposure ---------------------------------------------------------------

## "Injury on transition to airless: EXPOSURE, severity 2, immediate health loss 0."
const AIRLESS_INJURY_KIND: int = KIND_EXPOSURE
const AIRLESS_INJURY_SEVERITY: int = SEVERITY_SERIOUS
const AIRLESS_IMMEDIATE_HEALTH_LOSS: int = 0

# --- HAZ-003 exhaustion ---------------------------------------------------------------------

## "At rest 0 while still in water or on a climb, apply one EXHAUSTION severity 1 incident with
## zero immediate health loss ... Re-arm this incident only after rest recovers to 4000 at safe
## support." The movement-side triggers are EH-05's; the incident and its latch are this row's.
const EXHAUSTION_INJURY_KIND: int = KIND_EXHAUSTION
const EXHAUSTION_INJURY_SEVERITY: int = SEVERITY_MINOR
const EXHAUSTION_IMMEDIATE_HEALTH_LOSS: int = 0
const EXHAUSTION_REARM_REST: int = 4000

# --- HAZ-003 declared falls -----------------------------------------------------------------

## "At touchdown apply FALL with health loss min(40, ceil(D*8/1024)); severity 1 for D<=2048,
## severity 2 above." and "Recovery duration max(1, ceil(D*30/4096)) ticks."
const FALL_INJURY_KIND: int = KIND_FALL
const FALL_DAMAGE_PER_METRE: int = 8
const FALL_MAX_DAMAGE: int = 40
const FALL_SEVERITY_ONE_MAX_DROP_U: int = 2048
const FALL_RECOVERY_SPEED_U_PER_SECOND: int = 4096
const FALL_MINIMUM_TICKS: int = 1

# --- HAZ-004 rescue -------------------------------------------------------------------------

## "Pickup requires 8000 milli-WU HAUL, set-down 4000 milli-WU HAUL", published for the work
## owner. "One eligible rescuer can carry one patient per REQ-SET-171."
const RESCUE_PICKUP_WORK_MWU: int = 8000
const RESCUE_SETDOWN_WORK_MWU: int = 4000
const PATIENTS_PER_RESCUER: int = 1

## Fields `state_bytes()` emits per spawned row: slot, kind, severity, untreated ticks, care
## progress, last ordinal, rescuer slot/generation, and the three latch/input bytes.
const IMAGE_FIELDS_PER_ROW: int = 11

const NULL_SLOT: int = EntityDirectory.NULL_SLOT
const NULL_GENERATION: int = EntityDirectory.NULL_GENERATION
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- refusal codes --------------------------------------------------------------------------
#
# Shared meanings reuse `needs.gd`'s exact spellings rather than a near-copy, so a caller
# switching on a code cannot see two strings for one condition.

const REFUSE_NONE: StringName = Needs.REFUSE_NONE
const REFUSE_INVALID_SLOT: StringName = Needs.REFUSE_INVALID_SLOT
const REFUSE_NOT_PRESENT: StringName = Needs.REFUSE_NOT_PRESENT
const REFUSE_ALREADY_PRESENT: StringName = Needs.REFUSE_ALREADY_PRESENT
const REFUSE_RESIDENT_DEAD: StringName = Needs.REFUSE_RESIDENT_DEAD
const REFUSE_OVERFLOW: StringName = Needs.REFUSE_OVERFLOW

const REFUSE_INVALID_KIND: StringName = &"INVALID_INJURY_KIND"
const REFUSE_INVALID_SEVERITY: StringName = &"INVALID_INJURY_SEVERITY"
const REFUSE_INVALID_HEALTH_LOSS: StringName = &"INVALID_HEALTH_LOSS"
const REFUSE_INVALID_ORDINAL: StringName = &"INVALID_INCIDENT_ORDINAL"
const REFUSE_DUPLICATE_INCIDENT: StringName = &"DUPLICATE_INCIDENT"
const REFUSE_NO_INJURY: StringName = &"NO_ACTIVE_INJURY"
const REFUSE_INVALID_WORK: StringName = &"INVALID_CARE_WORK"
const REFUSE_INVALID_CARE_REQUIREMENT: StringName = &"INVALID_CARE_REQUIREMENT"
const REFUSE_CARE_INCOMPLETE: StringName = &"CARE_WORK_INCOMPLETE"
const REFUSE_CARE_BLOCKED: StringName = &"CARE_CONTEXT_BLOCKED"
const REFUSE_AIRLESS_ACTIVE: StringName = &"AIRLESS_EPISODE_ACTIVE"
const REFUSE_AIRLESS_NOT_ACTIVE: StringName = &"AIRLESS_EPISODE_NOT_ACTIVE"
const REFUSE_EXHAUSTION_LATCHED: StringName = &"EXHAUSTION_LATCHED"
const REFUSE_EXHAUSTION_REARM_REST: StringName = &"EXHAUSTION_REARM_REST"
const REFUSE_INVALID_DROP: StringName = &"INVALID_FALL_DROP"
const REFUSE_NO_DIRECTORY: StringName = &"NO_DIRECTORY_BOUND"
const REFUSE_INVALID_RESCUER: StringName = &"INVALID_RESCUER_REF"
const REFUSE_RESCUER_IS_PATIENT: StringName = &"RESCUER_IS_THE_PATIENT"
const REFUSE_RESCUER_BUSY: StringName = &"RESCUER_ALREADY_ASSIGNED"
const REFUSE_NEEDS_REFUSED: StringName = &"NEEDS_REFUSED"

# --- authoritative columns (ARCH-MEM-001: packed, allocated once) ---------------------------

## 1 while this row mirrors a spawned resident row. Never a free-list: `needs.gd` and the
## directory decide which rows exist.
var _present: PackedByteArray = PackedByteArray()
## Injury.kind, an InjuryKind value. KIND_NONE means there is no aggregate injury.
var _kind: PackedByteArray = PackedByteArray()
## HAZ-002: 1 between the transition to airless and the return to breathable support, so one
## continuous episode creates exactly one EXPOSURE incident and not one per tick.
var _airless_episode: PackedByteArray = PackedByteArray()
## HAZ-003: 1 once the exhaustion incident has fired, until rest recovers to 4000.
var _exhaustion_latch: PackedByteArray = PackedByteArray()
## HAZ-004: "No treatment work in active water, on an unsupported climb, during falling or
## while being carried." Those are movement states; the movement owner (EH-05) declares the
## block and 0 is the honest default of a world with no such traversal implemented.
var _care_context_blocked: PackedByteArray = PackedByteArray()

## Injury.severity: SEVERITY_NONE, 1 or 2. Always SEVERITY_NONE exactly when kind is KIND_NONE.
var _severity: PackedInt32Array = PackedInt32Array()
## Injury.rescuer, an EntityRef in the directory's slot/generation space. NULL_REF (-1, 0) means
## no rescuer is assigned, which is a real value and not a refusal.
var _rescuer_slot: PackedInt32Array = PackedInt32Array()
var _rescuer_generation: PackedInt32Array = PackedInt32Array()

## Injury.untreated_hours, stored as its own tick counter (see TICKS_PER_HOUR).
var _untreated_ticks: PackedInt64Array = PackedInt64Array()
## Injury.care_progress_mwu: treatment work in progress, retained across a change of helper.
var _care_progress_mwu: PackedInt64Array = PackedInt64Array()
## Highest incident ordinal already applied to this resident; 0 means none. Strictly increasing,
## so a retried or replayed one-shot event is refused rather than charged twice.
var _last_incident_ordinal: PackedInt64Array = PackedInt64Array()

# --- counters and scratch -------------------------------------------------------------------

var _present_count: int = 0
var _injured_count: int = 0
## Row named by the refusal that stopped the last `tick_all()`, or -1.
var _last_refused_slot: int = -1
## Value carried by the next OpResult, set by a `_*_checked()` helper just before it returns.
var _out_value: int = 0
## Reused by the checked arithmetic on the care-work path. One instance for the whole store.
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Allocate every column once to capacity, then reset to the empty settlement state."""
	assert(RESIDENT_CAPACITY == Needs.RESIDENT_CAPACITY,
		"injury rows must match the needs store's resident row capacity")
	assert(KIND_COUNT == 6 and KIND_EXHAUSTION == 5,
		"InjuryKind is GDD §4.3's six-member domain and must not be extended here")
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_present.resize(RESIDENT_CAPACITY)
	_kind.resize(RESIDENT_CAPACITY)
	_airless_episode.resize(RESIDENT_CAPACITY)
	_exhaustion_latch.resize(RESIDENT_CAPACITY)
	_care_context_blocked.resize(RESIDENT_CAPACITY)
	_severity.resize(RESIDENT_CAPACITY)
	_rescuer_slot.resize(RESIDENT_CAPACITY)
	_rescuer_generation.resize(RESIDENT_CAPACITY)
	_untreated_ticks.resize(RESIDENT_CAPACITY)
	_care_progress_mwu.resize(RESIDENT_CAPACITY)
	_last_incident_ordinal.resize(RESIDENT_CAPACITY)


func clear() -> void:
	"""Return every column to the empty settlement state without reallocating."""
	_present.fill(0)
	_kind.fill(KIND_NONE)
	_airless_episode.fill(0)
	_exhaustion_latch.fill(0)
	_care_context_blocked.fill(0)
	_severity.fill(SEVERITY_NONE)
	_rescuer_slot.fill(NULL_SLOT)
	_rescuer_generation.fill(NULL_GENERATION)
	_untreated_ticks.fill(0)
	_care_progress_mwu.fill(0)
	_last_incident_ordinal.fill(0)
	_present_count = 0
	_injured_count = 0
	_last_refused_slot = -1
	_out_value = 0


# --- result plumbing ------------------------------------------------------------------------

func _result(code: StringName) -> Needs.OpResult:
	"""Turn an internal refusal code plus the pending `_out_value` into one OpResult.

	Shares `needs.gd`'s result shape rather than cloning it, the way `gear.gd` shares
	`inventory.gd`'s. A refusal always carries 0, on a channel separate from the code, so an
	ignored refusal cannot surface a usable number.
	"""
	var value: int = _out_value
	_out_value = 0
	if code != REFUSE_NONE:
		return Needs.OpResult.new(false, code, 0)
	return Needs.OpResult.new(true, REFUSE_NONE, value)


func _read(code: StringName, value: int) -> IntMath.IntResult:
	"""Build a reader's IntResult: the value on success, an explicit refusal otherwise."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if code != REFUSE_NONE:
		out.refuse(String(code))
		return out
	out.succeed(value)
	return out


func _check_present_slot(slot: int) -> StringName:
	"""REFUSE_NONE when `slot` is in range and holds a spawned injury row."""
	if slot < 0 or slot >= RESIDENT_CAPACITY:
		return REFUSE_INVALID_SLOT
	if _present[slot] == 0:
		return REFUSE_NOT_PRESENT
	return REFUSE_NONE


func _check_live_slot(slot: int, needs: Needs) -> StringName:
	"""REFUSE_NONE when this row is spawned AND `needs` holds a living resident there.

	Liveness is asked of `needs.gd` because that is where health lives. Reading it from a
	mirrored flag here would create the second source of truth that lets a dead resident be
	treated, which is exactly the failure HAZ-004 forbids.
	"""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if needs == null:
		return REFUSE_NEEDS_REFUSED
	if not needs.is_alive(slot):
		return REFUSE_RESIDENT_DEAD
	return REFUSE_NONE


# --- lifecycle ------------------------------------------------------------------------------

func spawn(slot: int) -> Needs.OpResult:
	"""Open the injury row of a freshly spawned resident: no injury, no care, no rescuer."""
	return _result(_spawn_checked(slot))


func _spawn_checked(slot: int) -> StringName:
	"""Validate then write a fresh injury row. Refuses before touching anything."""
	if slot < 0 or slot >= RESIDENT_CAPACITY:
		return REFUSE_INVALID_SLOT
	if _present[slot] != 0:
		return REFUSE_ALREADY_PRESENT
	_write_empty_row(slot)
	_present[slot] = 1
	_present_count += 1
	_out_value = slot
	return REFUSE_NONE


func _write_empty_row(slot: int) -> void:
	"""Reset every column of one row to the no-injury state, leaving presence to the caller."""
	_kind[slot] = KIND_NONE
	_severity[slot] = SEVERITY_NONE
	_untreated_ticks[slot] = 0
	_care_progress_mwu[slot] = 0
	_last_incident_ordinal[slot] = 0
	_airless_episode[slot] = 0
	_exhaustion_latch[slot] = 0
	_care_context_blocked[slot] = 0
	_rescuer_slot[slot] = NULL_SLOT
	_rescuer_generation[slot] = NULL_GENERATION


func despawn(slot: int) -> Needs.OpResult:
	"""Release one injury row. The directory owns the slot; this only clears the data."""
	return _result(_despawn_checked(slot))


func _despawn_checked(slot: int) -> StringName:
	"""Validate then clear an injury row, keeping the present and injured counts exact."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if _kind[slot] != KIND_NONE:
		_injured_count -= 1
	_write_empty_row(slot)
	_present[slot] = 0
	_present_count -= 1
	_out_value = slot
	return REFUSE_NONE


# --- readers --------------------------------------------------------------------------------

func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a spawned injury row."""
	return _check_present_slot(slot) == REFUSE_NONE


func is_injured(slot: int) -> bool:
	"""True when `slot` holds a spawned row carrying an aggregate injury."""
	return _check_present_slot(slot) == REFUSE_NONE and _kind[slot] != KIND_NONE


func has_untreated_injury(slot: int) -> bool:
	"""HAZ-001's dangerous-entry term: an aggregate injury exists and treatment has not run.

	An injury in this store is untreated by construction -- `complete_treatment()` is the only
	thing that clears one -- so this is `is_injured()` under the name the entry rule uses. The
	OTHER HAZ-001 terms (health >= 70, hunger > 3500, rest >= 4000, capability, a known
	movement/profile/cargo contract, and resident consent) belong to the movement and priority
	owners and are deliberately NOT decided here.
	"""
	return is_injured(slot)


func kind_of(slot: int) -> IntMath.IntResult:
	"""Aggregate InjuryKind, KIND_NONE when uninjured."""
	return _read(_check_present_slot(slot), _kind[slot] if is_present(slot) else 0)


func severity_of(slot: int) -> IntMath.IntResult:
	"""Aggregate severity: 0 uninjured, 1 minor, 2 serious."""
	return _read(_check_present_slot(slot), _severity[slot] if is_present(slot) else 0)


func untreated_ticks_of(slot: int) -> IntMath.IntResult:
	"""Fixed ticks elapsed since the aggregate injury began, retained across new incidents."""
	return _read(_check_present_slot(slot), _untreated_ticks[slot] if is_present(slot) else 0)


func untreated_hours_of(slot: int) -> IntMath.IntResult:
	"""GDD §4.2 `Injury.untreated_hours`: the floor of the tick counter over 750.

	A DISPLAY AND RULE READING OF THE TICK COUNTER, not a second clock. The health cost of
	those hours is `needs.gd`'s rate term, integrated tick by tick with a retained remainder;
	nothing consumes whole hours from here.
	"""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _untreated_ticks[slot] / TICKS_PER_HOUR)


func care_progress_mwu_of(slot: int) -> IntMath.IntResult:
	"""Treatment work already paid into this resident's aggregate injury, in milli-WU."""
	return _read(_check_present_slot(slot), _care_progress_mwu[slot] if is_present(slot) else 0)


func last_incident_ordinal_of(slot: int) -> IntMath.IntResult:
	"""Highest one-shot incident ordinal already applied here; 0 when none has been."""
	return _read(_check_present_slot(slot),
		_last_incident_ordinal[slot] if is_present(slot) else 0)


func rescuer_slot_of(slot: int) -> IntMath.IntResult:
	"""Directory slot of the assigned rescuer, or NULL_SLOT (-1) when there is none."""
	return _read(_check_present_slot(slot),
		_rescuer_slot[slot] if is_present(slot) else NULL_SLOT)


func rescuer_generation_of(slot: int) -> IntMath.IntResult:
	"""Directory generation of the assigned rescuer, or NULL_GENERATION (0) when there is none."""
	return _read(_check_present_slot(slot),
		_rescuer_generation[slot] if is_present(slot) else NULL_GENERATION)


func has_rescuer(slot: int) -> bool:
	"""True when a rescuer reference is stored for this patient."""
	return _check_present_slot(slot) == REFUSE_NONE and _rescuer_slot[slot] != NULL_SLOT


func rescuer_is_live(slot: int, directory: EntityDirectory) -> bool:
	"""True when the stored rescuer reference still names a live RESIDENT in `directory`.

	A DESPAWNED RESCUER IS NOT SWEPT OUT OF THIS COLUMN, and deliberately so: `rescuer` is an
	EntityRef in the directory's slot/generation space, NOT a row index in this store, so
	`despawn()` here cannot even identify which stored references named the departing
	resident without the directory. That is what generation validation is for -- a reused slot
	carries a new generation and this answers false. A caller acts on a rescue only after
	asking, exactly as HAZ-004 requires a stale patient or helper to refuse.
	"""
	if not has_rescuer(slot) or directory == null:
		return false
	var ref: Vector2i = Vector2i(_rescuer_slot[slot], _rescuer_generation[slot])
	return directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESIDENT)


func airless_episode_active(slot: int) -> bool:
	"""True between the HAZ-002 transition to airless and the return to breathable support."""
	return _check_present_slot(slot) == REFUSE_NONE and _airless_episode[slot] == 1


func exhaustion_latched(slot: int) -> bool:
	"""True once the HAZ-003 exhaustion incident has fired and before it is re-armed."""
	return _check_present_slot(slot) == REFUSE_NONE and _exhaustion_latch[slot] == 1


func care_context_blocked(slot: int) -> bool:
	"""True while HAZ-004 forbids treatment work on this resident's current movement context."""
	return _check_present_slot(slot) == REFUSE_NONE and _care_context_blocked[slot] == 1


func present_count() -> int:
	"""Number of spawned injury rows."""
	return _present_count


func injured_count() -> int:
	"""Number of spawned rows currently carrying an aggregate injury."""
	return _injured_count


func last_refused_slot() -> int:
	"""Row named by the refusal that stopped the last `tick_all()`, or -1."""
	return _last_refused_slot


# --- the needs binding ----------------------------------------------------------------------

static func needs_injury_state_for(severity: int) -> int:
	"""Map an aggregate severity onto `needs.gd`'s INJURY_* health input.

	This is the mapping `needs.gd`'s INJURY_* block records as "deferred with that component",
	and it is the ONLY place it exists. Severity 1 selects INJURY_ACTIVE, whose rate is
	REQ-SET-172's -1/hour; severity 2 selects INJURY_UNTREATED_SERIOUS, whose rate is -4/hour
	and which additionally bars REQ-SET-017 recovery, as §5.2 and HAZ-002 both require.
	"""
	if severity == SEVERITY_SERIOUS:
		return Needs.INJURY_UNTREATED_SERIOUS
	if severity == SEVERITY_MINOR:
		return Needs.INJURY_ACTIVE
	return Needs.INJURY_NONE


func _publish_injury_state(slot: int, needs: Needs) -> StringName:
	"""Push this row's aggregate severity into the single health rate owner."""
	var result: Needs.OpResult = needs.set_injury_state(slot, needs_injury_state_for(_severity[slot]))
	return REFUSE_NONE if result.ok else REFUSE_NEEDS_REFUSED


# --- incidents ------------------------------------------------------------------------------

func apply_incident(slot: int, kind: int, severity: int, immediate_health_loss: int,
		incident_ordinal: int, needs: Needs) -> Needs.OpResult:
	"""Apply one injury incident: its one-shot health loss, then the aggregate merge.

	`incident_ordinal` is the caller's per-resident event ordinal and must strictly exceed the
	last one applied, so a replayed §5.4 hazard roll or a retried job commit refuses instead of
	charging its damage twice (HAZ-004). Returns the signed health the resident absorbed, which
	is 0 for an incident whose specified immediate loss is 0.
	"""
	return _result(_apply_incident_checked(slot, kind, severity, immediate_health_loss,
		incident_ordinal, needs))


func _apply_incident_checked(slot: int, kind: int, severity: int, loss: int,
		ordinal: int, needs: Needs) -> StringName:
	"""Validate everything, charge the health loss, then merge. Refuses before writing.

	ORDERING IS THE DEATH GUARANTEE. `needs.apply_health_event()` is the only step that can
	fail, and it validates before it writes, so a refusal leaves both stores byte-identical.
	It runs BEFORE this store is touched; a lethal loss therefore commits the death first and
	every later call on this row -- treatment included -- meets a dead resident and refuses.
	"""
	var code: StringName = _check_incident_arguments(slot, kind, severity, loss, ordinal, needs)
	if code != REFUSE_NONE:
		return code
	var health: Needs.OpResult = needs.apply_health_event(slot, -loss)
	if not health.ok:
		return REFUSE_NEEDS_REFUSED
	if _kind[slot] == KIND_NONE:
		_injured_count += 1
	_merge_aggregate(slot, kind, severity)
	_last_incident_ordinal[slot] = ordinal
	_out_value = health.value
	return _publish_injury_state(slot, needs)


func _check_incident_arguments(slot: int, kind: int, severity: int, loss: int,
		ordinal: int, needs: Needs) -> StringName:
	"""Every precondition of one incident, checked before any column is written."""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return code
	if kind <= KIND_NONE or kind >= KIND_COUNT:
		return REFUSE_INVALID_KIND
	if severity != SEVERITY_MINOR and severity != SEVERITY_SERIOUS:
		return REFUSE_INVALID_SEVERITY
	if loss < 0 or loss > Needs.HEALTH_MAX:
		return REFUSE_INVALID_HEALTH_LOSS
	if ordinal <= 0:
		return REFUSE_INVALID_ORDINAL
	if ordinal <= _last_incident_ordinal[slot]:
		return REFUSE_DUPLICATE_INCIDENT
	return REFUSE_NONE


func _merge_aggregate(slot: int, kind: int, severity: int) -> void:
	"""GDD §4.2 / HAZ-004 merge: worse severity replaces, ties keep the lower InjuryKind ID.

	`untreated_ticks` and `care_progress_mwu` are untouched on purpose: HAZ-004 states that a
	new incident erases neither elapsed untreated time nor already paid care work.
	"""
	if _kind[slot] == KIND_NONE or severity > _severity[slot]:
		_kind[slot] = kind
		_severity[slot] = severity
		return
	if severity == _severity[slot] and kind < _kind[slot]:
		_kind[slot] = kind


# --- HAZ-002 airless episodes ---------------------------------------------------------------

func begin_airless_episode(slot: int, incident_ordinal: int, needs: Needs) -> Needs.OpResult:
	"""HAZ-002 transition to airless: one EXPOSURE severity 2 incident for the whole episode.

	"If air is exhausted, create ONE EXPOSURE incident for that continuous airless episode; do
	not add an injury every tick." A second call while the episode is still open REFUSES rather
	than quietly doing nothing, so a caller that has lost track of the latch finds out.
	The -125/hour drain itself is `needs.set_airless()`, not this call.
	"""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return _result(code)
	if _airless_episode[slot] == 1:
		return _result(REFUSE_AIRLESS_ACTIVE)
	var applied: Needs.OpResult = apply_incident(slot, AIRLESS_INJURY_KIND,
		AIRLESS_INJURY_SEVERITY, AIRLESS_IMMEDIATE_HEALTH_LOSS, incident_ordinal, needs)
	if not applied.ok:
		return applied
	_airless_episode[slot] = 1
	_out_value = applied.value
	return _result(REFUSE_NONE)


func end_airless_episode(slot: int) -> Needs.OpResult:
	"""Close the episode on reaching breathable support; the injury and its damage remain.

	HAZ-002: "Reaching breathable support ends it for the next interval; the injury remains
	until existing treatment completes. A subsequent airless episode is a distinct incident,
	not a reset of untreated damage or care history." So this clears the latch and NOTHING else.
	"""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if _airless_episode[slot] == 0:
		return _result(REFUSE_AIRLESS_NOT_ACTIVE)
	_airless_episode[slot] = 0
	_out_value = slot
	return _result(REFUSE_NONE)


# --- HAZ-003 exhaustion ---------------------------------------------------------------------

func apply_exhaustion_incident(slot: int, incident_ordinal: int, needs: Needs) -> Needs.OpResult:
	"""HAZ-003 rest-0 exhaustion: one EXHAUSTION severity 1 incident, no immediate health loss.

	Latched until `rearm_exhaustion()` succeeds. The movement-side triggers -- rest 0 while in
	water or on a climb, and the loss of grip that becomes a declared fall -- are EH-05's;
	what lives here is the incident and the latch, because both are aggregate Injury state.
	"""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return _result(code)
	if _exhaustion_latch[slot] == 1:
		return _result(REFUSE_EXHAUSTION_LATCHED)
	var applied: Needs.OpResult = apply_incident(slot, EXHAUSTION_INJURY_KIND,
		EXHAUSTION_INJURY_SEVERITY, EXHAUSTION_IMMEDIATE_HEALTH_LOSS, incident_ordinal, needs)
	if not applied.ok:
		return applied
	_exhaustion_latch[slot] = 1
	_out_value = applied.value
	return _result(REFUSE_NONE)


func rearm_exhaustion(slot: int, needs: Needs) -> Needs.OpResult:
	"""HAZ-003: "Re-arm this incident only after rest recovers to 4000 at safe support."

	The rest threshold is read from `needs.gd` at the moment of the call; the "safe support"
	half is a movement condition the caller must already have established, and no proxy for it
	is invented here. Refuses below the threshold rather than re-arming early.
	"""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return _result(code)
	var rest: IntMath.IntResult = needs.need_of(slot, Needs.NEED_REST)
	if not rest.ok:
		return _result(REFUSE_NEEDS_REFUSED)
	if rest.value < EXHAUSTION_REARM_REST:
		return _result(REFUSE_EXHAUSTION_REARM_REST)
	_exhaustion_latch[slot] = 0
	_out_value = slot
	return _result(REFUSE_NONE)


# --- HAZ-003 declared falls -----------------------------------------------------------------

static func fall_damage(drop_u: int) -> IntMath.IntResult:
	"""HAZ-003 touchdown damage: min(40, ceil(D*8/1024)). Refuses a non-positive drop.

	"A declared fall has a positive drop": a 0 or negative drop is a broken connection record,
	not a free fall, so it refuses instead of returning a 0 that would read as "no damage".
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if drop_u <= 0:
		out.refuse(String(REFUSE_INVALID_DROP))
		return out
	if not IntMath.ceil_div_into(drop_u * FALL_DAMAGE_PER_METRE, UNITS_PER_METRE, out):
		return out
	out.succeed(mini(FALL_MAX_DAMAGE, out.value))
	return out


static func fall_severity(drop_u: int) -> IntMath.IntResult:
	"""HAZ-003: severity 1 for a drop of 2048u or less, severity 2 above it."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if drop_u <= 0:
		out.refuse(String(REFUSE_INVALID_DROP))
		return out
	out.succeed(SEVERITY_MINOR if drop_u <= FALL_SEVERITY_ONE_MAX_DROP_U else SEVERITY_SERIOUS)
	return out


static func fall_recovery_ticks(drop_u: int) -> IntMath.IntResult:
	"""HAZ-003 recovery duration: max(1, ceil(D*30/4096)) fixed ticks.

	PUBLISHED, NOT DRIVEN. The recovery trajectory, the landing and the occupancy it protects
	are `movement.gd`'s (EH-05, blocked). This store computes the authored duration so the two
	cannot disagree, and executes none of it.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if drop_u <= 0:
		out.refuse(String(REFUSE_INVALID_DROP))
		return out
	if not IntMath.ceil_div_into(drop_u * TICKS_PER_SECOND, FALL_RECOVERY_SPEED_U_PER_SECOND, out):
		return out
	out.succeed(maxi(FALL_MINIMUM_TICKS, out.value))
	return out


func apply_fall_injury(slot: int, drop_u: int, incident_ordinal: int,
		needs: Needs) -> Needs.OpResult:
	"""Apply the HAZ-003 touchdown consequence of a declared fall of `drop_u` 1/1024 m units.

	One-shot at touchdown, never per tick of the descent. Returns the health absorbed, which is
	negative; a fall that takes health to 0 kills, and `complete_treatment()` afterwards refuses.
	"""
	var damage: IntMath.IntResult = fall_damage(drop_u)
	if not damage.ok:
		return _result(REFUSE_INVALID_DROP)
	var severity: IntMath.IntResult = fall_severity(drop_u)
	if not severity.ok:
		return _result(REFUSE_INVALID_DROP)
	return apply_incident(slot, FALL_INJURY_KIND, severity.value, damage.value,
		incident_ordinal, needs)


# --- HAZ-004 care ---------------------------------------------------------------------------

func set_care_context_blocked(slot: int, blocked: bool) -> Needs.OpResult:
	"""Declare whether HAZ-004 forbids treatment work in this resident's movement context.

	"No treatment work in active water, on an unsupported climb, during falling or while being
	carried." Which of those the resident is in is the movement owner's fact, so this is an
	input column with a named unavailable default of 0, exactly as `needs.gd` treats beds,
	rooms and weather. No movement state is guessed here.
	"""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	_care_context_blocked[slot] = 1 if blocked else 0
	_out_value = slot
	return _result(REFUSE_NONE)


func add_care_work(slot: int, milli_wu: int, needs: Needs) -> Needs.OpResult:
	"""Pay treatment work into this resident's aggregate injury; returns the new total.

	HAZ-004: "A new incident does not erase ... already paid care work", and "changing helpers
	retains WIP". The progress is therefore a property of the PATIENT's aggregate injury and
	not of whoever is currently working, so a helper swap costs nothing and needs no transfer.
	"""
	return _result(_add_care_work_checked(slot, milli_wu, needs))


func _add_care_work_checked(slot: int, milli_wu: int, needs: Needs) -> StringName:
	"""Validate then accrue care work. Refuses before writing anything."""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return code
	if milli_wu <= 0:
		return REFUSE_INVALID_WORK
	if _kind[slot] == KIND_NONE:
		return REFUSE_NO_INJURY
	if _care_context_blocked[slot] == 1:
		return REFUSE_CARE_BLOCKED
	if not IntMath.checked_add_into(_care_progress_mwu[slot], milli_wu, _math):
		return REFUSE_OVERFLOW
	_care_progress_mwu[slot] = _math.value
	_out_value = _math.value
	return REFUSE_NONE


func complete_treatment(slot: int, required_mwu: int, needs: Needs) -> Needs.OpResult:
	"""REQ-SET-173: clear the aggregate injury and restore 10 health, capped 100.

	`required_mwu` must be exactly CARE_WORK_MWU (assisted) or SELF_CARE_WORK_MWU
	(REQ-SET-174's conscious last resident). Which one applies is a property of the treatment
	JOB, which this store does not model, so it is a checked argument rather than an invented
	mode column; any other number refuses. The herb 1000 + cloth 500 milli-U debit is
	`inventory.gd`'s and must already have been committed. Returns the health absorbed.
	"""
	return _result(_complete_treatment_checked(slot, required_mwu, needs))


func _complete_treatment_checked(slot: int, required_mwu: int, needs: Needs) -> StringName:
	"""Validate, heal, then clear. The heal runs FIRST, which is what makes death final.

	`needs.apply_health_event()` refuses RESIDENT_DEAD before writing, so for a resident whose
	health reached 0 this returns here and the aggregate injury is never cleared: there is no
	ordering in which a corpse is both restored and marked treated. `_check_live_slot()` above
	refuses the same case earlier; the two are deliberately redundant, and the one that
	survives a careless edit is the call that owns health.
	"""
	var code: StringName = _check_treatment_arguments(slot, required_mwu, needs)
	if code != REFUSE_NONE:
		return code
	var health: Needs.OpResult = needs.apply_health_event(slot, CARE_HEALTH_RESTORE)
	if not health.ok:
		return REFUSE_NEEDS_REFUSED
	_injured_count -= 1
	_kind[slot] = KIND_NONE
	_severity[slot] = SEVERITY_NONE
	_untreated_ticks[slot] = 0
	_care_progress_mwu[slot] = 0
	_rescuer_slot[slot] = NULL_SLOT
	_rescuer_generation[slot] = NULL_GENERATION
	_out_value = health.value
	return _publish_injury_state(slot, needs)


func _check_treatment_arguments(slot: int, required_mwu: int, needs: Needs) -> StringName:
	"""Every precondition of a completed treatment, checked before anything is written."""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return code
	if required_mwu != CARE_WORK_MWU and required_mwu != SELF_CARE_WORK_MWU:
		return REFUSE_INVALID_CARE_REQUIREMENT
	if _kind[slot] == KIND_NONE:
		return REFUSE_NO_INJURY
	if _care_context_blocked[slot] == 1:
		return REFUSE_CARE_BLOCKED
	if _care_progress_mwu[slot] < required_mwu:
		return REFUSE_CARE_INCOMPLETE
	return REFUSE_NONE


# --- HAZ-004 rescue relationship ------------------------------------------------------------

func set_rescuer(slot: int, rescuer_ref: Vector2i, directory: EntityDirectory,
		needs: Needs) -> Needs.OpResult:
	"""Record the generation-checked resident carrying this patient (GDD §4.2 Injury.rescuer).

	A RESCUE IS NOT A TREATMENT. GDD §5.2 states that "a rescue does not clear an injury until
	treatment completes", so this writes the reference and NOTHING else: kind, severity,
	untreated ticks and care progress are all untouched, and the patient keeps draining until
	`complete_treatment()` succeeds. REQ-SET-171's one-casualty limit is enforced here; the
	route, the combined envelope, the half speed and the landing are the movement owner's.
	"""
	return _result(_set_rescuer_checked(slot, rescuer_ref, directory, needs))


func _set_rescuer_checked(slot: int, rescuer_ref: Vector2i, directory: EntityDirectory,
		needs: Needs) -> StringName:
	"""Validate the patient, the reference and the one-patient rule, then store the ref."""
	var code: StringName = _check_live_slot(slot, needs)
	if code != REFUSE_NONE:
		return code
	if directory == null:
		return REFUSE_NO_DIRECTORY
	if not directory.is_valid_of_kind(rescuer_ref, EntityDirectory.KIND_RESIDENT):
		return REFUSE_INVALID_RESCUER
	if directory.get_typed_row(rescuer_ref) == slot:
		return REFUSE_RESCUER_IS_PATIENT
	if _rescuer_patient_count(rescuer_ref, slot) >= PATIENTS_PER_RESCUER:
		return REFUSE_RESCUER_BUSY
	_rescuer_slot[slot] = rescuer_ref.x
	_rescuer_generation[slot] = rescuer_ref.y
	_out_value = slot
	return REFUSE_NONE


func _rescuer_patient_count(rescuer_ref: Vector2i, excluding_slot: int) -> int:
	"""Patients this rescuer already carries, by bounded ascending scan of the 512 rows.

	No reverse rescuer-to-patient index is budgeted, and rescue assignment is an event rather
	than a per-tick sweep, so the scan is the honest implementation rather than an unbudgeted
	column. It allocates nothing.
	"""
	var count: int = 0
	for row: int in RESIDENT_CAPACITY:
		if _present[row] == 0 or row == excluding_slot:
			continue
		if _rescuer_slot[row] == rescuer_ref.x and _rescuer_generation[row] == rescuer_ref.y:
			count += 1
	return count


func clear_rescuer(slot: int) -> Needs.OpResult:
	"""Release the rescue relationship. The injury, its damage and its care progress remain."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	_rescuer_slot[slot] = NULL_SLOT
	_rescuer_generation[slot] = NULL_GENERATION
	_out_value = slot
	return _result(REFUSE_NONE)


# --- the untreated clock --------------------------------------------------------------------

func tick_all(needs: Needs) -> Needs.OpResult:
	"""Advance the untreated clock of every living, injured resident by one fixed tick.

	REQ-SET-011: no elapsed time, no speed, no delta. This advances GDD §4.2's
	`untreated_hours` counter ONLY -- the health cost of being untreated is a rate term of
	`needs._health_rate_per_hour()` and is integrated by `needs.tick_all()`, so calling this
	twice in a tick would misreport the hours and calling it never would leave the drain
	running with a frozen counter. The scheduler phase that pairs the two is G02/task08's and
	is not installed from here.
	"""
	_last_refused_slot = -1
	if needs == null:
		return _result(REFUSE_NEEDS_REFUSED)
	var advanced: int = 0
	for slot: int in RESIDENT_CAPACITY:
		if _present[slot] == 0 or _kind[slot] == KIND_NONE:
			continue
		if not needs.is_alive(slot):
			continue
		_untreated_ticks[slot] += 1
		advanced += 1
	_out_value = advanced
	return _result(REFUSE_NONE)


# --- serialization --------------------------------------------------------------------------

func state_bytes() -> PackedByteArray:
	"""Canonical image of every spawned injury row, comparable across two identical worlds.

	NOT A PRODUCTION CALL: it allocates. Rows are emitted in ascending slot, which is the
	order the resident directory itself imposes, so two worlds holding the same injuries
	produce the same image. The save FORMAT does not exist yet (see `gear.gd`'s note); this is
	the deterministic serialization half, and reading an image back is deferred with it.
	"""
	var image: PackedInt64Array = PackedInt64Array()
	image.resize(1 + _present_count * IMAGE_FIELDS_PER_ROW)
	image[0] = _present_count
	var cursor: int = 1
	for slot: int in RESIDENT_CAPACITY:
		if _present[slot] == 0:
			continue
		cursor = _write_image_row(image, cursor, slot)
	return var_to_bytes(image)


func _write_image_row(image: PackedInt64Array, cursor: int, slot: int) -> int:
	"""Write one row's eleven fields into the canonical image; returns the next cursor."""
	image[cursor] = slot
	image[cursor + 1] = _kind[slot]
	image[cursor + 2] = _severity[slot]
	image[cursor + 3] = _untreated_ticks[slot]
	image[cursor + 4] = _care_progress_mwu[slot]
	image[cursor + 5] = _last_incident_ordinal[slot]
	image[cursor + 6] = _rescuer_slot[slot]
	image[cursor + 7] = _rescuer_generation[slot]
	image[cursor + 8] = _airless_episode[slot]
	image[cursor + 9] = _exhaustion_latch[slot]
	image[cursor + 10] = _care_context_blocked[slot]
	return cursor + IMAGE_FIELDS_PER_ROW
