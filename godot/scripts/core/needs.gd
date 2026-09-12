extends RefCounted
## Resident needs, health, cold exposure, and mood: the GDD §5.2 integration core.
##
## GDD §4.2 fixes the two row shapes this module owns, plus the part of a third:
##   Needs:                hunger/rest/comfort/social/purpose: int32, health: int32,
##                         cold_hours: int32, starving_hours: int32, departure_days: int32
##   NeedRemainders:       hunger/rest/comfort/social/purpose: int64
##   IntegrationRemainders: health/cold: int64 and cold_milli_hours: int64 (the work/xp/
##                         food_effect fields of that row belong to labour and meals and are
##                         NOT part of this slice; see the GAPS block below).
## Needs are 0-10000, health is 0-100, and one row exists per resident. Rows are indexed by
## the RESIDENT typed row that entity_directory.gd allocates, so this module never allocates
## slots of its own -- it sizes its columns to that store's capacity and nothing else.
##
## INTEGER ONLY. There is no float anywhere in this file. Need values, need rates, health,
## cold exposure, mood and every factor are exact integers; a rational rate is carried as a
## retained integer remainder, never as an accumulated fraction.
##
## ---------------------------------------------------------------------------------------
## THE INTEGRATION RULE (GDD §5.2, BAL-NUM-001). This is the whole point of the module.
##
##   "Need integration uses exact integer remainders: for hourly rate R scaled in 1/1000
##    need-point units, each tick add R to accumulator, extract trunc(accumulator/750000),
##    retain remainder. Compound multipliers are applied in int64 before division. Clamp
##    final needs 0-10000 and discard positive overflow/remainder when a need reaches 10000."
##   "At an upper/lower need bound discard only the remainder that would push farther outside
##    the bound." (BAL-NUM-001)
##   "Need caps discard overflow of either sign at the relevant bound." (GDD §5.2)
##
## So one tick of one column is exactly:
##   accumulator += rate                       # rate in milli-need-points per GAME HOUR
##   whole        = trunc(accumulator / D)     # D = 750 ticks/hour * 1000 milli = 750000
##   accumulator -= whole * D                  # retained, signed, |accumulator| < D
##   value        = clamp(value + whole, lo, hi)
##   if value == hi and accumulator > 0:  accumulator = 0    # discard only what pushes out
##   if value == lo and accumulator < 0:  accumulator = 0
##
## `trunc` is truncation toward zero, so the same code integrates decay and restoration; the
## retained remainder is signed and may change sign when a resident wakes, is fed, or moves
## indoors. Nothing is ever rounded away: over any number of ticks T at a constant rate R the
## released total is exactly trunc(T*R/D), which is what test_needs.gd asserts over 75000-tick
## runs against closed-form integer arithmetic.
##
## _integrate_step() is the single implementation. Health and cold exposure reuse it with
## their own denominators (GDD §4.2: "health uses 750-tick hourly denominator, cold uses
## milli-hours"), so there is one integrator in the codebase, not three near-copies.
##
## ---------------------------------------------------------------------------------------
## WHY NOT IntMath.RemainderAccumulator. int_math.gd's accumulator is reused for the checked
## arithmetic underneath, but not as the storage:
##   1. It refuses a negative step, and every need rate here is signed -- decay is the normal
##      case and restoration is the exception.
##   2. It holds its remainder inside a RefCounted instance. One per resident per column is
##      512*7 = 3584 objects and a per-resident Array to reach them, which ARCH-MEM-001
##      forbids outright. The remainders live in packed int64 columns instead.
## Its checked primitives ARE used, always in their non-allocating `_into` forms:
## checked_add_into() on the per-tick path in _integrate_step(), and checked_mul_into() /
## floor_div_into() for the compound size-and-season multiplication, the milli-hour readers,
## and the mood and work factors. The work-facing readers also publish caller-owned `_into`
## forms; their allocating wrappers stay available for retained and cold-path results.
## work_factor_for_resident_into() fuses the three of them a work tick calls per resident into
## one call that validates the row once (decision 0024 section 4). It is a call-count
## reduction and NOT A CACHE: it retains nothing, holds no dirty flag, adds no invalidation
## rule, and observes exactly the tick's own column values. See
## _integrate_step() for why exactly one of the four
## accumulator operations still needs a runtime check and what is proven about the other
## three -- the answer is a bound with three explicit refusals guarding it, not an assumption.
##
## ---------------------------------------------------------------------------------------
## ARCH-MEM-001/005: every column is a packed array allocated once in _init(). No GDScript
## Array is allocated per resident, and resize() is called only by _allocate_columns();
## clear() refills the existing buffers. tick_all() allocates exactly one OpResult for the
## whole sweep, and per-resident integration allocates nothing at all.
##
## REFUSAL, NOT SENTINELS (finding H4, and the lot_debit_g overflow). Every mutator returns an
## OpResult whose `.ok` must be inspected; every reader returns an IntMath.IntResult whose
## `.ok` must be inspected. A refusal never returns a plausible-looking number in the value
## channel: IntResult.refuse() zeroes the value and _result() builds a refusal carrying 0. No
## reader here answers an out-of-range slot with a default.
##
## ---------------------------------------------------------------------------------------
## ENVIRONMENT INPUTS THAT DO NOT EXIST YET. §5.2's restoration rates are conditioned on
## rooms, beds, temperature, meals and labour -- none of which are implemented in this
## milestone. Nothing about them is invented here. Each is an explicit per-resident input
## column with a clearly-named unavailable default, set by whatever system eventually owns it:
##   activity            ACTIVITY_AWAKE (default) / SLEEP_BED / SLEEP_FLOOR      <- beds, schedule
##   comfort environment COMFORT_ENV_NONE (default) / HEATED_ROOM / MILD_OUTDOORS <- rooms, weather
##   social pairing      not paired (default)                                     <- social activity
##   purpose source      PURPOSE_SOURCE_NONE (default) / LABOR / MENTORING        <- jobs
##   cold environment    COLD_ENV_NEUTRAL (default) / EXPOSED / HEATED_SHELTER    <- rooms, weather
##   clothing tier       1 (GDD §5.1 spawn equipment)                             <- equipment
##   infirmary           false (default)                                          <- rooms
##   injury state        INJURY_NONE (default)                                    <- Injury component
##   winter / hard freeze  false (world-level, default)                           <- season, weather
## With every default in force a resident's hunger, comfort, social and purpose decay, rest
## decays while awake, cold neither accumulates nor clears, and health recovers under
## REQ-SET-017. That is the honest behaviour of an unfurnished world, not a placeholder rate.
##
## GAPS -- §5.2 clauses deliberately NOT implemented here, and why:
##   * MoodMemory storage (up to 8 entries/resident, refresh-not-stack, eviction by smallest
##     absolute value). Blocker U6 records that its owner-major index formula is unspecified.
##     The catalog VALUES and DURATIONS are published below because §5.2 states them
##     literally; mood_of() takes the active-memory total as an explicit argument.
##   * Departure (REQ-SET-021..024) and the `departure_days` column. It needs day boundaries,
##     a complete mood (i.e. the deferred MoodMemory store) and a map exit; marking residents
##     for departure off a structurally incomplete mood would be worse than not doing it. The
##     column exists, is explicitly zero, and is never written -- the FaunaStockReserved
##     pattern from GDD §4.2.
##   * Meal quality factors, NP-per-portion and the food/feast cold reductions (§5.7). Callers
##     pass already-resolved nutrition points to add_food_nutrition().
##   * Per-tick work output (80 milli-WU x factor/1000) and XP: labour, not needs. work_factor()
##     publishes the §5.2 factor; the milli-WU accumulator is a later slice.
##   * Injury damage rates (REQ-SET-172, §5.11) and treatment. Injury presence reaches this
##     module only as the INJURY_* input that §5.2 itself uses.
##   * REQ-SET-016 death consequences beyond recording the death: releasing reservations, the
##     chronicle entry, the burial job and recoverable inventory are other modules' work.
##
## Promoted from the verified `docs/validation/headless/winter_world.gd` control kernel, which
## stays byte-unchanged. Divergences from it are marked `DIVERGENCE:` at each site.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

# --- capacities ----------------------------------------------------------------------------

## Rows, one per RESIDENT typed row. _init() asserts this equals the directory's own capacity
## for KIND_RESIDENT rather than duplicating it as an independent number.
const RESIDENT_CAPACITY: int = 512
## Living residents never exceed this (GDD §4.1); mirrors EntityDirectory.RESIDENT_LIVING_CAP.
const RESIDENT_LIVING_CAP: int = 256

# --- fixed-step constants (GDD §5.1 REQ-SET-006) -------------------------------------------

const TICKS_PER_HOUR: int = 750
## Milli-need-points per need point. Rates are quoted per game hour in these units.
const MILLI_PER_POINT: int = 1000
## The §5.2 need denominator: 750 ticks/hour * 1000 milli = 750000.
const NEED_DENOMINATOR: int = TICKS_PER_HOUR * MILLI_PER_POINT
## GDD §4.2: "health uses 750-tick hourly denominator". Health rates are whole points/hour.
const HEALTH_DENOMINATOR: int = TICKS_PER_HOUR
## GDD §5.2: "cold_milli_hours stores 1000 per exposure-hour". Rates are milli-hours/hour.
const COLD_DENOMINATOR: int = TICKS_PER_HOUR
## GDD §5.2: cold_hours is the floor/1000 display value of cold_milli_hours.
const COLD_MILLI_PER_HOUR_UNIT: int = 1000

# --- need identity (GDD §4.2 field order) --------------------------------------------------

const NEED_HUNGER: int = 0
const NEED_REST: int = 1
const NEED_COMFORT: int = 2
const NEED_SOCIAL: int = 3
const NEED_PURPOSE: int = 4
const NEED_COUNT: int = 5
const NEED_KEYS: Array[StringName] = [&"hunger", &"rest", &"comfort", &"social", &"purpose"]

const NEED_MIN: int = 0
const NEED_MAX: int = 10000
const HEALTH_MIN: int = 0
const HEALTH_MAX: int = 100

## GDD §5.1 initialization contract: all five needs 7500, health 100.
const INITIAL_NEED_VALUE: int = 7500
const INITIAL_HEALTH: int = 100

# --- baseline decay, per game hour, in milli-need-points (GDD §5.2 table) -------------------

## Hunger 250/hour before the size and winter multipliers.
const HUNGER_DECAY_MILLI_PER_HOUR: int = 250 * MILLI_PER_POINT
## Rest 375/hour WHILE AWAKE; §5.2 states there is no awake decay while asleep.
const REST_DECAY_MILLI_PER_HOUR: int = 375 * MILLI_PER_POINT
const COMFORT_DECAY_MILLI_PER_HOUR: int = 100 * MILLI_PER_POINT
const SOCIAL_DECAY_MILLI_PER_HOUR: int = 100 * MILLI_PER_POINT
const PURPOSE_DECAY_MILLI_PER_HOUR: int = 75 * MILLI_PER_POINT

# --- restoration, per game hour, in milli-need-points (GDD §5.2 table) ----------------------

const REST_RESTORE_BED_MILLI_PER_HOUR: int = 1200 * MILLI_PER_POINT
const REST_RESTORE_FLOOR_MILLI_PER_HOUR: int = 750 * MILLI_PER_POINT
const COMFORT_RESTORE_HEATED_ROOM_MILLI_PER_HOUR: int = 300 * MILLI_PER_POINT
const COMFORT_RESTORE_MILD_OUTDOORS_MILLI_PER_HOUR: int = 100 * MILLI_PER_POINT
const SOCIAL_RESTORE_PAIRED_MILLI_PER_HOUR: int = 1200 * MILLI_PER_POINT
const PURPOSE_RESTORE_LABOR_MILLI_PER_HOUR: int = 320 * MILLI_PER_POINT
const PURPOSE_RESTORE_MENTORING_MILLI_PER_HOUR: int = 400 * MILLI_PER_POINT
## "dining+200 per shared meal" -- an event, not a rate.
const SOCIAL_SHARED_MEAL_POINTS: int = 200

## Largest magnitude any rate reaching _integrate_step() may have, in that column's own
## sub-unit per game hour. Every need rate below is within it (the largest is rest-in-bed at
## 1200000), as is every cold rate (at most 2000 milli-hours/hour) and health rate (at most
## 11 points/hour). _check_rate_bounds() proves the need rates at construction rather than
## trusting the reading, and _integrate_step() REFUSES a rate outside it rather than
## integrating something it has no overflow proof for.
const MAX_RATE_MAGNITUDE: int = 1200 * MILLI_PER_POINT

# --- thresholds (GDD §5.2 table and REQ-SET-012..015) --------------------------------------

## Hunger: "Eat<=3500; urgent<=1500; starving=0".
const HUNGER_EAT_THRESHOLD: int = 3500
const HUNGER_URGENT_THRESHOLD: int = 1500
const HUNGER_STARVING_VALUE: int = 0
## Rest: "Seek sleep<=2500; collapse<=500", and REQ-SET-015 clears hazardous work at 4000.
const REST_SEEK_SLEEP_THRESHOLD: int = 2500
const REST_COLLAPSE_THRESHOLD: int = 500
const REST_HAZARD_CLEAR_THRESHOLD: int = 4000
## Comfort: "Low<3000; content>=6000" -- strict below, inclusive above, as written.
const COMFORT_LOW_THRESHOLD: int = 3000
const COMFORT_CONTENT_THRESHOLD: int = 6000
## Social: "Lonely<2500". Purpose: "Aimless<2500". Both strict.
const SOCIAL_LONELY_THRESHOLD: int = 2500
const PURPOSE_AIMLESS_THRESHOLD: int = 2500

# --- size and season multipliers (GDD §5.2) -------------------------------------------------

const SIZE_SMALL: int = 0
const SIZE_MEDIUM: int = 1
const SIZE_LARGE: int = 2
const SIZE_COUNT: int = 3
## "Small size multiplier 1000, medium 1200, large 1600, denominator 1000."
const SIZE_MULTIPLIER: Array[int] = [1000, 1200, 1600]
const SIZE_DENOMINATOR: int = 1000
## REQ-SET-143 / §5.2 "winter x1.20", over the same 1000 denominator.
const WINTER_HUNGER_MULTIPLIER: int = 1200
const SEASON_DENOMINATOR: int = 1000

# --- health (REQ-SET-014, REQ-SET-017, REQ-SET-018) ----------------------------------------

## REQ-SET-014: "While hunger is 0 ... remove 4 health/hour".
const HEALTH_STARVATION_DRAIN_PER_HOUR: int = 4
## REQ-SET-018: "after 4 exposure hours it shall remove 3 health/hour".
const HEALTH_COLD_DRAIN_PER_HOUR: int = 3
## REQ-SET-017: "restore 2 health/hour, increased to 4/hour in an infirmary".
const HEALTH_RECOVERY_PER_HOUR: int = 2
const HEALTH_RECOVERY_INFIRMARY_PER_HOUR: int = 4
## REQ-SET-017 gate: hunger and rest must both be at least this to recover.
const HEALTH_RECOVERY_NEED_FLOOR: int = 4000

# --- cold exposure (REQ-SET-018/019, §5.2 closing paragraph, §5.10) ------------------------

## §5.2: base gain is 1 exposure-hour/hour for tier 1; §5.10: tier 2 removes the -5 C baseline.
const COLD_GAIN_TIER1_MILLI_PER_HOUR: int = 1000
const COLD_GAIN_TIER2_MILLI_PER_HOUR: int = 0
## §5.2: "In hard freeze, base cold gain is 2000 milli-hours/hour for tier 1 and 1000 for
## tier 2", matching §5.10's "outdoor exposure accumulation x2" and "hard freeze adds 1/hour
## even with that clothing".
const COLD_GAIN_HARD_FREEZE_TIER1_MILLI_PER_HOUR: int = 2000
const COLD_GAIN_HARD_FREEZE_TIER2_MILLI_PER_HOUR: int = 1000
## REQ-SET-019 / §5.2: "Clearing shelter remains 2000/hour".
const COLD_CLEAR_SHELTER_MILLI_PER_HOUR: int = 2000
## REQ-SET-018: exposure damage begins after this many whole exposure hours.
const COLD_DAMAGE_HOURS: int = 4
const CLOTHING_TIER_MIN: int = 1
const CLOTHING_TIER_MAX: int = 2

# --- mood (REQ-SET-020, GDD §5.2 formula) --------------------------------------------------

## Mood = clamp(floor((3*hunger+2*rest+2*comfort+social+2*purpose)/10) + memories, 0, 10000).
const MOOD_WEIGHT: Array[int] = [3, 2, 2, 1, 2]
const MOOD_DIVISOR: int = 10
const MOOD_MIN: int = 0
const MOOD_MAX: int = 10000

## Productivity factor bands, denominator 1000: <2000->600; 2000-3999->800; 4000-6999->1000;
## 7000-8499->1100; >=8500->1150.
const MOOD_FACTOR_DENOMINATOR: int = 1000
const MOOD_FACTOR_BAND_FLOOR: Array[int] = [2000, 4000, 7000, 8500]
const MOOD_FACTOR_VALUE: Array[int] = [600, 800, 1000, 1100, 1150]
## Health factor bands: <40->600; 40-69->850; >=70->1000.
const HEALTH_FACTOR_BAND_FLOOR: Array[int] = [40, 70]
const HEALTH_FACTOR_VALUE: Array[int] = [600, 850, 1000]
## Skill factor = 1000 + 50*level, levels 0..10 (GDD §5.3 caps skill level at 10).
const SKILL_FACTOR_BASE: int = 1000
const SKILL_FACTOR_PER_LEVEL: int = 50
const SKILL_LEVEL_MAX: int = 10
## total work factor = clamp(floor(skill*mood*health/1000000), 300, 1800).
const WORK_FACTOR_DIVISOR: int = 1000000
const WORK_FACTOR_MIN: int = 300
const WORK_FACTOR_MAX: int = 1800

# --- mood memory catalog (GDD §5.2) --------------------------------------------------------

## Keys in ascending ASCII order, per BAL-CAT-001. NO numeric IDs are published: §4.3 does not
## number this enum, so its members are catalog.gd's to compile. Callers look up by key.
const MEMORY_KEYS: Array[StringName] = [
	&"cold_home", &"conflict", &"excellent_meal", &"feast", &"friend_died", &"good_meal",
	&"milestone", &"monotonous_meal", &"rescued", &"stranger_died", &"untreated_injury",
]
## Mood value contributed by each key above, same order.
const MEMORY_VALUES: Array[int] = [-600, -600, 600, 1000, -1800, 300, 500, -400, 600, -300, -800]
## Duration in game hours, same order. untreated_injury has no hour count -- it lasts "until
## treated" -- so its entry is 0 and MEMORY_UNTIL_TREATED marks it; memory_duration_hours()
## REFUSES that key rather than handing back a 0 or a -1 that could be read as a duration.
const MEMORY_DURATION_HOURS: Array[int] = [12, 12, 8, 24, 72, 6, 24, 6, 48, 24, 0]
const MEMORY_UNTIL_TREATED: Array[bool] = [
	false, false, false, false, false, false, false, false, false, false, true,
]
## "at eight entries replace the smallest absolute value" -- the cap the deferred store needs.
const MEMORY_SLOTS_PER_RESIDENT: int = 8

# --- resident status (GDD §4.3 ResidentStatus, precedence in §5.2) --------------------------

const STATUS_ACTIVE: int = 0
const STATUS_RESTING: int = 1
const STATUS_INJURED: int = 2
const STATUS_INCAPACITATED: int = 3
const STATUS_LEAVING: int = 4
const STATUS_DEAD: int = 5
const STATUS_TRANSFERRED: int = 6
## "DEAD at health=0, INCAPACITATED at health=1..15". A treated resident wakes at health>=16.
const HEALTH_INCAPACITATED_MAX: int = 15

# --- environment inputs (module-local; NOT catalog enums) ----------------------------------

## Sleep location decides the rest rate. AWAKE is the unavailable-bed default.
const ACTIVITY_AWAKE: int = 0
const ACTIVITY_SLEEP_BED: int = 1
const ACTIVITY_SLEEP_FLOOR: int = 2
const ACTIVITY_COUNT: int = 3

## Comfort restoration source. NONE means neither a valid heated room nor mild outdoors.
const COMFORT_ENV_NONE: int = 0
const COMFORT_ENV_HEATED_ROOM: int = 1
const COMFORT_ENV_MILD_OUTDOORS: int = 2
const COMFORT_ENV_COUNT: int = 3

## Purpose restoration source (§5.2: completed useful labor, or mentoring).
const PURPOSE_SOURCE_NONE: int = 0
const PURPOSE_SOURCE_LABOR: int = 1
const PURPOSE_SOURCE_MENTORING: int = 2
const PURPOSE_SOURCE_COUNT: int = 3

## Cold environment. NEUTRAL is the unavailable-rooms default: neither exposed nor clearing.
const COLD_ENV_NEUTRAL: int = 0
const COLD_ENV_EXPOSED: int = 1
const COLD_ENV_HEATED_SHELTER: int = 2
const COLD_ENV_COUNT: int = 3

## Injury presence, as §5.2 itself uses it: for the INJURED status and the recovery gate.
## Mapping the Injury component's severity onto these is deferred with that component.
const INJURY_NONE: int = 0
const INJURY_ACTIVE: int = 1
const INJURY_UNTREATED_SERIOUS: int = 2
const INJURY_STATE_COUNT: int = 3

# --- refusal codes -------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
const REFUSE_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
const REFUSE_ALREADY_PRESENT: StringName = &"RESIDENT_ALREADY_PRESENT"
const REFUSE_RESIDENT_DEAD: StringName = &"RESIDENT_DEAD"
const REFUSE_LIVING_CAP: StringName = &"LIVING_CAP_RESIDENT"
const REFUSE_INVALID_SIZE: StringName = &"INVALID_SIZE_CLASS"
const REFUSE_INVALID_NEED: StringName = &"INVALID_NEED"
const REFUSE_INVALID_ACTIVITY: StringName = &"INVALID_ACTIVITY"
const REFUSE_INVALID_COMFORT_ENVIRONMENT: StringName = &"INVALID_COMFORT_ENVIRONMENT"
const REFUSE_INVALID_PURPOSE_SOURCE: StringName = &"INVALID_PURPOSE_SOURCE"
const REFUSE_INVALID_COLD_ENVIRONMENT: StringName = &"INVALID_COLD_ENVIRONMENT"
const REFUSE_INVALID_CLOTHING_TIER: StringName = &"INVALID_CLOTHING_TIER"
const REFUSE_INVALID_INJURY_STATE: StringName = &"INVALID_INJURY_STATE"
const REFUSE_INVALID_POINTS: StringName = &"INVALID_POINTS"
const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
const REFUSE_UNKNOWN_MEMORY: StringName = &"UNKNOWN_MEMORY_KEY"
const REFUSE_DURATION_CONDITIONAL: StringName = &"DURATION_CONDITIONAL"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
## _integrate_step() preconditions. Each one is a proof obligation for its overflow argument,
## so a violation refuses instead of integrating something unproven.
const REFUSE_RATE_OUT_OF_RANGE: StringName = &"RATE_OUT_OF_RANGE"
const REFUSE_INVALID_DENOMINATOR: StringName = &"INVALID_DENOMINATOR"
const REFUSE_REMAINDER_INVARIANT: StringName = &"REMAINDER_INVARIANT_BROKEN"


class OpResult:
	"""Outcome of one needs operation: success flag, refusal code, produced value.

	`.ok` MUST be inspected before `.value` is used. A refusal carries value 0 and never a
	partially applied effect: every mutator validates completely before it writes.
	"""
	var ok: bool
	var error: StringName
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value


# --- authoritative columns (ARCH-MEM-001: packed, allocated once) --------------------------

## Needs.hunger/rest/comfort/social/purpose, resident-major in a fixed 5-wide stripe:
## index = slot * NEED_COUNT + need. Five equal-length columns in one buffer, not an Array
## of arrays and not a per-resident Array.
var _need_value: PackedInt32Array = PackedInt32Array()
## NeedRemainders, the same stripe. Signed, |remainder| < NEED_DENOMINATOR at all times.
var _need_remainder: PackedInt64Array = PackedInt64Array()

var _health: PackedInt32Array = PackedInt32Array()
## IntegrationRemainders.health, denominator HEALTH_DENOMINATOR, signed.
var _health_remainder: PackedInt64Array = PackedInt64Array()

## IntegrationRemainders.cold_milli_hours: 1000 per exposure-hour (§5.2).
var _cold_milli_hours: PackedInt64Array = PackedInt64Array()
## IntegrationRemainders.cold, denominator COLD_DENOMINATOR, signed.
var _cold_remainder: PackedInt64Array = PackedInt64Array()

## Needs.starving_hours is exposed as a floor of this tick count, exactly as Needs.cold_hours
## is exposed as a floor of cold_milli_hours. Storing ticks makes the counter its own
## remainder, so REQ-SET-014's "one starving-hour counter/hour" needs no extra accumulator --
## GDD §4.2's IntegrationRemainders row does not provide one.
var _starving_ticks: PackedInt64Array = PackedInt64Array()

## Needs.departure_days. Reserved and explicitly zero: see the GAPS block in the header.
var _departure_days: PackedInt32Array = PackedInt32Array()

var _status: PackedByteArray = PackedByteArray()
var _present: PackedByteArray = PackedByteArray()
var _size_class: PackedByteArray = PackedByteArray()

# --- environment input columns (see the header) --------------------------------------------

var _activity: PackedByteArray = PackedByteArray()
var _comfort_environment: PackedByteArray = PackedByteArray()
var _social_paired: PackedByteArray = PackedByteArray()
var _purpose_source: PackedByteArray = PackedByteArray()
var _cold_environment: PackedByteArray = PackedByteArray()
var _clothing_tier: PackedByteArray = PackedByteArray()
var _infirmary: PackedByteArray = PackedByteArray()
var _injury_state: PackedByteArray = PackedByteArray()

# --- world-level inputs and derived rates ---------------------------------------------------

var _winter: bool = false
var _hard_freeze: bool = false
## Hunger decay per size class, milli-need-points/hour, with the size and winter multipliers
## already folded in. Recomputed only when winter changes, so the compound multiplication
## happens once per season boundary and never on the per-tick path.
var _hunger_rate_milli: PackedInt64Array = PackedInt64Array()

var _present_count: int = 0
var _living_count: int = 0
var _death_count: int = 0
var _last_refused_slot: int = -1

# --- scratch (not simulation state) ---------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Copy `_math.value` into a local
## before the next call. No callback or signal is invoked anywhere in this module, so no
## public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## _integrate_step()'s two outputs, consumed immediately by its caller.
var _step_value: int = 0
var _step_remainder: int = 0
## One tick's five need rates for one resident, refilled by _fill_need_rates() and consumed by
## _integrate_needs() before the next resident is touched. Allocated once with the columns.
var _rate_scratch: PackedInt64Array = PackedInt64Array()
## Value carried by the next OpResult, set by a `_*_checked()` helper just before it returns.
var _out_value: int = 0


func _init() -> void:
	"""Allocate every column once to capacity, then reset to the empty settlement state."""
	assert(RESIDENT_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_RESIDENT],
		"needs columns must match the directory's RESIDENT row capacity")
	assert(RESIDENT_LIVING_CAP == EntityDirectory.RESIDENT_LIVING_CAP,
		"needs living cap must match the directory's living cap")
	_check_rate_bounds()
	_allocate_columns()
	clear()


func _check_rate_bounds() -> void:
	"""Prove every published hourly rate fits MAX_RATE_MAGNITUDE.

	The per-tick integrator's overflow argument rests on this bound, so it is asserted rather
	than assumed: with |rate| <= 1.2e6 and |remainder| < 7.5e5 no accumulator step can come
	near int64. _integrate_step() re-checks the bound at runtime and refuses a rate outside it,
	so a future rate added here without updating MAX_RATE_MAGNITUDE fails loudly at both ends
	rather than integrating something the proof does not cover.
	"""
	var largest: int = maxi(HUNGER_DECAY_MILLI_PER_HOUR * SIZE_MULTIPLIER[SIZE_LARGE]
		* WINTER_HUNGER_MULTIPLIER / (SIZE_DENOMINATOR * SEASON_DENOMINATOR),
		REST_RESTORE_BED_MILLI_PER_HOUR)
	largest = maxi(largest, SOCIAL_RESTORE_PAIRED_MILLI_PER_HOUR)
	largest = maxi(largest, PURPOSE_RESTORE_MENTORING_MILLI_PER_HOUR + PURPOSE_DECAY_MILLI_PER_HOUR)
	assert(largest <= MAX_RATE_MAGNITUDE, "a published need rate exceeds its bound")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_need_value.resize(RESIDENT_CAPACITY * NEED_COUNT)
	_need_remainder.resize(RESIDENT_CAPACITY * NEED_COUNT)
	_health.resize(RESIDENT_CAPACITY)
	_health_remainder.resize(RESIDENT_CAPACITY)
	_cold_milli_hours.resize(RESIDENT_CAPACITY)
	_cold_remainder.resize(RESIDENT_CAPACITY)
	_starving_ticks.resize(RESIDENT_CAPACITY)
	_departure_days.resize(RESIDENT_CAPACITY)
	_status.resize(RESIDENT_CAPACITY)
	_present.resize(RESIDENT_CAPACITY)
	_size_class.resize(RESIDENT_CAPACITY)
	_activity.resize(RESIDENT_CAPACITY)
	_comfort_environment.resize(RESIDENT_CAPACITY)
	_social_paired.resize(RESIDENT_CAPACITY)
	_purpose_source.resize(RESIDENT_CAPACITY)
	_cold_environment.resize(RESIDENT_CAPACITY)
	_clothing_tier.resize(RESIDENT_CAPACITY)
	_infirmary.resize(RESIDENT_CAPACITY)
	_injury_state.resize(RESIDENT_CAPACITY)
	_hunger_rate_milli.resize(SIZE_COUNT)
	_rate_scratch.resize(NEED_COUNT)


func clear() -> void:
	"""Return every column to the empty settlement state without reallocating."""
	_need_value.fill(0)
	_need_remainder.fill(0)
	_health.fill(0)
	_health_remainder.fill(0)
	_cold_milli_hours.fill(0)
	_cold_remainder.fill(0)
	_starving_ticks.fill(0)
	_departure_days.fill(0)
	_status.fill(STATUS_DEAD)
	_present.fill(0)
	_size_class.fill(SIZE_SMALL)
	_fill_environment_defaults()
	_winter = false
	_hard_freeze = false
	_present_count = 0
	_living_count = 0
	_death_count = 0
	_last_refused_slot = -1
	_out_value = 0
	var code: StringName = _recompute_hunger_rates()
	assert(code == REFUSE_NONE, "the published hunger multipliers cannot overflow int64")


func _fill_environment_defaults() -> void:
	"""Reset every environment input column to its clearly-named unavailable default."""
	_activity.fill(ACTIVITY_AWAKE)
	_comfort_environment.fill(COMFORT_ENV_NONE)
	_social_paired.fill(0)
	_purpose_source.fill(PURPOSE_SOURCE_NONE)
	_cold_environment.fill(COLD_ENV_NEUTRAL)
	_clothing_tier.fill(CLOTHING_TIER_MIN)
	_infirmary.fill(0)
	_injury_state.fill(INJURY_NONE)


# --- result plumbing -------------------------------------------------------------------------

func _result(code: StringName) -> OpResult:
	"""Turn an internal refusal code plus the pending `_out_value` into one OpResult.

	This is NOT a sentinel scheme: the refusal code and the value travel on separate channels
	and a refusal always carries 0, so an ignored refusal cannot surface a usable number.
	"""
	var value: int = _out_value
	_out_value = 0
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


func _check_live_slot(slot: int) -> StringName:
	"""REFUSE_NONE when `slot` holds a present, not-yet-dead resident row."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if _status[slot] == STATUS_DEAD:
		return REFUSE_RESIDENT_DEAD
	return REFUSE_NONE


func _check_present_slot(slot: int) -> StringName:
	"""REFUSE_NONE when `slot` is in range and holds a spawned resident row, dead or alive."""
	if slot < 0 or slot >= RESIDENT_CAPACITY:
		return REFUSE_INVALID_SLOT
	if _present[slot] == 0:
		return REFUSE_NOT_PRESENT
	return REFUSE_NONE


# --- lifecycle -------------------------------------------------------------------------------

func spawn(slot: int, size_class: int) -> OpResult:
	"""Initialize one resident row to the GDD §5.1 start state: needs 7500, health 100.

	`slot` is the RESIDENT typed row entity_directory.gd allocated. Every environment input is
	reset to its unavailable default and every remainder to 0.
	"""
	return _result(_spawn_checked(slot, size_class))


func _spawn_checked(slot: int, size_class: int) -> StringName:
	"""Validate then write a fresh resident row. Refuses before touching anything."""
	if slot < 0 or slot >= RESIDENT_CAPACITY:
		return REFUSE_INVALID_SLOT
	if _present[slot] != 0:
		return REFUSE_ALREADY_PRESENT
	if size_class < 0 or size_class >= SIZE_COUNT:
		return REFUSE_INVALID_SIZE
	if _living_count >= RESIDENT_LIVING_CAP:
		return REFUSE_LIVING_CAP
	_write_spawn_row(slot, size_class)
	_present_count += 1
	_living_count += 1
	_out_value = slot
	return REFUSE_NONE


func _write_spawn_row(slot: int, size_class: int) -> void:
	"""Write every authoritative and input column of one freshly spawned resident."""
	var base: int = slot * NEED_COUNT
	for need: int in NEED_COUNT:
		_need_value[base + need] = INITIAL_NEED_VALUE
		_need_remainder[base + need] = 0
	_health[slot] = INITIAL_HEALTH
	_health_remainder[slot] = 0
	_cold_milli_hours[slot] = 0
	_cold_remainder[slot] = 0
	_starving_ticks[slot] = 0
	_departure_days[slot] = 0
	_present[slot] = 1
	_size_class[slot] = size_class
	_activity[slot] = ACTIVITY_AWAKE
	_comfort_environment[slot] = COMFORT_ENV_NONE
	_social_paired[slot] = 0
	_purpose_source[slot] = PURPOSE_SOURCE_NONE
	_cold_environment[slot] = COLD_ENV_NEUTRAL
	_clothing_tier[slot] = CLOTHING_TIER_MIN
	_infirmary[slot] = 0
	_injury_state[slot] = INJURY_NONE
	_status[slot] = STATUS_ACTIVE


func despawn(slot: int) -> OpResult:
	"""Release one resident row. The directory owns the slot; this only clears the data."""
	return _result(_despawn_checked(slot))


func _despawn_checked(slot: int) -> StringName:
	"""Validate then clear a resident row, keeping the living and present counts exact."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if _status[slot] != STATUS_DEAD:
		_living_count -= 1
	var base: int = slot * NEED_COUNT
	for need: int in NEED_COUNT:
		_need_value[base + need] = 0
		_need_remainder[base + need] = 0
	_health[slot] = 0
	_health_remainder[slot] = 0
	_cold_milli_hours[slot] = 0
	_cold_remainder[slot] = 0
	_starving_ticks[slot] = 0
	_present[slot] = 0
	_status[slot] = STATUS_DEAD
	_present_count -= 1
	_out_value = slot
	return REFUSE_NONE


# --- readers ---------------------------------------------------------------------------------

func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a spawned resident row, dead or alive."""
	return _check_present_slot(slot) == REFUSE_NONE


func is_alive(slot: int) -> bool:
	"""True when `slot` holds a spawned resident whose health has not reached 0."""
	return _check_live_slot(slot) == REFUSE_NONE


func present_count() -> int:
	"""Number of spawned resident rows, including rows whose resident has died."""
	return _present_count


func living_count() -> int:
	"""Number of spawned residents that are not dead. Never exceeds RESIDENT_LIVING_CAP."""
	return _living_count


func death_count() -> int:
	"""Deaths recorded since the last clear(), one per resident reaching health 0."""
	return _death_count


func last_refused_slot() -> int:
	"""Resident row that refused during the most recent tick_all(), or -1 when none did."""
	return _last_refused_slot


func need_of(slot: int, need: int) -> IntMath.IntResult:
	"""Current value of one need, 0-10000. Refuses an unknown slot or need index."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	need_into(slot, need, out)
	return out


func need_into(slot: int, need: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `need_of()`: write one need into the caller-owned `out`."""
	var code: StringName = _check_need_address(slot, need)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_need_value[slot * NEED_COUNT + need])


func need_remainder_of(slot: int, need: int) -> IntMath.IntResult:
	"""Retained signed remainder of one need, |value| < NEED_DENOMINATOR. Part of saved truth."""
	var code: StringName = _check_need_address(slot, need)
	if code != REFUSE_NONE:
		return _read(code, 0)
	return _read(REFUSE_NONE, _need_remainder[slot * NEED_COUNT + need])


func _check_need_address(slot: int, need: int) -> StringName:
	"""REFUSE_NONE when (slot, need) names a real need column of a spawned resident."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if need < 0 or need >= NEED_COUNT:
		return REFUSE_INVALID_NEED
	return REFUSE_NONE


func health_of(slot: int) -> IntMath.IntResult:
	"""Current health, 0-100."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	health_into(slot, out)
	return out


func health_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `health_of()`: write current health into the caller-owned `out`."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_health[slot])


func health_remainder_of(slot: int) -> IntMath.IntResult:
	"""Retained signed health remainder, |value| < HEALTH_DENOMINATOR. Part of saved truth."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _health_remainder[slot] if code == REFUSE_NONE else 0)


func cold_milli_hours_of(slot: int) -> IntMath.IntResult:
	"""Accumulated cold exposure in milli-hours: 1000 per exposure-hour (GDD §5.2)."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _cold_milli_hours[slot] if code == REFUSE_NONE else 0)


func cold_hours_of(slot: int) -> IntMath.IntResult:
	"""Needs.cold_hours: the floor/1000 display value of cold_milli_hours (GDD §5.2)."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if not IntMath.floor_div_into(_cold_milli_hours[slot], COLD_MILLI_PER_HOUR_UNIT, _math):
		return _read(REFUSE_OVERFLOW, 0)
	return _read(REFUSE_NONE, _math.value)


func starving_hours_of(slot: int) -> IntMath.IntResult:
	"""Needs.starving_hours: whole game hours spent at hunger 0 (REQ-SET-014)."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if not IntMath.floor_div_into(_starving_ticks[slot], TICKS_PER_HOUR, _math):
		return _read(REFUSE_OVERFLOW, 0)
	return _read(REFUSE_NONE, _math.value)


func departure_days_of(slot: int) -> IntMath.IntResult:
	"""Needs.departure_days. Reserved and always 0: REQ-SET-021..024 are deferred (header)."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _departure_days[slot] if code == REFUSE_NONE else 0)


func status_of(slot: int) -> IntMath.IntResult:
	"""ResidentStatus under the §5.2 precedence. See _refresh_status() for the ordering."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	status_into(slot, out)
	return out


func status_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `status_of()`: write ResidentStatus into the caller-owned `out`."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_status[slot])


func size_class_of(slot: int) -> IntMath.IntResult:
	"""Size class driving the hunger multiplier: SIZE_SMALL, SIZE_MEDIUM or SIZE_LARGE."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _size_class[slot] if code == REFUSE_NONE else 0)


func hunger_rate_milli_per_hour(size_class: int) -> IntMath.IntResult:
	"""Current hunger decay for a size class, milli-need-points/hour, size and season applied."""
	if size_class < 0 or size_class >= SIZE_COUNT:
		return _read(REFUSE_INVALID_SIZE, 0)
	return _read(REFUSE_NONE, _hunger_rate_milli[size_class])


func is_winter() -> bool:
	"""True while the winter hunger multiplier is in force (REQ-SET-143)."""
	return _winter


func is_hard_freeze() -> bool:
	"""True while the hard-freeze cold gain is in force (GDD §5.10)."""
	return _hard_freeze


# --- world-level inputs ------------------------------------------------------------------------

func set_winter(winter: bool) -> OpResult:
	"""Apply or release the REQ-SET-143 winter hunger multiplier for every resident."""
	var previous: bool = _winter
	_winter = winter
	var code: StringName = _recompute_hunger_rates()
	if code != REFUSE_NONE:
		_winter = previous
		var restore: StringName = _recompute_hunger_rates()
		assert(restore == REFUSE_NONE, "restoring the previous season must not refuse")
	return _result(code)


func set_hard_freeze(hard_freeze: bool) -> OpResult:
	"""Apply or release the GDD §5.10 hard-freeze cold-gain rates."""
	_hard_freeze = hard_freeze
	return _result(REFUSE_NONE)


func _recompute_hunger_rates() -> StringName:
	"""Fold the size and season multipliers into one hunger rate per size class.

	GDD §5.2: "Compound multipliers are applied in int64 before division." Both multipliers
	are therefore multiplied first and the combined 1000*1000 denominator divided once, so no
	intermediate rounding occurs (BAL-AUTH-002). Runs at a season boundary, not per tick.
	"""
	var season: int = WINTER_HUNGER_MULTIPLIER if _winter else SEASON_DENOMINATOR
	for size_class: int in SIZE_COUNT:
		if not IntMath.checked_mul_into(HUNGER_DECAY_MILLI_PER_HOUR, SIZE_MULTIPLIER[size_class], _math):
			return REFUSE_OVERFLOW
		if not IntMath.checked_mul_into(_math.value, season, _math):
			return REFUSE_OVERFLOW
		if not IntMath.floor_div_into(_math.value, SIZE_DENOMINATOR * SEASON_DENOMINATOR, _math):
			return REFUSE_OVERFLOW
		_hunger_rate_milli[size_class] = _math.value
	return REFUSE_NONE


# --- per-resident environment inputs ------------------------------------------------------------

func set_size_class(slot: int, size_class: int) -> OpResult:
	"""Change which §5.2 size multiplier scales this resident's hunger decay."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if size_class < 0 or size_class >= SIZE_COUNT:
		return _result(REFUSE_INVALID_SIZE)
	_size_class[slot] = size_class
	return _result(REFUSE_NONE)


func set_activity(slot: int, activity: int) -> OpResult:
	"""Set awake / asleep-in-bed / asleep-on-floor, which selects the rest rate."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if activity < 0 or activity >= ACTIVITY_COUNT:
		return _result(REFUSE_INVALID_ACTIVITY)
	_activity[slot] = activity
	_refresh_status(slot)
	return _result(REFUSE_NONE)


func set_comfort_environment(slot: int, environment: int) -> OpResult:
	"""Set the comfort restoration source: none, a valid heated room, or mild outdoors."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if environment < 0 or environment >= COMFORT_ENV_COUNT:
		return _result(REFUSE_INVALID_COMFORT_ENVIRONMENT)
	_comfort_environment[slot] = environment
	return _result(REFUSE_NONE)


func set_social_paired(slot: int, paired: bool) -> OpResult:
	"""Set whether the resident is in paired social activity (§5.2: +1200/hour)."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	_social_paired[slot] = 1 if paired else 0
	return _result(REFUSE_NONE)


func set_purpose_source(slot: int, source: int) -> OpResult:
	"""Set the purpose restoration source: none, completed useful labor, or mentoring."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if source < 0 or source >= PURPOSE_SOURCE_COUNT:
		return _result(REFUSE_INVALID_PURPOSE_SOURCE)
	_purpose_source[slot] = source
	return _result(REFUSE_NONE)


func set_cold_environment(slot: int, environment: int) -> OpResult:
	"""Set the cold environment: neutral, exposed (REQ-SET-018), or heated shelter (019)."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if environment < 0 or environment >= COLD_ENV_COUNT:
		return _result(REFUSE_INVALID_COLD_ENVIRONMENT)
	_cold_environment[slot] = environment
	return _result(REFUSE_NONE)


func set_clothing_tier(slot: int, tier: int) -> OpResult:
	"""Set clothing tier 1 or 2. Tier 2 removes the baseline cold gain (GDD §5.10)."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if tier < CLOTHING_TIER_MIN or tier > CLOTHING_TIER_MAX:
		return _result(REFUSE_INVALID_CLOTHING_TIER)
	_clothing_tier[slot] = tier
	return _result(REFUSE_NONE)


func set_infirmary(slot: int, in_infirmary: bool) -> OpResult:
	"""Set whether recovery uses the REQ-SET-017 infirmary rate of 4 health/hour."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	_infirmary[slot] = 1 if in_infirmary else 0
	return _result(REFUSE_NONE)


func set_injury_state(slot: int, injury_state: int) -> OpResult:
	"""Set injury presence: none, an active injury, or an untreated serious injury.

	INJURY_ACTIVE selects the §5.2 INJURED status band; INJURY_UNTREATED_SERIOUS additionally
	blocks REQ-SET-017 recovery. Injury damage rates live with the Injury component (header).
	"""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	if injury_state < 0 or injury_state >= INJURY_STATE_COUNT:
		return _result(REFUSE_INVALID_INJURY_STATE)
	_injury_state[slot] = injury_state
	_refresh_status(slot)
	return _result(REFUSE_NONE)


# --- events ------------------------------------------------------------------------------------

func apply_need_event(slot: int, need: int, points: int) -> OpResult:
	"""Add signed whole need points outside the rate integration; returns points absorbed.

	Value clamps to 0-10000 and, per BAL-NUM-001, a bound reached this way also discards the
	retained remainder that would push farther outside it. The returned value is what the need
	actually absorbed, so a caller can account for the discarded surplus rather than assume none.
	"""
	return _result(_apply_need_event_checked(slot, need, points))


func _apply_need_event_checked(slot: int, need: int, points: int) -> StringName:
	"""Validate then apply one whole-point need event. Refuses before writing anything."""
	var code: StringName = _check_need_address(slot, need)
	if code != REFUSE_NONE:
		return code
	if _status[slot] == STATUS_DEAD:
		return REFUSE_RESIDENT_DEAD
	var index: int = slot * NEED_COUNT + need
	if not IntMath.checked_add_into(_need_value[index], points, _math):
		return REFUSE_OVERFLOW
	var before: int = _need_value[index]
	var value: int = clampi(_math.value, NEED_MIN, NEED_MAX)
	_need_value[index] = value
	_discard_remainder_at_bound(index, value)
	_out_value = value - before
	return REFUSE_NONE


func _discard_remainder_at_bound(index: int, value: int) -> void:
	"""BAL-NUM-001: at a bound, drop only the retained remainder pushing farther outside it."""
	var remainder: int = _need_remainder[index]
	if (value == NEED_MAX and remainder > 0) or (value == NEED_MIN and remainder < 0):
		_need_remainder[index] = 0


func add_food_nutrition(slot: int, nutrition_points: int) -> OpResult:
	"""Eat: add nutrition points to hunger (§5.2 maps 1 NP to 1 need point).

	"eating consumes one prepared portion at task completion, clamping fullness without
	refunding excess NP" -- so the surplus is discarded, and the returned value is the amount
	actually absorbed. Quality factors and portion nutrition are resolved by the caller: those
	belong to the §5.7 recipe catalog, which this module does not own.
	"""
	if nutrition_points < 0:
		return _result(REFUSE_INVALID_POINTS)
	return apply_need_event(slot, NEED_HUNGER, nutrition_points)


func add_shared_meal_social(slot: int) -> OpResult:
	"""Dining bonus: +200 social per shared meal (GDD §5.2 restoration column)."""
	return apply_need_event(slot, NEED_SOCIAL, SOCIAL_SHARED_MEAL_POINTS)


func apply_health_event(slot: int, points: int) -> OpResult:
	"""Add signed whole health points outside the rate integration; returns points absorbed.

	Treatment (REQ-SET-173 restores 10 health, capped 100) and instantaneous injury damage
	arrive here. Reaching 0 records a death exactly as the per-tick drain does.
	"""
	return _result(_apply_health_event_checked(slot, points))


func _apply_health_event_checked(slot: int, points: int) -> StringName:
	"""Validate then apply one whole-point health event. Refuses before writing anything."""
	var code: StringName = _check_live_slot(slot)
	if code != REFUSE_NONE:
		return code
	if not IntMath.checked_add_into(_health[slot], points, _math):
		return REFUSE_OVERFLOW
	var before: int = _health[slot]
	var value: int = clampi(_math.value, HEALTH_MIN, HEALTH_MAX)
	_health[slot] = value
	var remainder: int = _health_remainder[slot]
	if (value == HEALTH_MAX and remainder > 0) or (value == HEALTH_MIN and remainder < 0):
		_health_remainder[slot] = 0
	if value == HEALTH_MIN:
		_death_count += 1
		_living_count -= 1
	_refresh_status(slot)
	_out_value = value - before
	return REFUSE_NONE


# --- the integration core ------------------------------------------------------------------------

func _integrate_step(current: int, remainder: int, rate: int, denominator: int,
		minimum: int, maximum: int) -> StringName:
	"""One tick of the GDD §5.2 remainder rule. THE single integrator in this module.

	Adds `rate` (per game hour, in the column's own sub-unit) to the retained accumulator,
	extracts trunc(accumulator/denominator) whole units, keeps the signed remainder, clamps
	the value into [minimum, maximum], and then discards only the remainder that would push
	farther outside a reached bound (BAL-NUM-001, GDD §5.2 "discard overflow of either sign").
	Leaves the new value in _step_value and the retained remainder in _step_remainder.

	OVERFLOW. This runs for seven columns of every living resident on every tick, so instead
	of a checked call per operation it establishes the three preconditions that make the
	accumulator arithmetic provably safe, and REFUSES when one does not hold:
	  * |rate| <= MAX_RATE_MAGNITUDE (1.2e6),
	  * denominator > 0 -- the same guard IntMath.trunc_div_into() applies, hoisted out,
	  * |remainder| < denominator <= NEED_DENOMINATOR (7.5e5) -- the invariant this function
	    itself re-establishes on every step, checked rather than assumed.
	Under those, |remainder + rate| < 2e6 < 2^21, so neither the accumulator sum, the
	truncating division (GDScript's `/` truncates toward zero, exactly as trunc_div does for a
	positive denominator), nor `whole * denominator` can approach int64. `current + whole` is
	the one term whose magnitude the caller controls -- cold_milli_hours has no specified
	ceiling -- so that addition alone stays a checked call and refuses rather than wrapping.
	"""
	if rate > MAX_RATE_MAGNITUDE or rate < -MAX_RATE_MAGNITUDE:
		return REFUSE_RATE_OUT_OF_RANGE
	if denominator <= 0 or denominator > NEED_DENOMINATOR:
		return REFUSE_INVALID_DENOMINATOR
	if remainder >= denominator or remainder <= -denominator:
		return REFUSE_REMAINDER_INVARIANT
	var accumulator: int = remainder + rate
	var whole: int = accumulator / denominator
	accumulator -= whole * denominator
	if not IntMath.checked_add_into(current, whole, _math):
		return REFUSE_OVERFLOW
	var value: int = clampi(_math.value, minimum, maximum)
	if (value == maximum and accumulator > 0) or (value == minimum and accumulator < 0):
		accumulator = 0
	_step_value = value
	_step_remainder = accumulator
	return REFUSE_NONE


func tick(slot: int) -> OpResult:
	"""Integrate one resident across one fixed tick. Refuses a dead or absent resident.

	REQ-SET-011: this takes no elapsed time, no speed and no delta. A tick is a tick, so 2x
	and 4x run more of exactly this call and nothing else (REQ-SET-003), and visibility cannot
	reach it at all.
	"""
	var code: StringName = _check_live_slot(slot)
	if code != REFUSE_NONE:
		return _result(code)
	code = _tick_resident(slot)
	if code == REFUSE_NONE:
		_out_value = 1
	return _result(code)


func tick_all() -> OpResult:
	"""Integrate every spawned, living resident for one tick; value is the count integrated.

	Dead rows are skipped rather than refused -- a settlement with a death in it is not an
	error. A genuine refusal stops the sweep and names the row in last_refused_slot(), so a
	partial sweep is always visible instead of being averaged away.
	"""
	_last_refused_slot = -1
	var integrated: int = 0
	for slot: int in RESIDENT_CAPACITY:
		if _present[slot] == 0 or _status[slot] == STATUS_DEAD:
			continue
		var code: StringName = _tick_resident(slot)
		if code != REFUSE_NONE:
			_last_refused_slot = slot
			return _result(code)
		integrated += 1
	_out_value = integrated
	return _result(REFUSE_NONE)


func _tick_resident(slot: int) -> StringName:
	"""Integrate one resident: sample health inputs, then needs, cold, health, status.

	The health inputs are sampled BEFORE the needs move, so a tick's health effect reflects
	the state the resident was actually in during that tick. This is winter_world.gd's own
	ordering (it reads `starving` before decaying hunger) and is kept deliberately.
	"""
	var starving: bool = _need_value[slot * NEED_COUNT + NEED_HUNGER] == HUNGER_STARVING_VALUE
	var cold_gain: int = _cold_gain_milli_per_hour(slot)
	var health_rate: int = _health_rate_per_hour(slot, starving, cold_gain)
	var cold_rate: int = _cold_rate_milli_per_hour(slot, cold_gain)
	_fill_need_rates(slot)
	var code: StringName = _integrate_needs(slot)
	if code != REFUSE_NONE:
		return code
	code = _integrate_cold(slot, cold_rate)
	if code != REFUSE_NONE:
		return code
	code = _integrate_health(slot, health_rate)
	if code != REFUSE_NONE:
		return code
	if starving:
		_starving_ticks[slot] += 1
	_refresh_status(slot)
	return REFUSE_NONE


func _integrate_needs(slot: int) -> StringName:
	"""Integrate all five needs of one resident for one tick from `_rate_scratch`."""
	for need: int in NEED_COUNT:
		var index: int = slot * NEED_COUNT + need
		var code: StringName = _integrate_step(_need_value[index], _need_remainder[index],
			_rate_scratch[need], NEED_DENOMINATOR, NEED_MIN, NEED_MAX)
		if code != REFUSE_NONE:
			return code
		_need_value[index] = _step_value
		_need_remainder[index] = _step_remainder
	return REFUSE_NONE


func _integrate_cold(slot: int, rate: int) -> StringName:
	"""Integrate cold exposure in milli-hours for one tick, floored at 0.

	There is no upper bound in the specification, so the only ceiling is int64 itself and
	_integrate_step() refuses rather than wrapping if a caller ever drives it that far.
	"""
	var code: StringName = _integrate_step(_cold_milli_hours[slot], _cold_remainder[slot],
		rate, COLD_DENOMINATOR, 0, IntMath.INT64_MAX)
	if code != REFUSE_NONE:
		return code
	_cold_milli_hours[slot] = _step_value
	_cold_remainder[slot] = _step_remainder
	return REFUSE_NONE


func _integrate_health(slot: int, rate: int) -> StringName:
	"""Integrate health for one tick and record a death when it reaches 0 (REQ-SET-016)."""
	var code: StringName = _integrate_step(_health[slot], _health_remainder[slot],
		rate, HEALTH_DENOMINATOR, HEALTH_MIN, HEALTH_MAX)
	if code != REFUSE_NONE:
		return code
	var died: bool = _step_value == HEALTH_MIN and _health[slot] > HEALTH_MIN
	_health[slot] = _step_value
	_health_remainder[slot] = _step_remainder
	if died:
		_death_count += 1
		_living_count -= 1
	return REFUSE_NONE


# --- rate selection ------------------------------------------------------------------------------

func _fill_need_rates(slot: int) -> void:
	"""Write this resident's five signed need rates, in milli-need-points/hour, into scratch.

	§5.2's restoration column adds to the baseline decay rather than replacing it: the winter
	control kernel's net +1100 social while socializing is exactly 1200 - 100, and its net
	+245 purpose while working is exactly 320 - 75. Rest is the one stated exception --
	"no awake decay while asleep" -- so sleep restoration is gross, not net.

	All five are produced in one pass into a reused five-element column rather than through a
	call per need, because this runs for every living resident on every tick.
	"""
	var paired: int = SOCIAL_RESTORE_PAIRED_MILLI_PER_HOUR if _social_paired[slot] == 1 else 0
	_rate_scratch[NEED_HUNGER] = -_hunger_rate_milli[_size_class[slot]]
	_rate_scratch[NEED_REST] = _rest_rate_milli_per_hour(slot)
	_rate_scratch[NEED_COMFORT] = _comfort_restore_milli_per_hour(slot) - COMFORT_DECAY_MILLI_PER_HOUR
	_rate_scratch[NEED_SOCIAL] = paired - SOCIAL_DECAY_MILLI_PER_HOUR
	_rate_scratch[NEED_PURPOSE] = _purpose_restore_milli_per_hour(slot) - PURPOSE_DECAY_MILLI_PER_HOUR


func _rest_rate_milli_per_hour(slot: int) -> int:
	"""Rest rate: +1200/hour in a bed, +750/hour on the floor, -375/hour while awake."""
	match _activity[slot]:
		ACTIVITY_SLEEP_BED:
			return REST_RESTORE_BED_MILLI_PER_HOUR
		ACTIVITY_SLEEP_FLOOR:
			return REST_RESTORE_FLOOR_MILLI_PER_HOUR
		_:
			return -REST_DECAY_MILLI_PER_HOUR


func _comfort_restore_milli_per_hour(slot: int) -> int:
	"""Comfort restoration: +300/hour in a valid heated room, +100/hour outdoors at 10-24 C."""
	match _comfort_environment[slot]:
		COMFORT_ENV_HEATED_ROOM:
			return COMFORT_RESTORE_HEATED_ROOM_MILLI_PER_HOUR
		COMFORT_ENV_MILD_OUTDOORS:
			return COMFORT_RESTORE_MILD_OUTDOORS_MILLI_PER_HOUR
		_:
			return 0


func _purpose_restore_milli_per_hour(slot: int) -> int:
	"""Purpose restoration: +320/hour of completed useful labor, +400/hour mentoring."""
	match _purpose_source[slot]:
		PURPOSE_SOURCE_LABOR:
			return PURPOSE_RESTORE_LABOR_MILLI_PER_HOUR
		PURPOSE_SOURCE_MENTORING:
			return PURPOSE_RESTORE_MENTORING_MILLI_PER_HOUR
		_:
			return 0


# --- published net need rates (NEED-RATE-R01) ------------------------------------------------
#
# The four readers below exist because the selected-resident panel must display the SAME
# continuous rate the integrator is about to apply, and UXV-020 forbids it recreating these
# formulas, reading a private column, or substituting a universal baseline. They publish the
# signed NET rate in milli-need-points per SIMULATED hour -- the exact int64 _fill_need_rates()
# writes for this resident this instant.
#
# WHAT THEY ARE NOT:
#   * Not a cache. Nothing is retained, there is no dirty flag and no invalidation rule; a
#     context change is visible on the very next call because the selector runs again.
#   * Not a second formula. _fill_need_rates() stays the single rate authority; these copy one
#     of its named entries out by value. A rate is never computed twice in this file.
#   * Not a hot path. The per-tick sweep keeps its one-pass _fill_need_rates() call and gains
#     nothing here: _tick_resident() does not call these, so a tick's call count is unchanged.
#   * Not an event. No need, remainder, activity/environment flag, status, clock or RNG is
#     written. Asking what the rate is changes nothing about the settlement.
#
# SIGN. These are already net and already signed: rest awake is -375000, comfort in a heated
# room is +200000. `hunger_rate_milli_per_hour()` is deliberately the other way round -- it
# keeps its established POSITIVE decay magnitude and its existing callers, and the display
# adapter is the thing that forms R = -magnitude. Negating one of these a second time, or
# subtracting a baseline that _fill_need_rates() already subtracted, is the mistake the
# fixture table plus the 750-tick comparison in test_needs.gd exists to catch.
#
# ZERO IS A REAL ANSWER. Mild outdoors restores +100000 against a -100000 comfort decay, so its
# net rate is exactly 0 with ok == true. A refusal also carries 0, which is why the refusal
# travels on `.ok` and the caller is required to inspect it (finding H4): a cleared zero from a
# refused read is NOT a balanced resident.

func rest_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Signed net rest rate, milli-need-points/simulated hour: +1200000 in a bed, +750000 on the
	floor, -375000 awake. Sleep has no awake decay, so the sleeping rates are gross by §5.2."""
	return _net_need_rate_into(slot, NEED_REST, out)


func comfort_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Signed net comfort rate, milli-need-points/simulated hour: +200000 in a valid heated room,
	0 in mild outdoors, -100000 with no restoration. The 0 is a success, not a refusal."""
	return _net_need_rate_into(slot, NEED_COMFORT, out)


func social_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Signed net social rate, milli-need-points/simulated hour: +1100000 paired, -100000 alone.
	A shared meal's +200 points is a discrete event and is deliberately not folded in here."""
	return _net_need_rate_into(slot, NEED_SOCIAL, out)


func purpose_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Signed net purpose rate, milli-need-points/simulated hour: +245000 from useful labor,
	+325000 mentoring, -75000 with no source. Planned-but-unstarted jobs contribute nothing."""
	return _net_need_rate_into(slot, NEED_PURPOSE, out)


func _net_need_rate_into(slot: int, need: int, out: IntMath.IntResult) -> bool:
	"""Copy one need's currently selected signed net rate into the caller-owned `out`.

	COLD PATH, BETWEEN COMPLETED UPDATES. `_rate_scratch` is the tick sweep's five-element
	buffer, consumed by _integrate_needs() before the next resident is touched. Reusing it here
	is allowed (it is bounded scratch, not a stored rate), but only because no caller can reach
	this while a tick holds live values in it: this module invokes no callback and emits no
	signal, so _tick_resident() cannot be re-entered, and the UI reads its snapshot between
	completed simulation updates. The scratch ARRAY is never handed out -- `out.succeed()` takes
	the int64 by value, so a later tick cannot rewrite an answer the caller is still holding.

	Refuses a row that is out of range, unspawned or dead, with the actual reason and a cleared
	value. It refuses a dead row deliberately: a corpse has no continuous rate, and answering
	with the rate its columns happen to still describe would be the stale-row read the ruling
	forbids.
	"""
	var code: StringName = _check_live_slot(slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	_fill_need_rates(slot)
	return out.succeed(_rate_scratch[need])


# --- cold and health rate selection ------------------------------------------------------------

func _cold_gain_milli_per_hour(slot: int) -> int:
	"""Cold gain while exposed: tier 1 1000/hour, tier 2 0; hard freeze 2000 and 1000."""
	var tier2: bool = _clothing_tier[slot] >= CLOTHING_TIER_MAX
	if _hard_freeze:
		return COLD_GAIN_HARD_FREEZE_TIER2_MILLI_PER_HOUR if tier2 \
			else COLD_GAIN_HARD_FREEZE_TIER1_MILLI_PER_HOUR
	return COLD_GAIN_TIER2_MILLI_PER_HOUR if tier2 else COLD_GAIN_TIER1_MILLI_PER_HOUR


func _cold_rate_milli_per_hour(slot: int, cold_gain: int) -> int:
	"""Signed cold rate: `cold_gain` while exposed, -2000/hour in heated shelter, else 0.

	`cold_gain` is this resident's _cold_gain_milli_per_hour(), computed once per tick because
	both this rate and the exposure-damage test need it.
	"""
	match _cold_environment[slot]:
		COLD_ENV_EXPOSED:
			return cold_gain
		COLD_ENV_HEATED_SHELTER:
			return -COLD_CLEAR_SHELTER_MILLI_PER_HOUR
		_:
			return 0


func _is_cold_damaging(slot: int, cold_gain: int) -> bool:
	"""REQ-SET-018/019: damage once 4 exposure hours are banked and gain is still happening.

	"until sheltered or properly clothed" and "stop exposure damage immediately" both reduce
	to the same test -- damage runs exactly while the resident is still taking cold on -- which
	is why tier 2 at -5 C stops it but tier 2 in a hard freeze (gain 1000) does not.
	"""
	if _cold_environment[slot] != COLD_ENV_EXPOSED:
		return false
	if cold_gain <= 0:
		return false
	return _cold_milli_hours[slot] >= COLD_DAMAGE_HOURS * COLD_MILLI_PER_HOUR_UNIT


func _health_rate_per_hour(slot: int, starving: bool, cold_gain: int) -> int:
	"""Signed health rate in whole points per game hour, summed over §5.2's causes.

	REQ-SET-014 (-4 starving), REQ-SET-018 (-3 cold) and REQ-SET-017 (+2, or +4 in an
	infirmary) are independent requirements with independent conditions, so they SUM rather
	than override. Starvation and recovery are mutually exclusive by construction: recovery
	needs hunger >= 4000 and starvation needs hunger = 0. Cold damage and recovery are not,
	and a well-fed rested resident freezing outdoors nets -1/hour, which is the literal
	reading of both requirements.
	"""
	var rate: int = 0
	if starving:
		rate -= HEALTH_STARVATION_DRAIN_PER_HOUR
	if _is_cold_damaging(slot, cold_gain):
		rate -= HEALTH_COLD_DRAIN_PER_HOUR
	if _can_recover_health(slot):
		rate += HEALTH_RECOVERY_INFIRMARY_PER_HOUR if _infirmary[slot] == 1 \
			else HEALTH_RECOVERY_PER_HOUR
	return rate


func _can_recover_health(slot: int) -> bool:
	"""REQ-SET-017: health<100, hunger and rest both >=4000, no untreated serious injury."""
	if _health[slot] >= HEALTH_MAX:
		return false
	if _injury_state[slot] == INJURY_UNTREATED_SERIOUS:
		return false
	var base: int = slot * NEED_COUNT
	if _need_value[base + NEED_HUNGER] < HEALTH_RECOVERY_NEED_FLOOR:
		return false
	return _need_value[base + NEED_REST] >= HEALTH_RECOVERY_NEED_FLOOR


func _refresh_status(slot: int) -> void:
	"""Apply the §5.2 precedence: DEAD at 0, INCAPACITATED 1-15, INJURED 16-99 with an active
	Injury, otherwise ACTIVE or the current RESTING activity.

	STATUS_LEAVING is never set here: departure is deferred (header), and §5.2's precedence
	list does not place it, so inventing a position for it would be inventing a rule.
	"""
	if _health[slot] <= HEALTH_MIN:
		_status[slot] = STATUS_DEAD
		return
	if _health[slot] <= HEALTH_INCAPACITATED_MAX:
		_status[slot] = STATUS_INCAPACITATED
		return
	if _health[slot] < HEALTH_MAX and _injury_state[slot] != INJURY_NONE:
		_status[slot] = STATUS_INJURED
		return
	_status[slot] = STATUS_RESTING if _activity[slot] != ACTIVITY_AWAKE else STATUS_ACTIVE


# --- mood, factors, memories (REQ-SET-020) -----------------------------------------------------

func mood_of(slot: int, memory_total: int) -> IntMath.IntResult:
	"""REQ-SET-020 mood: clamp(floor(weighted needs / 10) + memory_total, 0, 10000).

	`memory_total` is the summed value of this resident's active MoodMemory entries. It is an
	argument rather than stored state because blocker U6 leaves the MoodMemory child store's
	owner-major index formula unspecified; memory_value_of() publishes the §5.2 catalog values
	so a caller can sum them without inventing anything.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	mood_into(slot, memory_total, out)
	return out


func mood_into(slot: int, memory_total: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `mood_of()`, using caller-owned `out` for both arithmetic steps."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return _mood_of_checked_row_into(slot, memory_total, out)


func _mood_of_checked_row_into(slot: int, memory_total: int, out: IntMath.IntResult) -> bool:
	"""REQ-SET-020's mood for a row `_check_present_slot()` has ALREADY accepted.

	THIS IS THE ONE IMPLEMENTATION OF THE MOOD FORMULA. `mood_into()` validates the slot and
	delegates here; `work_factor_for_resident_into()` calls it after its own single validation.
	The weighted sum, the divisor, the memory term and the clamp therefore exist exactly once,
	so the fused reader cannot drift away from the unfused chain (decision 0024 section 4).

	It is private because it trusts its caller about the slot, which no published reader may.
	"""
	var base: int = slot * NEED_COUNT
	var weighted: int = 0
	for need: int in NEED_COUNT:
		weighted += MOOD_WEIGHT[need] * _need_value[base + need]
	if not IntMath.floor_div_into(weighted, MOOD_DIVISOR, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	var needs_mood: int = out.value
	if not IntMath.checked_add_into(needs_mood, memory_total, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return out.succeed(clampi(out.value, MOOD_MIN, MOOD_MAX))


func mood_factor(mood: int) -> int:
	"""§5.2 productivity factor over 1000: <2000->600, 2000-3999->800, 4000-6999->1000,
	7000-8499->1100, >=8500->1150."""
	for band: int in MOOD_FACTOR_BAND_FLOOR.size():
		if mood < MOOD_FACTOR_BAND_FLOOR[band]:
			return MOOD_FACTOR_VALUE[band]
	return MOOD_FACTOR_VALUE[MOOD_FACTOR_VALUE.size() - 1]


func health_factor(health: int) -> int:
	"""§5.2 health factor over 1000: <40->600, 40-69->850, >=70->1000."""
	for band: int in HEALTH_FACTOR_BAND_FLOOR.size():
		if health < HEALTH_FACTOR_BAND_FLOOR[band]:
			return HEALTH_FACTOR_VALUE[band]
	return HEALTH_FACTOR_VALUE[HEALTH_FACTOR_VALUE.size() - 1]


func skill_factor(skill_level: int) -> IntMath.IntResult:
	"""§5.2 skill factor: 1000 + 50*level, for a skill level of 0..10."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	skill_factor_into(skill_level, out)
	return out


func skill_factor_into(skill_level: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `skill_factor()`: write the factor into the caller-owned `out`."""
	if skill_level < 0 or skill_level > SKILL_LEVEL_MAX:
		return out.refuse(String(REFUSE_INVALID_SKILL_LEVEL))
	return out.succeed(SKILL_FACTOR_BASE + SKILL_FACTOR_PER_LEVEL * skill_level)


func work_factor(skill_level: int, mood: int, health: int) -> IntMath.IntResult:
	"""§5.2 total work factor: clamp(floor(skill*mood*health/1000000), 300, 1800).

	`mood` and `health` are the raw 0-10000 and 0-100 values; their factors are derived here so
	no caller can pair a mood value with a health factor by mistake. The per-tick 80 milli-WU
	work output that consumes this factor belongs to the labour slice, not to needs.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	work_factor_into(skill_level, mood, health, out)
	return out


func work_factor_into(skill_level: int, mood: int, health: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating `work_factor()`, reusing caller-owned `out` through every checked step."""
	if not skill_factor_into(skill_level, out):
		return false
	var skill: int = out.value
	if not IntMath.checked_mul_into(skill, mood_factor(mood), out):
		return out.refuse(String(REFUSE_OVERFLOW))
	var skill_mood: int = out.value
	if not IntMath.checked_mul_into(skill_mood, health_factor(health), out):
		return out.refuse(String(REFUSE_OVERFLOW))
	var numerator: int = out.value
	if not IntMath.floor_div_into(numerator, WORK_FACTOR_DIVISOR, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return out.succeed(clampi(out.value, WORK_FACTOR_MIN, WORK_FACTOR_MAX))


func work_factor_for_resident_into(resident_slot: int, skill_level: int, memory_total: int,
		out: IntMath.IntResult) -> bool:
	"""Decision 0024 section 4's fused reader: §5.2's work factor for one resident, in one call.

	VALIDATES THE ROW ONCE. The chain this replaces cost a work tick three calls into this module
	per resident -- `health_into()`, `mood_into()`, `work_factor_into()` -- and the first two
	each ran `_check_present_slot()` on the same row. This is one call, one presence check, and
	a direct read of the health column. That is the whole of the change: a CALL-COUNT REDUCTION.

	IT KEEPS ONE CANONICAL FORMULA. The mood term comes from `_mood_of_checked_row_into()` and
	the factor from `work_factor_into()` -- the same two implementations the unfused chain runs,
	called rather than copied. There is no second copy of a §7.1-verified formula here.

	IT IS NOT A CACHE. Nothing is retained between calls, no dirty flag exists and no validity
	rule is introduced, so every call reads the columns as they stand this instant and observes
	exactly the tick the unfused chain would have observed. Decision 0024 section 4 reserves
	caching for a separate decision whose contract must cover every mutation.

	REFUSAL ORDER MATCHES THE CHAIN: the resident row is judged before the skill level, exactly
	as the chain judged it in `health_into()` before `work_factor_into()`.
	"""
	var code: StringName = _check_present_slot(resident_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if not _mood_of_checked_row_into(resident_slot, memory_total, out):
		return false
	var mood: int = out.value
	var health: int = _health[resident_slot]
	return work_factor_into(skill_level, mood, health, out)


func memory_value_of(memory_key: StringName) -> IntMath.IntResult:
	"""Mood value of one §5.2 memory kind, looked up by catalog key."""
	var index: int = MEMORY_KEYS.find(memory_key)
	if index < 0:
		return _read(REFUSE_UNKNOWN_MEMORY, 0)
	return _read(REFUSE_NONE, MEMORY_VALUES[index])


func memory_duration_hours_of(memory_key: StringName) -> IntMath.IntResult:
	"""Duration in game hours of one §5.2 memory kind.

	Refuses `untreated_injury`, whose §5.2 duration is "until treated" and therefore has no
	hour count at all. Returning 0 or -1 for it would be exactly the sentinel that finding H4
	was about, so the absence is reported as a refusal instead.
	"""
	var index: int = MEMORY_KEYS.find(memory_key)
	if index < 0:
		return _read(REFUSE_UNKNOWN_MEMORY, 0)
	if MEMORY_UNTIL_TREATED[index]:
		return _read(REFUSE_DURATION_CONDITIONAL, 0)
	return _read(REFUSE_NONE, MEMORY_DURATION_HOURS[index])
