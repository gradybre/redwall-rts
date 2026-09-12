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
## ALL FIVE RATES NOW BIND, AND NOT ONE OF THEM IS COMPUTED HERE. §5 requires "current
## per-simulated-hour change" and says, in terms, "If rate isn't published, say Rate
## unavailable". For a long time four rows said exactly that: `needs.gd` computed all five
## effective rates in the PRIVATE `_fill_need_rates()` and published only
## `hunger_rate_milli_per_hour(size_class)`, and substituting the baseline decay for the other
## four would have been "the baseline formula as a universal answer" -- a resident asleep in a
## bed shown losing rest.
##
## NEED-RATE-R01 closed that interface gap. `needs.gd` now publishes four signed net readers,
## `ui_resident_snapshot.gd` validates the selected reference and copies all five at one
## boundary, and `ui_need_rate.gd` formats them. This file OWNS NO RATE ARITHMETIC: the ruling
## forbids the UI recreating those formulas or reading private columns, so `fill_needs()` is a
## transfer and nothing else. `RATE_UNAVAILABLE` survives for a genuinely failed binding only.
##
## The signs are asymmetric and that asymmetry is the store's. The four new readers are already
## signed net rates and must not be negated again; `hunger_rate_milli_per_hour()` deliberately
## keeps its established POSITIVE decay magnitude, and the snapshot forms `R = -magnitude` once.
##
## ---------------------------------------------------------------------------------------
## WHAT IS STILL GENUINELY ABSENT, stated rather than filled in with a plausible zero:
##   * AGE. `residents.gd` stores species, size, role, name, arrival tick, home, bed, skills
##     and equipment. There is no age column and no birth tick, so UXV-019's "age" is
##     unavailable; `arrival_tick_of()` is an arrival, not an age, and is not relabelled as one.
##   * CENTER VIEW'S CAMERA. UI-IDENTITY-R01 requires the 44-high action in the 64 px footer to
##     stay visible, and `ui_shell.gd` builds and labels it. It is DISABLED, carrying
##     `ui_availability.gd`'s REASON_NO_WORLD_CAMERA -- "the interface binds no camera". The
##     action exists; the camera binding is still reported rather than invented.
##
## No allocation happens per row read: the five Row objects are built once in `_init()`.

const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const UiArt := preload("res://ui/ui_art.gd")
const UiNeedRate := preload("res://scripts/ui/ui_need_rate.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const UiResidentSnapshot := preload("res://scripts/ui/ui_resident_snapshot.gd")

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
## The one validated boundary every filled row comes from. Built once; `capture()` reuses it.
var _snapshot: UiResidentSnapshot = UiResidentSnapshot.new()


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
	"""UI-IDENTITY-R01's medallion column: 48 at NARROW, 64 at STANDARD and WIDE.

	Both are ART-LOCK-001's production sizes. This CHANGED with the 2026-09-12 ruling. The old
	rule gave 64 only to the 384 px wide column, because the roundel then had to share the row
	with a heading whose §4 minimum was 280 px. The ruling overrides that minimum for this
	template -- "allocate exactly the remaining 172/172/220px" -- and publishes the medallion
	column directly: 48/64/64. `ui_resident_header.gd` holds the same table keyed on the profile
	and derives it from the row equation; this width-keyed form is what the manager already
	calls, and §1.2's detail widths 320/336/384 map one-to-one onto those profiles.
	"""
	return EMBLEM_SIZES[1] if detail_width >= 336.0 else EMBLEM_SIZES[0]


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
	"""Write all five UI-SET-039 rows for the resident in one store row. Refuses by name.

	A slot alone is not an identity. This resolves the row's own `(slot, generation)` reference
	and hands THAT to `fill_needs_for()`, so even the slot-keyed call goes through the
	directory's full ARCH-ID-003 check rather than trusting an index a caller carried in.
	"""
	if residents == null or needs == null:
		return _refuse(REFUSE_NO_STORES)
	if not residents.is_alive(slot):
		return _refuse(REFUSE_NOT_A_RESIDENT)
	return fill_needs_for(residents.directory(), residents, needs, residents.ref_of(slot))


func fill_needs_for(directory: EntityDirectoryScript, residents: ResidentsScript,
		needs: NeedsScript, ref: Vector2i) -> bool:
	"""NEED-RATE-R01's boundary: validate the selected reference, then copy five rows from it.

	This is the entry point the ruling describes -- "The snapshot owner FIRST validates the
	selected EntityRef/generation through the directory and resolves its RESIDENT typed row,
	THEN copies values and rates at one completed-state boundary." Every row comes from that one
	capture, so five rows cannot describe two residents.

	No rate is computed here. `ui_resident_snapshot.gd` reads `needs.gd`'s five public readers
	and `ui_need_rate.gd` formats what they said; this copies the finished row across.
	"""
	if not _snapshot.capture(directory, residents, needs, ref):
		return _refuse(_snapshot.last_refusal())
	for need: int in NeedsScript.NEED_COUNT:
		_copy_row(_rows[need], _snapshot.row(need))
	_last_refusal = REFUSE_NONE
	return true


func _copy_row(row: Row, captured: UiResidentSnapshot.NeedRow) -> void:
	"""Copy one captured row into the card's own row. Nothing is recomputed in the transfer."""
	row.label = captured.label
	row.basis_points = captured.basis_points
	row.value_text = captured.value_text
	row.has_rate = captured.has_rate
	row.rate_text = captured.rate_text
	row.accessible = captured.accessible


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
