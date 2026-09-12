extends RefCounted
## UI-SET-036's resident journal, composed from the stores and nothing else.
##
## UXV-019..023 fix what the resident card says and in what order. This module is where every
## one of those strings is BUILT, so that `ui_shell.gd` only ever renders text somebody else
## derived and `ui_manager.gd` only ever routes it. That separation is the reason the percent
## conversion is testable at all: it is one static function over one integer.
##
## ---------------------------------------------------------------------------------------
## THE DEFECT THIS FILE EXISTS TO FIX. The card printed `Hunger 7500 of 10000`.
##
##  * UXV-020: "never expose 7500 as the player-facing 75% value". Basis points are the
##    store's unit, not the player's. `percent_text()` converts EXACTLY, in integers, to at
##    most two decimals with trailing zeroes trimmed -- 7500 to "75%", 7501 to "75.01%", 0 to
##    "0%", 10000 to "100%". There is no float in the conversion, and no rounding: a value that
##    cannot be said exactly in two decimals cannot occur, because 0-10000 over 100 is exact.
##  * UXV-021: the visible label is `Fullness`, not `Hunger`, and "a larger value means more
##    satisfied". The NUMBER IS NOT INVERTED. §5: "Fullness is satisfaction, not severity; do
##    not fill 25% for 7500." The underlying field name reaches the player through
##    `accessible_text()`, which is §5's "Hunger/fullness in accessible detail".
##
## ---------------------------------------------------------------------------------------
## RATES, AND THE FOUR THAT ARE NOT PUBLISHED. §5 requires "current per-simulated-hour change"
## and says, in terms, "If rate isn't published, say Rate unavailable".
##
## `needs.gd` computes all five effective rates in `_fill_need_rates()`, which is PRIVATE, and
## publishes exactly one of them: `hunger_rate_milli_per_hour(size_class)`, with the size and
## season multipliers already folded in. That single reader is enough for Fullness, because
## hunger's effective rate depends on nothing else -- `_fill_need_rates()` writes
## `-_hunger_rate_milli[_size_class[slot]]` and no other term.
##
## The other four cannot be derived from the public interface at all. Rest depends on
## `_activity`, comfort on `_comfort_environment`, social on `_social_paired` and purpose on
## `_purpose_source`; every one of those four columns has a SETTER and no reader. Substituting
## the baseline decay would be "the baseline formula as a universal answer", which §5 forbids
## by name -- a resident asleep in a bed would be shown losing rest. So those four rows say
## RATE_UNAVAILABLE, and the missing readers are an unfulfilled binding requirement reported
## against `scripts/core/needs.gd`, which this task does not own and does not touch.
##
## ---------------------------------------------------------------------------------------
## WHAT ELSE IS GENUINELY ABSENT, stated rather than filled in with a plausible zero:
##   * AGE. `residents.gd` stores species, size, role, name, arrival tick, home, bed, skills
##     and equipment. There is no age column and no birth tick, so UXV-019's "age" is
##     unavailable; `arrival_tick_of()` is an arrival, not an age, and is not relabelled as one.
##   * CENTER VIEW. §4.1 asks for a 44-high Center view in a 64 px footer. Its semantics belong
##     to UI-SET-037 ("click center-camera") and `ui_availability.gd` records REASON_NO_WORLD_
##     CAMERA: "the interface binds no camera". Building the action would require inventing
##     both a registry row and a camera binding, so it is NOT built and is reported.
##
## No allocation happens per row read: the five Row objects are built once in `_init()`.

const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const UiArt := preload("res://ui/ui_art.gd")

# --- the five need rows -------------------------------------------------------------------

## UXV-021's visible labels, indexed by `NeedsScript.NEED_*`. `hunger` is shown as `Fullness`;
## the other four keep the store's own word because it is already the satisfaction sense.
const NEED_LABELS: Array[String] = ["Fullness", "Rest", "Comfort", "Social", "Purpose"]
## The store field behind each label, for §5's "Hunger/fullness in accessible detail".
const NEED_FIELDS: Array[String] = ["hunger", "rest", "comfort", "social", "purpose"]

## §5's exact wording for a rate no system publishes. Not a zero, and not a blank.
const RATE_UNAVAILABLE: String = "Rate unavailable"
## Why that rate is missing, for the row's accessible description.
const RATE_UNAVAILABLE_REASON: String = \
	"needs.gd publishes no effective rate for this need"

## Basis points per whole percent. 10000 basis points is 100%, so 100 of them is 1%.
const BASIS_POINTS_PER_PERCENT: int = 100
## Milli-need-points per game hour that equal one hundredth of a percentage point per hour:
## 1000 milli is one need point, and 100 need points is one percentage point of 10000.
const MILLI_PER_RATE_HUNDREDTH: int = 1000
## Two decimal places, expressed as the divisor that splits them off.
const HUNDREDTHS: int = 100

# --- identity -----------------------------------------------------------------------------

## UXV-019: the heading for a resident the settlement has not named.
const UNNAMED_HEADING: String = "Unnamed resident"
## Stated where a store publishes no value at all, per UXV-022.
const UNAVAILABLE: String = "unavailable"
## UXV-019: an age field does not exist in `residents.gd`. Named, never guessed from arrival.
const AGE_UNAVAILABLE: String = "Age unavailable: no age or birth field exists"
## ART-UI-06/UXV-019: the medallion is a species mark and must never read as a portrait.
const EMBLEM_NOTE: String = "Species emblem is a generic mark, not a portrait of this resident."

## `needs.gd`'s ResidentStatus values in order, as player-facing words.
const STATUS_WORDS: Array[String] = [
	"Active", "Resting", "Injured", "Incapacitated", "Leaving", "Dead", "Transferred",
]
## `residents.gd`'s Role values in order.
const ROLE_WORDS: Array[String] = ["Resident", "Warden", "Specialist"]
## GDD §4.3 JobKind, in ordinal order. RESERVED_3 carries no job and is named as reserved.
const JOB_KIND_WORDS: Array[String] = [
	"Hauling", "Building", "Fishing", "Reserved", "Foraging", "Farming",
	"Cooking", "Preserving", "Crafting", "Tending", "Keeping", "Healing",
]
## What the activity row says when the job store holds no agent row for this resident.
const NO_JOB_AGENT: String = "no job agent"
const JOB_IDLE: String = "idle"

# --- medallions ---------------------------------------------------------------------------

## ART-LOCK-001 §5 delivers four generic species medallions and no others.
const EMBLEM_SPECIES: Array[StringName] = [&"mouse", &"mole", &"otter", &"squirrel"]
## "Actual production sizes are 48/64px." The 24 px reduction is a diagnostic species test and
## is deliberately NOT offered here, because it is not an authorized portrait size.
const EMBLEM_SIZES: Array[int] = [48, 64]
const EMBLEM_ID_PREFIX: String = "ART.EMBLEM."

const REFUSE_NONE: StringName = &""
const REFUSE_NO_STORES: StringName = &"UI_CARD_NO_STORES"
const REFUSE_NOT_A_RESIDENT: StringName = &"UI_CARD_NOT_A_RESIDENT"
const REFUSE_NEED_OUT_OF_RANGE: StringName = &"UI_CARD_NEED_OUT_OF_RANGE"


class Row:
	"""One UI-SET-039 need row: its label, its exact percent, its rate and its track fraction."""
	var label: String = ""
	var value_text: String = ""
	var rate_text: String = ""
	var has_rate: bool = false
	## The store's own 0-10000 value, for the 8 px track. Never shown as a number.
	var basis_points: int = 0
	var accessible: String = ""


var _rows: Array[Row] = []
var _last_refusal: StringName = REFUSE_NONE
## Reused readers, so filling the five rows allocates nothing.
var _need: IntMath.IntResult = IntMath.IntResult.new()
## The standing refusal handed back for the four needs whose rate `needs.gd` does not publish.
var _no_rate: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Build the five need rows once. Nothing here allocates again."""
	for index: int in NeedsScript.NEED_COUNT:
		_rows.append(Row.new())


# --- exact formatting ---------------------------------------------------------------------

static func is_basis_points(value: int) -> bool:
	"""True for a value on `needs.gd`'s 0-10000 scale. Callers check BEFORE formatting."""
	return value >= NeedsScript.NEED_MIN and value <= NeedsScript.NEED_MAX


static func percent_text(basis_points: int) -> String:
	"""UXV-020's exact percent: 7500 to "75%", 7501 to "75.01%", 0 to "0%", 10000 to "100%".

	Integer arithmetic throughout, with trailing zeroes trimmed. `is_basis_points()` is the
	precondition; an out-of-range value is an invariant violation, not a display case, so this
	asserts rather than inventing a printable number for it.
	"""
	assert(is_basis_points(basis_points), "percent_text() requires 0-10000 basis points")
	var whole: int = basis_points / BASIS_POINTS_PER_PERCENT
	var fraction: int = basis_points % BASIS_POINTS_PER_PERCENT
	if fraction == 0:
		return "%d%%" % whole
	if fraction % 10 == 0:
		return "%d.%d%%" % [whole, fraction / 10]
	return "%d.%02d%%" % [whole, fraction]


static func rate_hundredths(milli_points_per_hour: int) -> int:
	"""A milli-need-point/hour rate as hundredths of a percentage point per hour.

	§5: "display-only rounding is nearest with ties away from zero". -250000 milli/hour is
	-250 hundredths, which prints as -2.50 pp/h -- the amendment's own worked example.
	"""
	var magnitude: int = absi(milli_points_per_hour)
	var rounded: int = (magnitude + MILLI_PER_RATE_HUNDREDTH / 2) / MILLI_PER_RATE_HUNDREDTH
	return -rounded if milli_points_per_hour < 0 else rounded


static func rate_text(milli_points_per_hour: int) -> String:
	"""A signed per-simulated-hour change in percentage points, to two decimals."""
	var hundredths: int = rate_hundredths(milli_points_per_hour)
	var magnitude: int = absi(hundredths)
	var body: String = "%d.%02d pp/h" % [magnitude / HUNDREDTHS, magnitude % HUNDREDTHS]
	if hundredths == 0:
		return body
	return ("-" if hundredths < 0 else "+") + body


# --- medallions ---------------------------------------------------------------------------

static func has_emblem(species_key: StringName) -> bool:
	"""True when ART-LOCK-001 §5 delivers a generic medallion for this species."""
	return EMBLEM_SPECIES.has(species_key)


static func emblem_pixels_for_width(detail_width: float) -> int:
	"""48 for the narrow and standard detail columns, 64 for the wide one.

	Both are ART-LOCK-001's production sizes. §1.2's detail widths are 320/336/384, so the wide
	column is the only one with room for the 64 px roundel beside a 20 px heading.
	"""
	return EMBLEM_SIZES[1] if detail_width >= 384.0 else EMBLEM_SIZES[0]


static func emblem_path(species_key: StringName, pixels: int) -> String:
	"""The medallion source for a species at a production size, or "" when there is none.

	"" means ART-LOCK-001 delivers no medallion for that species or that size -- the twelve
	species outside the four founding ones, and every size that is not 48 or 64. It is an
	answer about the art registry, not a failure code: `has_emblem()` asks the same question
	without needing a string back.
	"""
	if not has_emblem(species_key) or not EMBLEM_SIZES.has(pixels):
		return ""
	var asset_id: StringName = StringName("%s%s_%d"
		% [EMBLEM_ID_PREFIX, String(species_key).to_upper(), pixels])
	if not UiArt.has_asset_id(asset_id):
		return ""
	return UiArt.source_path_of(UiArt.ASSET_ID.find(asset_id))


static func emblem_description(species_key: StringName) -> String:
	"""What the medallion IS, for the panel's accessible description. Never a name."""
	return "Generic %s species emblem; not a portrait of this resident." % species_key


# --- identity, health, activity and skills ------------------------------------------------

static func heading_text(residents: ResidentsScript, slot: int) -> String:
	"""UXV-019's heading: the full persisted display name, alone on its own line."""
	if residents.is_named(slot):
		return String(residents.name_key_of(slot))
	return UNNAMED_HEADING


static func species_text(residents: ResidentsScript, slot: int) -> String:
	"""The resident's species key, or that the store refused to publish one."""
	var species: IntMath.IntResult = residents.species_of(slot)
	if not species.ok:
		return UNAVAILABLE
	var key: StringName = residents.species_key(species.value)
	return UNAVAILABLE if key == &"" else String(key)


static func identity_text(residents: ResidentsScript, needs: NeedsScript, slot: int) -> String:
	"""UXV-019's second line: actual species, role and status. Age is separately unavailable."""
	var role: IntMath.IntResult = residents.role_of(slot)
	var status: IntMath.IntResult = needs.status_of(slot)
	var role_word: String = ROLE_WORDS[role.value] if role.ok else UNAVAILABLE
	var status_word: String = STATUS_WORDS[status.value] if status.ok else UNAVAILABLE
	return "%s - %s - %s" % [species_text(residents, slot), role_word, status_word]


static func health_text(needs: NeedsScript, slot: int) -> String:
	"""§5: "Health remains 0-100, e.g. 100 / 100". Not a percent, and not basis points."""
	var health: IntMath.IntResult = needs.health_of(slot)
	if not health.ok:
		return "Health %s" % UNAVAILABLE
	return "Health %d / %d" % [health.value, NeedsScript.HEALTH_MAX]


static func activity_text(needs: NeedsScript, jobs: JobsScript, slot: int) -> String:
	"""UXV-022's current activity from actual fields: the published status and job assignment.

	`needs.gd` exposes ResidentStatus and nothing finer -- its `_activity` column, which knows
	awake from asleep in a bed, has a setter and no reader. So this states the status the store
	does publish, and the job store's own answer about whether this resident holds a job.
	"""
	var status: IntMath.IntResult = needs.status_of(slot)
	var word: String = STATUS_WORDS[status.value] if status.ok else UNAVAILABLE
	return "Activity: %s, %s" % [word, _job_phrase(jobs, slot)]


static func _job_phrase(jobs: JobsScript, slot: int) -> String:
	"""What the job store says this resident is assigned to, or that it holds no agent row."""
	if jobs == null or not jobs.is_agent_present(slot):
		return NO_JOB_AGENT
	var job: Vector2i = jobs.job_of(slot)
	if job == JobsScript.NULL_REF:
		return JOB_IDLE
	var kind: IntMath.IntResult = jobs.kind_of(job.x)
	if not kind.ok or kind.value < 0 or kind.value >= JOB_KIND_WORDS.size():
		return UNAVAILABLE
	return JOB_KIND_WORDS[kind.value]


static func skill_text(residents: ResidentsScript, slot: int, skill: int) -> String:
	"""UXV-022: level, exact accumulated XP and the next level's threshold.

	GDD §5.3 puts level L's start at 5000*L*L XP, so the next threshold is exact arithmetic on
	the published level. At level 10 there is no next threshold and the row says Max level.
	"""
	var level: IntMath.IntResult = residents.skill_level_of(slot, skill)
	var xp: IntMath.IntResult = residents.skill_xp_of(slot, skill)
	if not level.ok or not xp.ok:
		return "Foraging %s" % UNAVAILABLE
	if level.value >= ResidentsScript.SKILL_LEVEL_MAX:
		return "Foraging: max level, %d XP" % xp.value
	var next: int = ResidentsScript.SKILL_XP_PER_LEVEL_SQUARE \
		* (level.value + 1) * (level.value + 1)
	return "Foraging: level %d, %d / %d XP" % [level.value, xp.value, next]


# --- the five rows ------------------------------------------------------------------------

func fill_needs(residents: ResidentsScript, needs: NeedsScript, slot: int) -> bool:
	"""Write all five UI-SET-039 rows for one resident. Refuses by name; fills nothing on refusal.

	Every row is filled from the store in one pass. A need outside 0-10000 is a store invariant
	violation and refuses the WHOLE card rather than printing four good rows and one wrong one.
	"""
	if residents == null or needs == null:
		return _refuse(REFUSE_NO_STORES)
	if not needs.is_alive(slot) or not residents.is_alive(slot):
		return _refuse(REFUSE_NOT_A_RESIDENT)
	for need: int in NeedsScript.NEED_COUNT:
		if not needs.need_into(slot, need, _need) or not is_basis_points(_need.value):
			return _refuse(REFUSE_NEED_OUT_OF_RANGE)
	for need: int in NeedsScript.NEED_COUNT:
		needs.need_into(slot, need, _need)
		_write_row(_rows[need], need, _need.value, _rate_milli_of(needs, slot, need))
	_last_refusal = REFUSE_NONE
	return true


func _write_row(row: Row, need: int, basis_points: int, rate_milli: IntMath.IntResult) -> void:
	"""Fill one row from an already-validated need value and its rate, published or not."""
	row.label = NEED_LABELS[need]
	row.basis_points = basis_points
	row.value_text = percent_text(basis_points)
	row.has_rate = rate_milli.ok
	row.rate_text = rate_text(rate_milli.value) if rate_milli.ok else RATE_UNAVAILABLE
	var detail: String = row.rate_text if rate_milli.ok else RATE_UNAVAILABLE_REASON
	row.accessible = "%s, field %s, %s, %s" \
		% [row.label, NEED_FIELDS[need], row.value_text, detail]


func _rate_milli_of(needs: NeedsScript, slot: int, need: int) -> IntMath.IntResult:
	"""The effective signed rate in milli-need-points per game hour, where one is published.

	Only hunger's is. `needs.gd` applies it as `-_hunger_rate_milli[size_class]`, so the sign is
	restored here rather than being guessed; the magnitude already carries the size and winter
	multipliers. The other four refuse, and `_write_row()` prints RATE_UNAVAILABLE for them.
	"""
	if need != NeedsScript.NEED_HUNGER:
		_no_rate.refuse(String(RATE_UNAVAILABLE))
		return _no_rate
	var size_class: IntMath.IntResult = needs.size_class_of(slot)
	if not size_class.ok:
		return size_class
	var rate: IntMath.IntResult = needs.hunger_rate_milli_per_hour(size_class.value)
	if not rate.ok:
		return rate
	rate.value = -rate.value
	return rate


func row(index: int) -> Row:
	"""One filled need row. Callers pass a `NeedsScript.NEED_*` index."""
	return _rows[index]


func row_count() -> int:
	"""How many need rows this card composes. GDD §4.2 fixes five."""
	return _rows.size()


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
