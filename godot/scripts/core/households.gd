extends RefCounted
## PC-04 households and daily care: the bounded owner FAMILY-STATE-R01 specifies.
##
## Adopted under DEC-044 / decision 0521 WITH CHILDREN INACTIVE. This store exists and is tested,
## but NOTHING COMPOSES IT INTO THE LIVE SETTLEMENT YET: no scenario spawns a child, and the pieces
## that would make a composed store correct across a save -- section 4/5 owner registration, the
## family rules fingerprint and the cross-owner admission/lifecycle transaction -- sit behind
## PC-04's open engineering gates (decision 0521 lists each one). A store that held live rows
## without being saved would be future-affecting state a reload silently drops, so it is built
## and validated here and stops at that boundary.
##
## TWO TABLES, ONE OWNER (FAMILY-STATE-R01 §Household owner, §Per-resident state).
##   * Households: 256 rows of (present, generation, persistent_id, member_count) and a fixed
##     8-wide member arena of resident EntityRefs, index row*8 + ordinal, in persistent-ID order.
##     Household IDs are LOCAL to this owner, monotonic from 1, never recycled and never passed
##     as EntityRefs or resident IDs. A row reference is (row, generation), null (-1, 0).
##   * Dependents: exactly 512 rows indexed by the RESIDENT typed row, bound to that resident's
##     full DIRECTORY EntityRef (slot AND generation). `present` follows resident presence, not
##     stage, and the stage stays solely in Residents (MOVE-DEP-R02). A CHILD row carries care;
##     an ADULT/ELDER row carries provider state. Every stage may belong to a household.
## WHY THE WHOLE REF (decision 0996, review R04). The directory allocates its slot and the typed
## row independently, and a generation belongs to a directory SLOT. A resident despawned while
## still bound frees both; another kind can take the slot, and the next resident then reuses the
## typed row under a DIFFERENT slot at the SAME generation. A generation-only binding would read
## the previous tenant's household, care and willingness as the new resident's. Every reader,
## mutator, recovery path and column validator therefore compares (slot, generation).
## Payload: 19720 household bytes + 28680 dependent bytes = 48400 (`payload_bytes()` re-derives
## it from the columns). No scratch is allocated: the 5632-byte selection scratch belongs to the
## care-selection pass, which is held at gate 6 and is not built.
##
## WHAT IS NOT KINSHIP. Membership is a declared living arrangement. Nothing reads a surname,
## a species or an affinity edge to infer it, and membership never consumes a Relationship link.
## A household may mix species and hold unrelated residents.
##
## CARE ARITHMETIC (Brendan's confirmed values, DEC-044). Care is 0..10000, 6500 for a new child,
## integrated by the same signed-remainder rule as Needs but by its OWN integrator, because its
## served rate exceeds Needs' proven rate bound: rate -250000 milli/hour idle or +2750000 while
## receiving service (3000 gross minus the 250 decay that never stops), denominator 750000,
## truncation toward zero, outward remainder discarded at a bound. Latches update once from the
## final care value: critical set <=1500 / clear >2000; low set <=3500 / clear >4000; critical
## forces low; eligibility set <=6000 / clear >=9000. Zero care changes warnings and (when children
## are active) mood, never health: there is no neglect-death roll.
##
## REFUSAL, NOT SENTINELS. Every mutator writes a caller-owned IntMath.IntResult and returns
## its `.ok`. Every mutator validates completely before its first write, so a refusal changes
## nothing and `state_bytes()` proves it.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## FAMILY-STATE-R01: the new canonical owner `households` starts at schema 1. A column set of any
## other version refuses; there is no migration from a pre-family file (LC:117-121, EP v2).
const OWNER_SCHEMA_VERSION: int = 1

const HOUSEHOLD_CAPACITY: int = 256
const MEMBERS_PER_HOUSEHOLD: int = 8
const MEMBER_CAPACITY: int = HOUSEHOLD_CAPACITY * MEMBERS_PER_HOUSEHOLD
const RESIDENT_CAPACITY: int = 512
const PREFERRED_CAREGIVER_MAX: int = 2

const I32_MAX: int = 2147483647
const NEXT_HOUSEHOLD_ID_INITIAL: int = 1
## The scalar may reach I32_MAX + 1, meaning every ID has been issued. It never resets.
const NEXT_HOUSEHOLD_ID_TERMINAL: int = I32_MAX + 1
const NULL_ROW: int = -1
## The clock's first absolute world day (`sim_clock.gd`: day 1 opens at 06:00). A new store is the
## world's first day, so its `served_day` is 1 and a fresh capture validates against a new clock.
const FIRST_WORLD_DAY: int = 1
const NULL_GENERATION: int = 0
const NULL_SLOT: int = EntityDirectory.NULL_SLOT
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

const STAGE_ADULT: int = ResidentsScript.LIFE_STAGE_ADULT
const STAGE_CHILD: int = ResidentsScript.LIFE_STAGE_CHILD
const STAGE_ELDER: int = ResidentsScript.LIFE_STAGE_ELDER

# --- care (DEC-044's confirmed values) ----------------------------------------------------------

const CARE_MIN: int = 0
const CARE_MAX: int = 10000
const CARE_INITIAL_CHILD: int = 6500
const CARE_DECAY_MILLI_PER_HOUR: int = 250000
const CARE_SERVICE_MILLI_PER_HOUR: int = 3000000
const CARE_RATE_IDLE: int = -CARE_DECAY_MILLI_PER_HOUR
const CARE_RATE_SERVED: int = CARE_SERVICE_MILLI_PER_HOUR - CARE_DECAY_MILLI_PER_HOUR
## 750 ticks/hour x 1000 milli-points, as in Needs.
const CARE_DENOMINATOR: int = 750000
const CARE_ELIGIBLE_SET_AT_OR_BELOW: int = 6000
const CARE_ELIGIBLE_CLEAR_AT_OR_ABOVE: int = 9000
const CARE_LOW_SET_AT_OR_BELOW: int = 3500
const CARE_LOW_CLEAR_ABOVE: int = 4000
const CARE_CRITICAL_SET_AT_OR_BELOW: int = 1500
const CARE_CRITICAL_CLEAR_ABOVE: int = 2000
const WARNING_LOW: int = 1
const WARNING_CRITICAL: int = 2
## A service turn is at most 750 ticks of actual paired service; a stable saved one holds 0..749.
const SERVICE_TURN_TICKS: int = 750
## One provider serves at most one child per tick, and a day is 18000 ticks.
const PROVIDER_SERVED_TICKS_MAX: int = 18000
## FAMILY-STATE-R01 v2's child sort key: (ordinary_bit << 45) | (care << 31) | persistent_id.
const SORT_ORDINARY_SHIFT: int = 45
const SORT_CARE_SHIFT: int = 31
## `care_after_tick()` writes [care, remainder].
const CARE_STEP_WIDTH: int = 2

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: String = ""
const REFUSE_RESIDENT_INVALID: String = "HOUSEHOLD_RESIDENT_INVALID"
const REFUSE_RESIDENT_NOT_LIVING: String = "HOUSEHOLD_RESIDENT_NOT_LIVING"
const REFUSE_ALREADY_BOUND: String = "HOUSEHOLD_RESIDENT_ALREADY_BOUND"
const REFUSE_NOT_BOUND: String = "HOUSEHOLD_RESIDENT_NOT_BOUND"
## The row is bound to a previous tenant of this typed row (the despawn skipped `unbind`).
const REFUSE_STALE_BINDING: String = "HOUSEHOLD_STALE_BINDING"
const REFUSE_NOT_STALE: String = "HOUSEHOLD_BINDING_NOT_STALE"
const REFUSE_MEMBER_COUNT: String = "HOUSEHOLD_MEMBER_COUNT"
const REFUSE_MEMBER_DUPLICATE: String = "HOUSEHOLD_MEMBER_DUPLICATE"
const REFUSE_MEMBER_HOUSED: String = "HOUSEHOLD_MEMBER_ALREADY_HOUSED"
const REFUSE_CAPACITY: String = "HOUSEHOLD_CAPACITY"
const REFUSE_ID_EXHAUSTED: String = "HOUSEHOLD_ID_EXHAUSTED"
const REFUSE_TARGET_NOT_CHILD: String = "CARE_TARGET_NOT_CHILD"
const REFUSE_TARGET_NOT_PROVIDER_STAGE: String = "CARE_TARGET_NOT_ADULT_OR_ELDER"
const REFUSE_PREFERENCE_COUNT: String = "CARE_PREFERENCE_COUNT"
const REFUSE_CAREGIVER_DUPLICATE: String = "CARE_PREFERENCE_DUPLICATE"
const REFUSE_CHILD_NOT_ELIGIBLE: String = "CARE_CHILD_NOT_ELIGIBLE"
const REFUSE_CHILD_SERVED: String = "CARE_CHILD_ALREADY_SERVED"
const REFUSE_PROVIDER_UNWILLING: String = "CARE_PROVIDER_UNWILLING"
const REFUSE_PROVIDER_BUSY: String = "CARE_PROVIDER_BUSY"
const REFUSE_NO_SERVICE: String = "CARE_NO_SERVICE"
const REFUSE_PAIRED_SHAPE: String = "CARE_PAIRED_SHAPE"
const REFUSE_PAIRED_WITHOUT_SERVICE: String = "CARE_PAIRED_WITHOUT_SERVICE"
const REFUSE_PROVIDER_DAY_FULL: String = "CARE_PROVIDER_DAY_FULL"
const REFUSE_DAY_NOT_ADVANCING: String = "CARE_DAY_NOT_ADVANCING"
const REFUSE_CARE_DOMAIN: String = "CARE_DOMAIN"
const REFUSE_LOAD_BARRIER: String = "HOUSEHOLD_LOAD_BARRIER_NOT_HELD"
const REFUSE_COLUMN_SHAPE: String = "HOUSEHOLD_COLUMN_SHAPE"
const REFUSE_COLUMN_SCHEMA: String = "HOUSEHOLD_COLUMN_SCHEMA_VERSION"
const REFUSE_COLUMN_NEXT_ID: String = "HOUSEHOLD_COLUMN_NEXT_ID"
const REFUSE_COLUMN_HOUSEHOLD_ROW: String = "HOUSEHOLD_COLUMN_HOUSEHOLD_ROW"
const REFUSE_COLUMN_HOUSEHOLD_ID: String = "HOUSEHOLD_COLUMN_HOUSEHOLD_ID"
const REFUSE_COLUMN_MEMBER: String = "HOUSEHOLD_COLUMN_MEMBER"
const REFUSE_COLUMN_RECIPROCITY: String = "HOUSEHOLD_COLUMN_RECIPROCITY"
const REFUSE_COLUMN_BINDING: String = "HOUSEHOLD_COLUMN_BINDING"
const REFUSE_COLUMN_UNUSED: String = "HOUSEHOLD_COLUMN_UNUSED_VALUE"
const REFUSE_COLUMN_STAGE: String = "HOUSEHOLD_COLUMN_STAGE_RESTRICTION"
const REFUSE_COLUMN_CARE: String = "HOUSEHOLD_COLUMN_CARE"
const REFUSE_COLUMN_LATCH: String = "HOUSEHOLD_COLUMN_LATCH"
const REFUSE_COLUMN_PREFERENCE: String = "HOUSEHOLD_COLUMN_PREFERENCE"
const REFUSE_COLUMN_PROVIDER: String = "HOUSEHOLD_COLUMN_PROVIDER"
const REFUSE_COLUMN_SERVED_DAY: String = "HOUSEHOLD_COLUMN_SERVED_DAY"


# --- household columns (FAMILY-STATE-R01, 19720 bytes) -----------------------------------------

var _h_present: PackedByteArray = PackedByteArray()
var _h_generation: PackedInt32Array = PackedInt32Array()
var _h_persistent_id: PackedInt32Array = PackedInt32Array()
var _h_member_count: PackedInt32Array = PackedInt32Array()
var _h_member_slot: PackedInt32Array = PackedInt32Array()
var _h_member_generation: PackedInt32Array = PackedInt32Array()
var _next_household_id: int = NEXT_HOUSEHOLD_ID_INITIAL

# --- per-resident dependent/provider columns (FAMILY-STATE-R01 + decision 0996, 28680 bytes) ---

var _d_present: PackedByteArray = PackedByteArray()
var _d_care_eligible: PackedByteArray = PackedByteArray()
var _d_warning_bits: PackedByteArray = PackedByteArray()
var _d_willing: PackedByteArray = PackedByteArray()
## The bound resident's directory EntityRef, as a (slot, generation) pair of columns.
var _d_resident_slot: PackedInt32Array = PackedInt32Array()
var _d_resident_generation: PackedInt32Array = PackedInt32Array()
var _d_household_row: PackedInt32Array = PackedInt32Array()
var _d_household_generation: PackedInt32Array = PackedInt32Array()
var _d_preferred_0: PackedInt32Array = PackedInt32Array()
var _d_preferred_1: PackedInt32Array = PackedInt32Array()
var _d_care: PackedInt32Array = PackedInt32Array()
var _d_care_remainder: PackedInt64Array = PackedInt64Array()
var _d_provider_slot: PackedInt32Array = PackedInt32Array()
var _d_provider_generation: PackedInt32Array = PackedInt32Array()
var _d_service_paired_ticks: PackedInt32Array = PackedInt32Array()
var _d_provider_served_ticks_today: PackedInt32Array = PackedInt32Array()
## The absolute world day `_d_provider_served_ticks_today` counts: FIRST_WORLD_DAY until a midnight.
var _served_day: int = FIRST_WORLD_DAY

# --- collaborators and scratch (not state) ------------------------------------------------------

var _residents: ResidentsScript = null
var _directory: EntityDirectory = null
## `care_after_tick()`'s two outputs [care, remainder], consumed before the next row.
var _care_step: PackedInt64Array = PackedInt64Array()
var _calendar: SimClockScript.Calendar = SimClockScript.Calendar.new()


func _init(p_residents: ResidentsScript) -> void:
	"""Compose with one Residents store (and through it the directory and Needs)."""
	assert(p_residents != null, "the household owner composes with a Residents store")
	@warning_ignore("assert_always_true") assert(RESIDENT_CAPACITY == ResidentsScript.RESIDENT_CAPACITY,
		"dependent rows are resident rows")
	_residents = p_residents
	_directory = p_residents.directory()
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""The only place a column is sized (ARCH-MEM-005: allocate once)."""
	_h_present.resize(HOUSEHOLD_CAPACITY)
	for column: PackedInt32Array in [_h_generation, _h_persistent_id, _h_member_count]:
		column.resize(HOUSEHOLD_CAPACITY)
	_h_member_slot.resize(MEMBER_CAPACITY)
	_h_member_generation.resize(MEMBER_CAPACITY)
	for column: PackedByteArray in [_d_present, _d_care_eligible, _d_warning_bits, _d_willing]:
		column.resize(RESIDENT_CAPACITY)
	for column: PackedInt32Array in [_d_resident_slot, _d_resident_generation, _d_household_row,
			_d_household_generation, _d_preferred_0, _d_preferred_1, _d_care, _d_provider_slot,
			_d_provider_generation, _d_service_paired_ticks, _d_provider_served_ticks_today]:
		column.resize(RESIDENT_CAPACITY)
	_d_care_remainder.resize(RESIDENT_CAPACITY)
	_care_step.resize(CARE_STEP_WIDTH)


func clear() -> void:
	"""Return every column to its canonical unused value and reset both scalars."""
	_h_present.fill(0)
	_h_generation.fill(0)
	_h_persistent_id.fill(0)
	_h_member_count.fill(0)
	_h_member_slot.fill(NULL_SLOT)
	_h_member_generation.fill(NULL_GENERATION)
	_next_household_id = NEXT_HOUSEHOLD_ID_INITIAL
	for row: int in RESIDENT_CAPACITY:
		_clear_dependent_row(row)
	_served_day = FIRST_WORLD_DAY


func _clear_dependent_row(row: int) -> void:
	"""Write FAMILY-STATE-R01's canonical unused value into every column of one dependent row."""
	_d_present[row] = 0
	_d_care_eligible[row] = 0
	_d_warning_bits[row] = 0
	_d_willing[row] = 0
	_d_resident_slot[row] = NULL_SLOT
	_d_resident_generation[row] = NULL_GENERATION
	_d_household_row[row] = NULL_ROW
	_d_household_generation[row] = NULL_GENERATION
	_d_preferred_0[row] = 0
	_d_preferred_1[row] = 0
	_d_care[row] = 0
	_d_care_remainder[row] = 0
	_d_provider_slot[row] = NULL_SLOT
	_d_provider_generation[row] = NULL_GENERATION
	_d_service_paired_ticks[row] = 0
	_d_provider_served_ticks_today[row] = 0


# --- pure arithmetic (no store state) -----------------------------------------------------------

static func care_after_tick(care: int, remainder: int, served: bool, out: PackedInt64Array) -> bool:
	"""One tick of care: out = [care', remainder']. False, leaving `out` alone, on a bad input.

	Rate -250000 idle or +2750000 served (milli/hour), denominator 750000, truncation toward zero,
	clamp 0..10000, and only the remainder that pushes farther outside a reached bound discarded.
	|remainder + rate| < 3500000, so nothing approaches int64.
	"""
	if out.size() != CARE_STEP_WIDTH or care < CARE_MIN or care > CARE_MAX:
		return false
	if remainder >= CARE_DENOMINATOR or remainder <= -CARE_DENOMINATOR:
		return false
	var accumulator: int = remainder + (CARE_RATE_SERVED if served else CARE_RATE_IDLE)
	@warning_ignore("integer_division") var whole: int = accumulator / CARE_DENOMINATOR
	accumulator -= whole * CARE_DENOMINATOR
	var value: int = clampi(care + whole, CARE_MIN, CARE_MAX)
	if (value == CARE_MAX and accumulator > 0) or (value == CARE_MIN and accumulator < 0):
		accumulator = 0
	out[0] = value
	out[1] = accumulator
	return true


static func warning_bits_after(care: int, bits: int) -> int:
	"""The low/critical latch byte after one update from the final care value.

	Critical sets at <=1500 and clears only above 2000; low sets at <=3500 and clears only above
	4000; critical forces low. Between the thresholds a latch keeps its previous value.
	"""
	var critical: bool = (bits & WARNING_CRITICAL) != 0
	var low: bool = (bits & WARNING_LOW) != 0
	if care <= CARE_CRITICAL_SET_AT_OR_BELOW:
		critical = true
	elif care > CARE_CRITICAL_CLEAR_ABOVE:
		critical = false
	if care <= CARE_LOW_SET_AT_OR_BELOW:
		low = true
	elif care > CARE_LOW_CLEAR_ABOVE:
		low = false
	if critical:
		low = true
	return (WARNING_CRITICAL if critical else 0) | (WARNING_LOW if low else 0)


static func eligibility_after(care: int, eligible: int) -> int:
	"""The ordinary-care eligibility latch: set at <=6000, cleared at >=9000, otherwise retained."""
	if care <= CARE_ELIGIBLE_SET_AT_OR_BELOW:
		return 1
	if care >= CARE_ELIGIBLE_CLEAR_AT_OR_ABOVE:
		return 0
	return eligible


static func child_sort_key_into(critical: bool, care: int, persistent_id: int,
		out: IntMath.IntResult) -> bool:
	"""FAMILY-STATE-R01 v2's ascending selection key into `out`, or an explicit refusal.

	(ordinary_bit << 45) | (care << 31) | persistent_id: critical children first, then lower care,
	then lower persistent ID. Every valid key is below 2^46. An out-of-domain input refuses
	rather than returning a sentinel that would sort ahead of every real child.
	"""
	if care < CARE_MIN or care > CARE_MAX or persistent_id < 1 or persistent_id > I32_MAX:
		return out.refuse(REFUSE_CARE_DOMAIN)
	var ordinary_bit: int = 0 if critical else 1
	return out.succeed((ordinary_bit << SORT_ORDINARY_SHIFT) | (care << SORT_CARE_SHIFT)
		| persistent_id)


# --- resident resolution ------------------------------------------------------------------------

func _row_of_ref(ref: Vector2i) -> int:
	"""Typed row of a live resident directory ref held by Residents, or NULL_ROW. No allocation."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESIDENT):
		return NULL_ROW
	var row: int = _directory.get_typed_row(ref)
	if not _residents.is_present(row):
		return NULL_ROW
	return row


func _bound_row_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Resolve a ref to the row bound to THIS resident (dead or alive) into `out`, or refuse.

	The stored binding ref -- slot AND generation -- must equal the ref's: a row still bound to a
	previous tenant of the same typed row is refused as STALE, never read as the new resident's,
	even when that tenant's directory slot carried the same generation (decision 0996).
	"""
	var row: int = _row_of_ref(ref)
	if row == NULL_ROW:
		return out.refuse(REFUSE_RESIDENT_INVALID)
	if _d_present[row] == 0:
		return out.refuse(REFUSE_NOT_BOUND)
	if _bound_ref_of(row) != ref:
		return out.refuse(REFUSE_STALE_BINDING)
	return out.succeed(row)


func _bound_living_row(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Resolve a ref to a bound, living resident row into `out`, or refuse."""
	if not _bound_row_into(ref, out):
		return false
	if not _residents.is_alive(out.value):
		return out.refuse(REFUSE_RESIDENT_NOT_LIVING)
	return true


func _bound_ref_of(row: int) -> Vector2i:
	"""The directory EntityRef a row is bound to, (slot, generation); NULL_REF when unbound."""
	return Vector2i(_d_resident_slot[row], _d_resident_generation[row])


func _binding_is_current(row: int) -> bool:
	"""True when a bound row's stored EntityRef is its present tenant's whole directory ref."""
	return _d_present[row] == 1 and _bound_ref_of(row) == _residents.ref_of(row)


func _is_provider_stage(row: int) -> bool:
	"""True for an ADULT or ELDER row. A CHILD is never a provider (DEC-032)."""
	var stage: int = _residents.life_stage_code_of(row)
	return stage == STAGE_ADULT or stage == STAGE_ELDER


func _persistent_id_of_row(row: int) -> int:
	"""Persistent ID of a present resident row, through the directory."""
	return _directory.get_persistent_id(_residents.ref_of(row))


# --- binding a resident row ---------------------------------------------------------------------

func bind_resident_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Create the dependent row of one present resident at its stage defaults. Value: the row.

	CHILD: care 6500, remainder 0, not eligible, no warning, unwilling. ADULT/ELDER: willing by
	default (DEC-044), care state canonical zero. No household and no preference is implied. A
	resident that died before binding can still be bound, because every present resident row
	must be bound for the image to validate. A row still bound to a previous tenant refuses
	STALE until `release_stale_row_into()` clears it.
	"""
	var row: int = _row_of_ref(ref)
	if row == NULL_ROW:
		return out.refuse(REFUSE_RESIDENT_INVALID)
	if _d_present[row] == 1:
		return out.refuse(REFUSE_ALREADY_BOUND if _bound_ref_of(row) == ref
			else REFUSE_STALE_BINDING)
	_clear_dependent_row(row)
	_d_present[row] = 1
	_d_resident_slot[row] = ref.x
	_d_resident_generation[row] = ref.y
	if _residents.life_stage_code_of(row) == STAGE_CHILD:
		_d_care[row] = CARE_INITIAL_CHILD
	else:
		_d_willing[row] = 1
	return out.succeed(row)


func detach_resident_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Death/departure network cleanup for one bound resident (dead or alive). Value: its row.

	Removes this resident from its household (retiring the row if it was the last member),
	ends every service it gives or receives, removes its persistent ID from every live
	preference pair and clears its own preferences. Surviving members, their other links and
	all care values stay. The row stays bound: it follows Residents' presence. The caller's
	lifecycle transaction must commit the historical record FIRST (gate 2, decision 0521).
	"""
	if not _bound_row_into(ref, out):
		return false
	var row: int = out.value
	_leave_household(row)
	_end_services_involving(ref, row)
	_scrub_preferences_naming(_persistent_id_of_row(row))
	_d_preferred_0[row] = 0
	_d_preferred_1[row] = 0
	return out.succeed(row)


func unbind_resident_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Detach one resident, then return its row to canonical unused. For Residents' despawn.

	Called before the directory slot is released, so the ref still validates; no reuse of the
	slot can inherit the previous tenant's household, care or provider fairness.
	"""
	if not detach_resident_into(ref, out):
		return false
	_clear_dependent_row(out.value)
	return true


func _leave_household(row: int) -> void:
	"""Remove one resident from its household, compacting the member arena; retire if empty."""
	var household: int = _d_household_row[row]
	if household == NULL_ROW:
		return
	_compact_members(household, _residents.ref_of(row))
	_d_household_row[row] = NULL_ROW
	_d_household_generation[row] = NULL_GENERATION


func _compact_members(household: int, leaving: Vector2i) -> void:
	"""Drop `leaving` and any member whose ref no longer resolves; null the tail; retire if empty.

	A member ref stops resolving only when its resident was despawned while still bound, which
	is exactly the stale case `release_stale_row_into()` repairs. Order is preserved.
	"""
	var base: int = household * MEMBERS_PER_HOUSEHOLD
	var write: int = 0
	for ordinal: int in _h_member_count[household]:
		var member: Vector2i = Vector2i(_h_member_slot[base + ordinal],
			_h_member_generation[base + ordinal])
		if member == leaving or _row_of_ref(member) == NULL_ROW:
			continue
		_h_member_slot[base + write] = member.x
		_h_member_generation[base + write] = member.y
		write += 1
	for ordinal: int in range(write, MEMBERS_PER_HOUSEHOLD):
		_h_member_slot[base + ordinal] = NULL_SLOT
		_h_member_generation[base + ordinal] = NULL_GENERATION
	_h_member_count[household] = write
	if write == 0:
		_retire_household(household)


func release_stale_row_into(row: int, out: IntMath.IntResult) -> bool:
	"""Clear a row still bound to a PREVIOUS tenant of its typed row. Value: the row.

	The recovery for a despawn that skipped `unbind_resident_into()`. The previous tenant's
	directory ref no longer validates, so its household entry and any service it gave are found
	by that fact; live preferences naming a persistent ID no present resident holds are removed.
	Surviving members and their other links are untouched. Refuses a row bound to its present
	tenant, which must go through `unbind_resident_into()` instead.
	"""
	if row < 0 or row >= RESIDENT_CAPACITY or _d_present[row] == 0:
		return out.refuse(REFUSE_NOT_BOUND)
	if _binding_is_current(row):
		return out.refuse(REFUSE_NOT_STALE)
	if _d_household_row[row] != NULL_ROW:
		_compact_members(_d_household_row[row], NULL_REF)
	_end_service_row(row)
	_end_services_without_a_provider()
	_scrub_unresolvable_preferences()
	_clear_dependent_row(row)
	return out.succeed(row)


func _end_services_without_a_provider() -> void:
	"""End every service whose provider ref no longer resolves to a present resident."""
	for child: int in RESIDENT_CAPACITY:
		if _d_provider_slot[child] == NULL_SLOT:
			continue
		var provider: Vector2i = Vector2i(_d_provider_slot[child], _d_provider_generation[child])
		if _row_of_ref(provider) == NULL_ROW:
			_end_service_row(child)


func _scrub_unresolvable_preferences() -> void:
	"""Remove every live preference naming a persistent ID that no present resident holds."""
	var pids: PackedInt64Array = _persistent_id_index(_residents)
	for row: int in RESIDENT_CAPACITY:
		var second: int = _d_preferred_1[row]
		if second != 0 and _row_of_persistent_id(pids, second) == NULL_ROW:
			_d_preferred_1[row] = 0
		var first: int = _d_preferred_0[row]
		if first != 0 and _row_of_persistent_id(pids, first) == NULL_ROW:
			_d_preferred_0[row] = _d_preferred_1[row]
			_d_preferred_1[row] = 0


func _retire_household(household: int) -> void:
	"""Clear an empty household row. Its generation is kept, so a reused row is a new identity."""
	_h_present[household] = 0
	_h_persistent_id[household] = 0
	_h_member_count[household] = 0


func _end_services_involving(ref: Vector2i, row: int) -> void:
	"""Clear the service this row receives and every service it gives, by a bounded 512 scan."""
	_end_service_row(row)
	for child: int in RESIDENT_CAPACITY:
		if _d_provider_slot[child] == ref.x and _d_provider_generation[child] == ref.y:
			_end_service_row(child)


func _end_service_row(child: int) -> void:
	"""Clear one child's assignment and session counter; care and daily totals are untouched."""
	_d_provider_slot[child] = NULL_SLOT
	_d_provider_generation[child] = NULL_GENERATION
	_d_service_paired_ticks[child] = 0


func _scrub_preferences_naming(persistent_id: int) -> void:
	"""Remove one persistent ID from every live preference pair, keeping zeros at the end."""
	for row: int in RESIDENT_CAPACITY:
		if _d_preferred_1[row] == persistent_id:
			_d_preferred_1[row] = 0
		if _d_preferred_0[row] == persistent_id:
			_d_preferred_0[row] = _d_preferred_1[row]
			_d_preferred_1[row] = 0


# --- households ---------------------------------------------------------------------------------

func create_household_into(member_refs: Array[Vector2i], out: IntMath.IntResult) -> bool:
	"""Allocate one household of 1..8 bound, living, currently unhoused residents. Value: its row.

	Every member and both sides of the membership are preflighted before the first write, and
	nothing fallible follows it. Members are stored in persistent-ID order; stages and species
	may mix freely, and no relationship is inferred from a name or species.
	"""
	var keys: PackedInt64Array = PackedInt64Array()
	if not _member_keys_into(member_refs, keys, out):
		return false
	var household: int = _free_household_row()
	if household == NULL_ROW:
		return out.refuse(REFUSE_CAPACITY)
	if _next_household_id >= NEXT_HOUSEHOLD_ID_TERMINAL:
		return out.refuse(REFUSE_ID_EXHAUSTED)
	_commit_household(household, keys)
	return out.succeed(household)


func _member_keys_into(member_refs: Array[Vector2i], keys: PackedInt64Array,
		out: IntMath.IntResult) -> bool:
	"""Validate every proposed member and fill `keys` with (persistent_id << 9 | row), sorted."""
	if member_refs.is_empty() or member_refs.size() > MEMBERS_PER_HOUSEHOLD:
		return out.refuse(REFUSE_MEMBER_COUNT)
	for ref: Vector2i in member_refs:
		if not _bound_living_row(ref, out):
			return false
		var row: int = out.value
		if _d_household_row[row] != NULL_ROW:
			return out.refuse(REFUSE_MEMBER_HOUSED)
		keys.append((_persistent_id_of_row(row) << 9) | row)
	keys.sort()
	for index: int in range(1, keys.size()):
		if keys[index] == keys[index - 1]:
			return out.refuse(REFUSE_MEMBER_DUPLICATE)
	return out.succeed(keys.size())


func _free_household_row() -> int:
	"""Lowest free row whose retained generation can still advance, or NULL_ROW."""
	for household: int in HOUSEHOLD_CAPACITY:
		if _h_present[household] == 0 and _h_generation[household] < I32_MAX:
			return household
	return NULL_ROW


func _commit_household(household: int, keys: PackedInt64Array) -> void:
	"""Write a preflighted household and every member's back-reference. Infallible."""
	_h_present[household] = 1
	_h_generation[household] += 1
	_h_persistent_id[household] = _next_household_id
	_next_household_id += 1
	_h_member_count[household] = keys.size()
	var base: int = household * MEMBERS_PER_HOUSEHOLD
	for ordinal: int in keys.size():
		var row: int = keys[ordinal] & 511
		var ref: Vector2i = _residents.ref_of(row)
		_h_member_slot[base + ordinal] = ref.x
		_h_member_generation[base + ordinal] = ref.y
		_d_household_row[row] = household
		_d_household_generation[row] = _h_generation[household]


# --- preferences, willingness and service ------------------------------------------------------

func set_preferred_caregivers_into(child_ref: Vector2i, caregiver_refs: Array[Vector2i],
		out: IntMath.IntResult) -> bool:
	"""Name 0..2 distinct living ADULT/ELDER preferred caregivers for a living CHILD.

	Stored as persistent IDs ascending with 0 only at the end. A preference may name someone
	outside the household and never prevents community fallback. Value: the count stored.
	"""
	if not _bound_living_row(child_ref, out):
		return false
	var child: int = out.value
	if _residents.life_stage_code_of(child) != STAGE_CHILD:
		return out.refuse(REFUSE_TARGET_NOT_CHILD)
	if caregiver_refs.size() > PREFERRED_CAREGIVER_MAX:
		return out.refuse(REFUSE_PREFERENCE_COUNT)
	var ids: PackedInt64Array = PackedInt64Array()
	for ref: Vector2i in caregiver_refs:
		if not _bound_living_row(ref, out):
			return false
		if not _is_provider_stage(out.value):
			return out.refuse(REFUSE_TARGET_NOT_PROVIDER_STAGE)
		ids.append(_persistent_id_of_row(out.value))
	ids.sort()
	if ids.size() == 2 and ids[0] == ids[1]:
		return out.refuse(REFUSE_CAREGIVER_DUPLICATE)
	_d_preferred_0[child] = ids[0] if ids.size() > 0 else 0
	_d_preferred_1[child] = ids[1] if ids.size() > 1 else 0
	return out.succeed(ids.size())


func set_willing_into(ref: Vector2i, willing: bool, out: IntMath.IntResult) -> bool:
	"""Turn one living ADULT/ELDER's daily-care willingness on or off. A CHILD refuses.

	Turning it off ends an active service only at the next safe boundary, which the service
	integration owns (gate 6); medical rescue policy is never touched.
	"""
	if not _bound_living_row(ref, out):
		return false
	if not _is_provider_stage(out.value):
		return out.refuse(REFUSE_TARGET_NOT_PROVIDER_STAGE)
	_d_willing[out.value] = 1 if willing else 0
	return out.succeed(_d_willing[out.value])


func assign_provider_into(child_ref: Vector2i, provider_ref: Vector2i,
		out: IntMath.IntResult) -> bool:
	"""Stage one ordinary-care service. Structural rules only; selection facts are the pass's.

	Child: bound, living CHILD, eligible, unserved. Provider: bound, living ADULT/ELDER, willing,
	serving no one. The instantaneous hunger/rest/health/route gates belong to the selection
	pass that calls this (gate 6) and are not re-derived here. Value: the child row.
	"""
	if not _bound_living_row(child_ref, out):
		return false
	var child: int = out.value
	if _residents.life_stage_code_of(child) != STAGE_CHILD:
		return out.refuse(REFUSE_TARGET_NOT_CHILD)
	if _d_care_eligible[child] == 0:
		return out.refuse(REFUSE_CHILD_NOT_ELIGIBLE)
	if _d_provider_slot[child] != NULL_SLOT:
		return out.refuse(REFUSE_CHILD_SERVED)
	if not _provider_available_into(provider_ref, out):
		return false
	_d_provider_slot[child] = provider_ref.x
	_d_provider_generation[child] = provider_ref.y
	_d_service_paired_ticks[child] = 0
	return out.succeed(child)


func _provider_available_into(provider_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Refuse a provider that is not a bound, living, willing ADULT/ELDER serving no child."""
	if not _bound_living_row(provider_ref, out):
		return false
	if not _is_provider_stage(out.value):
		return out.refuse(REFUSE_TARGET_NOT_PROVIDER_STAGE)
	if _d_willing[out.value] == 0:
		return out.refuse(REFUSE_PROVIDER_UNWILLING)
	if _d_provider_served_ticks_today[out.value] >= PROVIDER_SERVED_TICKS_MAX:
		return out.refuse(REFUSE_PROVIDER_DAY_FULL)
	for child: int in RESIDENT_CAPACITY:
		if _d_provider_slot[child] == provider_ref.x \
				and _d_provider_generation[child] == provider_ref.y:
			return out.refuse(REFUSE_PROVIDER_BUSY)
	return out.succeed(out.value)


func end_service_into(child_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""End one child's service (an interruption). Received care and daily totals are kept."""
	if not _bound_row_into(child_ref, out):
		return false
	var row: int = out.value
	if _d_provider_slot[row] == NULL_SLOT:
		return out.refuse(REFUSE_NO_SERVICE)
	_end_service_row(row)
	return out.succeed(row)


# --- ARCH-SYS-017a care integration and the 019a daily reset -----------------------------------

func advance_care_into(paired: PackedByteArray, out: IntMath.IntResult) -> bool:
	"""Integrate one tick of care for every living CHILD row. Value: children integrated.

	`paired[row] == 1` states that the child at `row` actually received paired service over the
	preceding committed interval; travel and waiting are 0 and earn nothing. Every flag is
	validated before any row moves. A paired tick counts toward the turn and the provider's daily
	share; then the latches update and a service ends on completion (care >= 9000) before the
	750-tick turn limit. Interruptions are the caller's (`end_service_into()`).
	"""
	if not _paired_refusal_into(paired, out):
		return false
	var integrated: int = 0
	for row: int in RESIDENT_CAPACITY:
		if _d_present[row] == 0 or _residents.life_stage_code_of(row) != STAGE_CHILD:
			continue
		if not _residents.is_alive(row):
			continue
		if not _advance_child(row, paired[row] == 1):
			return out.refuse(REFUSE_CARE_DOMAIN)
		integrated += 1
	return out.succeed(integrated)


func _paired_refusal_into(paired: PackedByteArray, out: IntMath.IntResult) -> bool:
	"""Refuse a paired column of the wrong shape, a non-0/1 byte, or a pair with no service."""
	if paired.size() != RESIDENT_CAPACITY:
		return out.refuse(REFUSE_PAIRED_SHAPE)
	for row: int in RESIDENT_CAPACITY:
		if _d_present[row] == 1 and not _binding_is_current(row):
			return out.refuse(REFUSE_STALE_BINDING)
		if paired[row] == 0:
			continue
		if paired[row] != 1 or _d_present[row] == 0 or _d_provider_slot[row] == NULL_SLOT \
				or not _residents.is_alive(row):
			return out.refuse(REFUSE_PAIRED_WITHOUT_SERVICE)
		var provider: int = _row_of_ref(
			Vector2i(_d_provider_slot[row], _d_provider_generation[row]))
		if provider == NULL_ROW or not _residents.is_alive(provider):
			return out.refuse(REFUSE_PAIRED_WITHOUT_SERVICE)
		if _d_provider_served_ticks_today[provider] >= PROVIDER_SERVED_TICKS_MAX:
			return out.refuse(REFUSE_PROVIDER_DAY_FULL)
	return out.succeed(0)


func _advance_child(row: int, served: bool) -> bool:
	"""One child's tick: integrate, count the paired tick, update latches, finish the service.

	False, writing nothing to this row, if its stored care is outside the validated domain. That
	is an invariant break; the sweep stops there and refuses rather than writing stale scratch.
	"""
	if not care_after_tick(_d_care[row], _d_care_remainder[row], served, _care_step):
		return false
	_d_care[row] = _care_step[0]
	_d_care_remainder[row] = _care_step[1]
	if served:
		_d_service_paired_ticks[row] += 1
		var provider: int = _directory.get_typed_row(
			Vector2i(_d_provider_slot[row], _d_provider_generation[row]))
		_d_provider_served_ticks_today[provider] += 1
	_d_warning_bits[row] = warning_bits_after(_d_care[row], _d_warning_bits[row])
	_d_care_eligible[row] = eligibility_after(_d_care[row], _d_care_eligible[row])
	if _d_provider_slot[row] != NULL_SLOT and (_d_care_eligible[row] == 0
			or _d_service_paired_ticks[row] >= SERVICE_TURN_TICKS):
		_end_service_row(row)
	return true


func begin_day_into(day: int, out: IntMath.IntResult) -> bool:
	"""ARCH-SYS-019a's midnight leg: zero every provider's daily share and open `day`.

	Active assignments and session counters are preserved. The caller has already credited the
	interval ending at midnight to the previous day. Refuses a day that does not advance.
	"""
	if day <= _served_day:
		return out.refuse(REFUSE_DAY_NOT_ADVANCING)
	_d_provider_served_ticks_today.fill(0)
	_served_day = day
	return out.succeed(day)


# --- readers ------------------------------------------------------------------------------------

func is_bound(row: int) -> bool:
	"""True when `row` is in range and bound to its PRESENT tenant (never a previous one)."""
	return row >= 0 and row < RESIDENT_CAPACITY and _binding_is_current(row)


func care_of(row: int) -> int:
	"""Care of a bound row (canonical 0 for ADULT/ELDER); -1 for an unbound row."""
	return _d_care[row] if is_bound(row) else -1


func care_remainder_of(row: int) -> int:
	"""Retained signed care remainder of a bound row; 0 for an unbound row."""
	return _d_care_remainder[row] if is_bound(row) else 0


func warning_bits_of(row: int) -> int:
	"""Low (bit 0) and critical (bit 1) care latches of a bound row."""
	return _d_warning_bits[row] if is_bound(row) else 0


func is_care_eligible(row: int) -> bool:
	"""True while a bound child's ordinary-care eligibility latch is set."""
	return is_bound(row) and _d_care_eligible[row] == 1


func is_willing(row: int) -> bool:
	"""True when a bound ADULT/ELDER row is willing to give daily care."""
	return is_bound(row) and _d_willing[row] == 1


func household_row_of(row: int) -> int:
	"""Household row of a bound resident row, or NULL_ROW."""
	return _d_household_row[row] if is_bound(row) else NULL_ROW


func household_ref(household: int) -> Vector2i:
	"""(row, generation) of a present household, or the null pair."""
	if household < 0 or household >= HOUSEHOLD_CAPACITY or _h_present[household] == 0:
		return Vector2i(NULL_ROW, NULL_GENERATION)
	return Vector2i(household, _h_generation[household])


func household_id_of(household: int) -> int:
	"""Local persistent ID of a present household, or 0."""
	return _h_persistent_id[household] if household_ref(household).x != NULL_ROW else 0


func member_count_of(household: int) -> int:
	"""Living member count of a present household, or 0."""
	return _h_member_count[household] if household_ref(household).x != NULL_ROW else 0


func member_ref_of(household: int, ordinal: int) -> Vector2i:
	"""The ordinal-th member's resident EntityRef, in persistent-ID order, or NULL_REF."""
	if household_ref(household).x == NULL_ROW or ordinal < 0 or ordinal >= MEMBERS_PER_HOUSEHOLD:
		return NULL_REF
	var index: int = household * MEMBERS_PER_HOUSEHOLD + ordinal
	return Vector2i(_h_member_slot[index], _h_member_generation[index])


func household_count() -> int:
	"""Present household rows, by a bounded 256 scan."""
	var count: int = 0
	for household: int in HOUSEHOLD_CAPACITY:
		count += _h_present[household]
	return count


func preferred_caregiver_ids_of(row: int) -> Vector2i:
	"""(first, second) preferred caregiver persistent IDs of a bound row; 0 means none."""
	if not is_bound(row):
		return Vector2i.ZERO
	return Vector2i(_d_preferred_0[row], _d_preferred_1[row])


func provider_of(row: int) -> Vector2i:
	"""The provider EntityRef serving a bound child row, or NULL_REF."""
	if not is_bound(row):
		return NULL_REF
	return Vector2i(_d_provider_slot[row], _d_provider_generation[row])


func service_paired_ticks_of(row: int) -> int:
	"""Actual paired ticks of a bound child's current service turn."""
	return _d_service_paired_ticks[row] if is_bound(row) else 0


func provider_served_ticks_today_of(row: int) -> int:
	"""Paired ticks a bound ADULT/ELDER has served today."""
	return _d_provider_served_ticks_today[row] if is_bound(row) else 0


func next_household_id() -> int:
	"""The next household ID to issue; NEXT_HOUSEHOLD_ID_TERMINAL once exhausted."""
	return _next_household_id


func served_day() -> int:
	"""The absolute day the provider daily shares count; 0 before the first day opens."""
	return _served_day


func payload_bytes() -> int:
	"""Bytes the packed columns plus the two i64 scalars occupy, re-derived from the columns."""
	var total: int = 16 + _h_present.size() + _d_care_remainder.size() * 8
	for column: PackedByteArray in [_d_present, _d_care_eligible, _d_warning_bits, _d_willing]:
		total += column.size()
	for column: PackedInt32Array in [_h_generation, _h_persistent_id, _h_member_count,
			_h_member_slot, _h_member_generation]:
		total += column.size() * 4
	for column: PackedInt32Array in _i32_resident_columns():
		total += column.size() * 4
	return total


# --- bulk columns: capture, pure validation, restore (FAMILY-STATE-R01 §Required APIs) ---------
#
# The STORE half of section 4/5. The §4 owner registration, ordinals, declaration hashes and the
# section 5 member arena codec are allocated by the implementation packet together with the family
# rules fingerprint (FAMILY-STATE-R01 §Save; gate 3, decision 0521) and do not exist yet, so
# nothing here writes wire bytes. What this does fix is the version rule: a column set declares
# OWNER_SCHEMA_VERSION and any other version refuses -- there is no pre-family migration.


class Columns:
	"""Caller-owned image of every household/dependent column and both scalars. One per load.

	The buffers belong to the CALLER; `copy_columns_into()` refills them in place and refuses a
	wrongly sized one rather than resizing it.
	"""
	var schema_version: int = OWNER_SCHEMA_VERSION
	var h_present: PackedByteArray = PackedByteArray()
	var h_generation: PackedInt32Array = PackedInt32Array()
	var h_persistent_id: PackedInt32Array = PackedInt32Array()
	var h_member_count: PackedInt32Array = PackedInt32Array()
	var h_member_slot: PackedInt32Array = PackedInt32Array()
	var h_member_generation: PackedInt32Array = PackedInt32Array()
	var next_household_id: int = NEXT_HOUSEHOLD_ID_INITIAL
	var d_present: PackedByteArray = PackedByteArray()
	var d_care_eligible: PackedByteArray = PackedByteArray()
	var d_warning_bits: PackedByteArray = PackedByteArray()
	var d_willing: PackedByteArray = PackedByteArray()
	var d_resident_slot: PackedInt32Array = PackedInt32Array()
	var d_resident_generation: PackedInt32Array = PackedInt32Array()
	var d_household_row: PackedInt32Array = PackedInt32Array()
	var d_household_generation: PackedInt32Array = PackedInt32Array()
	var d_preferred_0: PackedInt32Array = PackedInt32Array()
	var d_preferred_1: PackedInt32Array = PackedInt32Array()
	var d_care: PackedInt32Array = PackedInt32Array()
	var d_care_remainder: PackedInt64Array = PackedInt64Array()
	var d_provider_slot: PackedInt32Array = PackedInt32Array()
	var d_provider_generation: PackedInt32Array = PackedInt32Array()
	var d_service_paired_ticks: PackedInt32Array = PackedInt32Array()
	var d_provider_served_ticks_today: PackedInt32Array = PackedInt32Array()
	var served_day: int = FIRST_WORLD_DAY

	func _init() -> void:
		"""Size every column to its declared extent. The only place this class resizes."""
		h_present.resize(HOUSEHOLD_CAPACITY)
		for column: PackedInt32Array in [h_generation, h_persistent_id, h_member_count]:
			column.resize(HOUSEHOLD_CAPACITY)
		h_member_slot.resize(MEMBER_CAPACITY)
		h_member_generation.resize(MEMBER_CAPACITY)
		for column: PackedByteArray in [d_present, d_care_eligible, d_warning_bits, d_willing]:
			column.resize(RESIDENT_CAPACITY)
		for column: PackedInt32Array in i32_resident_columns():
			column.resize(RESIDENT_CAPACITY)
		d_care_remainder.resize(RESIDENT_CAPACITY)
		h_member_slot.fill(NULL_SLOT)
		d_resident_slot.fill(NULL_SLOT)
		d_household_row.fill(NULL_ROW)
		d_provider_slot.fill(NULL_SLOT)

	func i32_resident_columns() -> Array[PackedInt32Array]:
		"""The eleven 512-row int32 columns, in declaration order."""
		return [d_resident_slot, d_resident_generation, d_household_row, d_household_generation,
			d_preferred_0, d_preferred_1, d_care, d_provider_slot, d_provider_generation,
			d_service_paired_ticks, d_provider_served_ticks_today]


static func _columns_shaped(c: Columns) -> bool:
	"""True when a non-null image holds every buffer at exactly its declared extent."""
	if c == null or c.h_present.size() != HOUSEHOLD_CAPACITY:
		return false
	for column: PackedInt32Array in [c.h_generation, c.h_persistent_id, c.h_member_count]:
		if column.size() != HOUSEHOLD_CAPACITY:
			return false
	if c.h_member_slot.size() != MEMBER_CAPACITY or c.h_member_generation.size() != MEMBER_CAPACITY:
		return false
	for column: PackedByteArray in [c.d_present, c.d_care_eligible, c.d_warning_bits, c.d_willing]:
		if column.size() != RESIDENT_CAPACITY:
			return false
	for column: PackedInt32Array in c.i32_resident_columns():
		if column.size() != RESIDENT_CAPACITY:
			return false
	return c.d_care_remainder.size() == RESIDENT_CAPACITY


static func _copy_bytes(dst: PackedByteArray, src: PackedByteArray) -> void:
	"""Element copy into an existing, equally sized buffer: no allocation, no resize."""
	for index: int in src.size():
		dst[index] = src[index]


static func _copy_i32(dst: PackedInt32Array, src: PackedInt32Array) -> void:
	"""Element copy into an existing, equally sized buffer: no allocation, no resize."""
	for index: int in src.size():
		dst[index] = src[index]


static func _copy_i64(dst: PackedInt64Array, src: PackedInt64Array) -> void:
	"""Element copy into an existing, equally sized buffer: no allocation, no resize."""
	for index: int in src.size():
		dst[index] = src[index]


func copy_columns_into(out: Columns) -> bool:
	"""Capture every column into a caller-owned image. False, leaving `out` unchanged, on shape."""
	if not _columns_shaped(out):
		return false
	out.schema_version = OWNER_SCHEMA_VERSION
	_copy_bytes(out.h_present, _h_present)
	_copy_i32(out.h_generation, _h_generation)
	_copy_i32(out.h_persistent_id, _h_persistent_id)
	_copy_i32(out.h_member_count, _h_member_count)
	_copy_i32(out.h_member_slot, _h_member_slot)
	_copy_i32(out.h_member_generation, _h_member_generation)
	out.next_household_id = _next_household_id
	_copy_bytes(out.d_present, _d_present)
	_copy_bytes(out.d_care_eligible, _d_care_eligible)
	_copy_bytes(out.d_warning_bits, _d_warning_bits)
	_copy_bytes(out.d_willing, _d_willing)
	var mine: Array[PackedInt32Array] = _i32_resident_columns()
	var theirs: Array[PackedInt32Array] = out.i32_resident_columns()
	for index: int in mine.size():
		_copy_i32(theirs[index], mine[index])
	_copy_i64(out.d_care_remainder, _d_care_remainder)
	out.served_day = _served_day
	return true


func _i32_resident_columns() -> Array[PackedInt32Array]:
	"""This store's eleven 512-row int32 columns, in the same order as Columns'."""
	return [_d_resident_slot, _d_resident_generation, _d_household_row, _d_household_generation,
		_d_preferred_0, _d_preferred_1, _d_care, _d_provider_slot, _d_provider_generation,
		_d_service_paired_ticks, _d_provider_served_ticks_today]


func restore_columns_into(candidate: Columns, clock: SimClockScript,
		out: IntMath.IntResult) -> bool:
	"""Validate a whole image against the bound Residents and install it. Value: households.

	Requires the clock's load barrier to be HELD (it is read, never moved) and takes the world
	day from the clock. Every rule is checked before the first write; the image is copied into
	the existing buffers, and no second staging copy is made. Neither releases the barrier nor
	publishes the world.
	"""
	if clock == null or not clock.is_load_barrier_held():
		return out.refuse(REFUSE_LOAD_BARRIER)
	clock.calendar_into(_calendar)
	var refusal: String = columns_refusal(candidate, _residents, _calendar.absolute_day)
	if refusal != REFUSE_NONE:
		return out.refuse(refusal)
	_install(candidate)
	return out.succeed(household_count())


func _install(c: Columns) -> void:
	"""Copy a validated image into the live buffers and scalars."""
	_copy_bytes(_h_present, c.h_present)
	_copy_i32(_h_generation, c.h_generation)
	_copy_i32(_h_persistent_id, c.h_persistent_id)
	_copy_i32(_h_member_count, c.h_member_count)
	_copy_i32(_h_member_slot, c.h_member_slot)
	_copy_i32(_h_member_generation, c.h_member_generation)
	_next_household_id = c.next_household_id
	_copy_bytes(_d_present, c.d_present)
	_copy_bytes(_d_care_eligible, c.d_care_eligible)
	_copy_bytes(_d_warning_bits, c.d_warning_bits)
	_copy_bytes(_d_willing, c.d_willing)
	var mine: Array[PackedInt32Array] = _i32_resident_columns()
	var theirs: Array[PackedInt32Array] = c.i32_resident_columns()
	for index: int in mine.size():
		_copy_i32(mine[index], theirs[index])
	_copy_i64(_d_care_remainder, c.d_care_remainder)
	_served_day = c.served_day


static func columns_refusal(c: Columns, residents: ResidentsScript, world_day: int) -> String:
	"""Pure validation of a whole image against a Residents store and a world day. "" accepts.

	Lengths, schema version, scalar ranges, every canonical unused value, unique household IDs,
	ascending living members, two-sided membership, the resident binding's whole EntityRef,
	stage restrictions, care/remainder/latch consistency, preferences and provider references
	and their uniqueness. Mutates nothing.
	"""
	if not _columns_shaped(c) or residents == null:
		return REFUSE_COLUMN_SHAPE
	if c.schema_version != OWNER_SCHEMA_VERSION:
		return REFUSE_COLUMN_SCHEMA
	if c.next_household_id < NEXT_HOUSEHOLD_ID_INITIAL \
			or c.next_household_id > NEXT_HOUSEHOLD_ID_TERMINAL:
		return REFUSE_COLUMN_NEXT_ID
	if c.served_day != world_day:
		return REFUSE_COLUMN_SERVED_DAY
	var refusal: String = _household_rows_refusal(c, residents)
	if refusal != REFUSE_NONE:
		return refusal
	var pids: PackedInt64Array = _persistent_id_index(residents)
	for row: int in RESIDENT_CAPACITY:
		refusal = _dependent_row_refusal(c, residents, pids, row)
		if refusal != REFUSE_NONE:
			return refusal
	return _cross_row_refusal(c)


static func _static_row_of_ref(residents: ResidentsScript, ref: Vector2i) -> int:
	"""Typed row of a live resident ref present in `residents`, or NULL_ROW."""
	var directory: EntityDirectory = residents.directory()
	if not directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESIDENT):
		return NULL_ROW
	var row: int = directory.get_typed_row(ref)
	return row if residents.is_present(row) else NULL_ROW


static func _persistent_id_index(residents: ResidentsScript) -> PackedInt64Array:
	"""Sorted (persistent_id << 9 | row) keys of every present resident. Cold-path scratch."""
	var keys: PackedInt64Array = PackedInt64Array()
	for row: int in RESIDENT_CAPACITY:
		if residents.is_present(row):
			var pid: int = residents.directory().get_persistent_id(residents.ref_of(row))
			keys.append((pid << 9) | row)
	keys.sort()
	return keys


static func _row_of_persistent_id(keys: PackedInt64Array, pid: int) -> int:
	"""Row of a present resident by persistent ID, or NULL_ROW."""
	var at: int = keys.bsearch(pid << 9)
	if at >= keys.size() or (keys[at] >> 9) != pid:
		return NULL_ROW
	return keys[at] & 511


static func _household_rows_refusal(c: Columns, residents: ResidentsScript) -> String:
	"""Every household row: domains, unused values, IDs below the cursor and unique, members."""
	var ids: PackedInt64Array = PackedInt64Array()
	for household: int in HOUSEHOLD_CAPACITY:
		var refusal: String = _household_row_refusal(c, residents, household)
		if refusal != REFUSE_NONE:
			return refusal
		if c.h_present[household] == 1:
			ids.append(c.h_persistent_id[household])
	ids.sort()
	for index: int in range(1, ids.size()):
		if ids[index] == ids[index - 1]:
			return REFUSE_COLUMN_HOUSEHOLD_ID
	return REFUSE_NONE


static func _household_row_refusal(c: Columns, residents: ResidentsScript,
		household: int) -> String:
	"""One household row. A free row keeps any generation and holds no ID, count or member."""
	if c.h_present[household] > 1 or c.h_generation[household] < 0:
		return REFUSE_COLUMN_HOUSEHOLD_ROW
	var base: int = household * MEMBERS_PER_HOUSEHOLD
	if c.h_present[household] == 0:
		if c.h_persistent_id[household] != 0 or c.h_member_count[household] != 0:
			return REFUSE_COLUMN_UNUSED
		for ordinal: int in MEMBERS_PER_HOUSEHOLD:
			if c.h_member_slot[base + ordinal] != NULL_SLOT \
					or c.h_member_generation[base + ordinal] != NULL_GENERATION:
				return REFUSE_COLUMN_UNUSED
		return REFUSE_NONE
	if c.h_generation[household] == 0:
		return REFUSE_COLUMN_HOUSEHOLD_ROW
	var pid: int = c.h_persistent_id[household]
	if pid < 1 or pid >= c.next_household_id:
		return REFUSE_COLUMN_HOUSEHOLD_ID
	var count: int = c.h_member_count[household]
	if count < 1 or count > MEMBERS_PER_HOUSEHOLD:
		return REFUSE_COLUMN_MEMBER
	return _members_refusal(c, residents, household)


static func _members_refusal(c: Columns, residents: ResidentsScript, household: int) -> String:
	"""Members: living residents in strictly ascending persistent ID, pointing back; null tail.

	The back-reference's GENERATION is checked once, per dependent row, by
	`_household_ref_refusal()`; checking it here as well made each copy unobservable.
	"""
	var base: int = household * MEMBERS_PER_HOUSEHOLD
	var previous: int = 0
	for ordinal: int in MEMBERS_PER_HOUSEHOLD:
		var ref: Vector2i = Vector2i(c.h_member_slot[base + ordinal],
			c.h_member_generation[base + ordinal])
		if ordinal >= c.h_member_count[household]:
			if ref != NULL_REF:
				return REFUSE_COLUMN_UNUSED
			continue
		var row: int = _static_row_of_ref(residents, ref)
		if row == NULL_ROW or not residents.is_alive(row):
			return REFUSE_COLUMN_MEMBER
		var pid: int = residents.directory().get_persistent_id(ref)
		if pid <= previous:
			return REFUSE_COLUMN_MEMBER
		previous = pid
		if c.d_present[row] != 1 or c.d_household_row[row] != household:
			return REFUSE_COLUMN_RECIPROCITY
	return REFUSE_NONE


static func _dependent_row_refusal(c: Columns, residents: ResidentsScript,
		pids: PackedInt64Array, row: int) -> String:
	"""One dependent row: binding, unused values, byte domains, stage rules, household ref."""
	if c.d_present[row] > 1 or residents.is_present(row) != (c.d_present[row] == 1):
		return REFUSE_COLUMN_BINDING
	if c.d_present[row] == 0:
		return REFUSE_NONE if _dependent_row_unused(c, row) else REFUSE_COLUMN_UNUSED
	if Vector2i(c.d_resident_slot[row], c.d_resident_generation[row]) != residents.ref_of(row):
		return REFUSE_COLUMN_BINDING
	if c.d_care_eligible[row] > 1 or c.d_willing[row] > 1:
		return REFUSE_COLUMN_LATCH
	var bits: int = c.d_warning_bits[row]
	if bits != 0 and bits != WARNING_LOW and bits != (WARNING_LOW | WARNING_CRITICAL):
		return REFUSE_COLUMN_LATCH
	var refusal: String = _household_ref_refusal(c, row)
	if refusal != REFUSE_NONE:
		return refusal
	if residents.life_stage_code_of(row) == STAGE_CHILD:
		return _child_row_refusal(c, residents, pids, row)
	return _provider_row_refusal(c, row)


static func _dependent_row_unused(c: Columns, row: int) -> bool:
	"""True when an unbound row holds FAMILY-STATE-R01's canonical unused value everywhere."""
	return c.d_care_eligible[row] == 0 and c.d_warning_bits[row] == 0 and c.d_willing[row] == 0 \
		and c.d_resident_slot[row] == NULL_SLOT \
		and c.d_resident_generation[row] == NULL_GENERATION \
		and c.d_household_row[row] == NULL_ROW and c.d_household_generation[row] == 0 \
		and c.d_preferred_0[row] == 0 and c.d_preferred_1[row] == 0 and c.d_care[row] == 0 \
		and c.d_care_remainder[row] == 0 and c.d_provider_slot[row] == NULL_SLOT \
		and c.d_provider_generation[row] == NULL_GENERATION \
		and c.d_service_paired_ticks[row] == 0 and c.d_provider_served_ticks_today[row] == 0


static func _household_ref_refusal(c: Columns, row: int) -> String:
	"""A household ref is null (-1, 0) or names a present household at its generation."""
	var household: int = c.d_household_row[row]
	if household == NULL_ROW:
		return REFUSE_NONE if c.d_household_generation[row] == 0 else REFUSE_COLUMN_RECIPROCITY
	if household < 0 or household >= HOUSEHOLD_CAPACITY or c.h_present[household] != 1 \
			or c.d_household_generation[row] != c.h_generation[household]:
		return REFUSE_COLUMN_RECIPROCITY
	return REFUSE_NONE


static func _provider_row_refusal(c: Columns, row: int) -> String:
	"""ADULT/ELDER: no care state, no preferences, no patient; a daily share of 0..18000."""
	if c.d_care[row] != 0 or c.d_care_remainder[row] != 0 or c.d_care_eligible[row] != 0 \
			or c.d_warning_bits[row] != 0 or c.d_preferred_0[row] != 0 \
			or c.d_preferred_1[row] != 0 or c.d_provider_slot[row] != NULL_SLOT \
			or c.d_provider_generation[row] != NULL_GENERATION \
			or c.d_service_paired_ticks[row] != 0:
		return REFUSE_COLUMN_STAGE
	var served: int = c.d_provider_served_ticks_today[row]
	if served < 0 or served > PROVIDER_SERVED_TICKS_MAX:
		return REFUSE_COLUMN_PROVIDER
	return REFUSE_NONE


static func _child_row_refusal(c: Columns, residents: ResidentsScript,
		pids: PackedInt64Array, row: int) -> String:
	"""CHILD: unwilling with no daily share; care, latches, preferences and provider valid."""
	if c.d_willing[row] != 0 or c.d_provider_served_ticks_today[row] != 0:
		return REFUSE_COLUMN_STAGE
	var refusal: String = _care_refusal(c.d_care[row], c.d_care_remainder[row])
	if refusal == REFUSE_NONE:
		refusal = _latch_refusal(c.d_care[row], c.d_warning_bits[row], c.d_care_eligible[row])
	if refusal == REFUSE_NONE:
		refusal = _preference_refusal(c, residents, pids, row)
	if refusal == REFUSE_NONE:
		refusal = _child_provider_refusal(c, residents, row)
	return refusal


static func _care_refusal(care: int, remainder: int) -> String:
	"""Care 0..10000, |remainder| < 750000, and no outward remainder at a reached bound."""
	if care < CARE_MIN or care > CARE_MAX:
		return REFUSE_COLUMN_CARE
	if remainder >= CARE_DENOMINATOR or remainder <= -CARE_DENOMINATOR:
		return REFUSE_COLUMN_CARE
	if (care == CARE_MAX and remainder > 0) or (care == CARE_MIN and remainder < 0):
		return REFUSE_COLUMN_CARE
	return REFUSE_NONE


static func _latch_refusal(care: int, bits: int, eligible: int) -> String:
	"""Each latch must be a state its own hysteresis rule can leave at this care value."""
	var critical: bool = (bits & WARNING_CRITICAL) != 0
	var low: bool = (bits & WARNING_LOW) != 0
	if (critical and care > CARE_CRITICAL_CLEAR_ABOVE) \
			or (not critical and care <= CARE_CRITICAL_SET_AT_OR_BELOW):
		return REFUSE_COLUMN_LATCH
	if (low and care > CARE_LOW_CLEAR_ABOVE) or (not low and care <= CARE_LOW_SET_AT_OR_BELOW):
		return REFUSE_COLUMN_LATCH
	if eligible == 1 and care >= CARE_ELIGIBLE_CLEAR_AT_OR_ABOVE:
		return REFUSE_COLUMN_LATCH
	if eligible == 0 and care <= CARE_ELIGIBLE_SET_AT_OR_BELOW:
		return REFUSE_COLUMN_LATCH
	return REFUSE_NONE


static func _preference_refusal(c: Columns, residents: ResidentsScript,
		pids: PackedInt64Array, row: int) -> String:
	"""Two ascending persistent IDs, 0 only at the end, each a living bound ADULT/ELDER."""
	var first: int = c.d_preferred_0[row]
	var second: int = c.d_preferred_1[row]
	if first < 0 or second < 0 or (first == 0 and second != 0) or (second != 0 and second <= first):
		return REFUSE_COLUMN_PREFERENCE
	if (first != 0 or second != 0) and not residents.is_alive(row):
		return REFUSE_COLUMN_PREFERENCE
	for pid: int in [first, second]:
		if pid == 0:
			continue
		var named: int = _row_of_persistent_id(pids, pid)
		if named == NULL_ROW or not residents.is_alive(named) or c.d_present[named] != 1:
			return REFUSE_COLUMN_PREFERENCE
		if residents.life_stage_code_of(named) == STAGE_CHILD:
			return REFUSE_COLUMN_PREFERENCE
	return REFUSE_NONE


static func _child_provider_refusal(c: Columns, residents: ResidentsScript, row: int) -> String:
	"""A served child is living and eligible, its provider a living bound ADULT/ELDER, 0..749."""
	var ref: Vector2i = Vector2i(c.d_provider_slot[row], c.d_provider_generation[row])
	var session: int = c.d_service_paired_ticks[row]
	if ref == NULL_REF:
		return REFUSE_NONE if session == 0 else REFUSE_COLUMN_PROVIDER
	if session < 0 or session >= SERVICE_TURN_TICKS:
		return REFUSE_COLUMN_PROVIDER
	if not residents.is_alive(row) or c.d_care_eligible[row] != 1:
		return REFUSE_COLUMN_PROVIDER
	var provider: int = _static_row_of_ref(residents, ref)
	if provider == NULL_ROW or not residents.is_alive(provider) or c.d_present[provider] != 1:
		return REFUSE_COLUMN_PROVIDER
	if residents.life_stage_code_of(provider) == STAGE_CHILD:
		return REFUSE_COLUMN_PROVIDER
	return REFUSE_NONE


static func _cross_row_refusal(c: Columns) -> String:
	"""Each household's referencing rows number exactly its member count; providers are unique."""
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(HOUSEHOLD_CAPACITY)
	var providers: PackedInt64Array = PackedInt64Array()
	for row: int in RESIDENT_CAPACITY:
		if c.d_present[row] == 1 and c.d_household_row[row] != NULL_ROW:
			counts[c.d_household_row[row]] += 1
		if c.d_present[row] == 1 and c.d_provider_slot[row] != NULL_SLOT:
			providers.append(c.d_provider_slot[row])
	for household: int in HOUSEHOLD_CAPACITY:
		if c.h_present[household] == 1 and counts[household] != c.h_member_count[household]:
			return REFUSE_COLUMN_RECIPROCITY
	providers.sort()
	for index: int in range(1, providers.size()):
		if providers[index] == providers[index - 1]:
			return REFUSE_COLUMN_PROVIDER
	return REFUSE_NONE


func state_bytes() -> PackedByteArray:
	"""Diagnostic image of every column and scalar. Allocates; NOT a production call."""
	var image: PackedByteArray = PackedByteArray()
	for column: PackedByteArray in [_h_present, _d_present, _d_care_eligible, _d_warning_bits,
			_d_willing]:
		image.append_array(column)
	for column: PackedInt32Array in [_h_generation, _h_persistent_id, _h_member_count,
			_h_member_slot, _h_member_generation]:
		image.append_array(column.to_byte_array())
	for column: PackedInt32Array in _i32_resident_columns():
		image.append_array(column.to_byte_array())
	image.append_array(_d_care_remainder.to_byte_array())
	image.append_array(PackedInt64Array([_next_household_id, _served_day]).to_byte_array())
	return image
