extends RefCounted
## The residents store: one row per creature, and the GDD §5.8 daily food demand it supplies.
##
## This module owns the GDD §4.2 `Resident` and `Skills` components and nothing else. It does
## not allocate slots and it does not integrate needs:
##   * `entity_directory.gd` owns slot allocation, `(slot, generation)` refs, the 512 RESIDENT
##     rows and the 256 living cap. Every spawn here goes through `create(KIND_RESIDENT)`, so
##     there is exactly one allocator and one generation counter.
##   * `needs.gd` owns the per-resident needs/health/cold columns and their integrator. A spawn
##     here attaches a needs row at the same typed slot; decay is never reimplemented.
##   * `catalog.gd` compiles the SpeciesDefinition ids. They are NOT hand numbered: GDD §4.2's
##     closing paragraph assigns unlisted enum values from ascending ASCII key order, so
##     `badger` is 0 and `mouse` is 7, not the §4.3 sentence order.
##
## WHAT THIS SUPPLIES. GDD §5.8's food-days figure is
## `floor(100*sum(edible_unreserved_NP)/daily_demand_NP)/100`. `economy_system.gd` already
## computed the numerator. `daily_demand_np()` here is the denominator: each LIVING resident's
## baseline requirement scaled by the §5.2 size multiplier and today's season multiplier.
## Wounded residents still count (§5.8); dead rows do not.
##
## GAPS -- named, not invented (AGENTS.md "do not invent a constant"):
##   * `home` and `bed` stay null `(-1, 0)`. GDD §5.1 places 12 beds in a refuge hall and
##     assigns them "resident ID ascending and bed ID ascending", but no Building, Room or
##     Furniture store exists in this milestone, so there is no bed to reference.
##   * Relationships (the §5.1 edges (1,2)...(11,12) at affinity 20), Priorities, Schedule and
##     MoodMemory are separate §4.2 components with no store yet.
##
## THE EQUIPMENT MIRROR (decision 0061) IS NOW HERE, and only the part §4.2 actually names.
## GDD §4.2 `Equipment` is `tool_item_id, tool_durability, clothing_tier, satchel:EntityRef`,
## ledgered once in `systems_architecture.md` §3 as five I32 columns at length 512. Four of them
## live below. The fifth, `clothing_tier`, ALREADY lives in `needs.gd`, which owns warmth and
## mood and applies tier 1 at spawn; duplicating it here would be the second copy READY_07 §7.2
## step 2 forbids ("do not bill those original fields a second time"), so the mirror allocates
## 8192 of the ledgered 10240 bytes and the ledger total does not move.
##
## THE MIRROR IS NOT AUTHORITATIVE. `GearInstance.durability` in `gear.gd` is (ARCH-STATE-001);
## these columns are the resident-side view of it that eligibility gates read. `gear.gd` is the
## only writer: it funnels every durability change through one private setter that writes through
## here, and `gear.audit_equipment_mirror()` re-derives every row from the gear store and refuses
## on divergence. Writing `set_equipped_tool()` from anywhere else produces a state that audit
## rejects -- which is the point: a mirror that can silently disagree is the same defect class as
## counting one lot twice.
##   * §5.1 lists the starting cohort as "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels);
##     IDs 1-12" without stating which ID gets which species. INITIAL_SPECIES below takes the
##     sentence's own order. The §7.1 starter fixture depends only on the 10-small/2-medium
##     split, which every ordering produces, so the food-days arithmetic does not rest on this
##     reading -- but a later spec revision could reorder the individuals.
##
## LIFE STAGE (MOVE-DEP-R02; GDD §4.2 as amended 2026-09-12; DEC-032). `_life_stage` is a B8
## column at length 512 carrying the FIXED, BOUNDED domain ADULT 0, CHILD 1, ELDER 2. COUNT 3 is
## a bound and is never stored. It is assigned once at creation and there is deliberately NO
## setter: release 1 introduces no birth, no aging timer, no adulthood transition and no
## age-based death, so a post-creation stage write would be a rule this repository does not have.
## `spawn_with_stage()` is the generic entry and requires an explicit validated stage;
## `spawn()` is the ADULT-only convenience that passes `LIFE_STAGE_ADULT` by name, which is what
## preserves `movement.gd`'s current "adult 0 is the only profiled stage". Free rows hold 0 and
## are distinguished by `_present`/the directory generation, never by their stage byte.
##
## WHAT LIFE STAGE DOES NOT DO. It does not enable dependent simulation. PC-04 owns child/elder
## needs, care, schedule, work and hazard rules and none of them exist, so nothing here derives a
## child or elder coefficient from an adult one. `movement.gd` still refuses any stage but ADULT
## because `_profile_life_stage` (MOVE-DEP-R02's +4-byte starter-catalog column) is that module's
## to add; this store answers what a resident's stage IS, and the profile owner answers whether
## that stage may travel. Storing CHILD is therefore legal and travelling as one is not.
##
## RIG IDENTITY (MOVE-DEP-R03; `docs/planning/species_rig_identity.json`). §4.3's
## `SpeciesDefinition.rig_id` now has its sixteen values. They are LOGICAL BASE/ADULT identities:
## naming `rig_mouse_v1` asserts no skeleton, clip, palette or export exists. The keys compile
## through `catalog.gd` as their own RigDefinition domain in ascending ASCII order, exactly like
## the species keys, and each species binds to one by its own key. There is no per-resident rig
## column; a rig is a property of the species row.
##   * Child and elder render variants need explicit `(species, life_stage)` bindings. None is
##     authored anywhere, so `rig_binding()` REFUSES them rather than handing back the adult rig.
##   * That refusal is a presentation/export gap and NOT an admission gate. A CHILD mouse spawns
##     and is legal simulation state with no rig binding at all; the 2026-09-12 executor
##     follow-up is explicit that "a missing rig is a presentation/export gap, not authority to
##     deny legal simulation". `spawn_with_stage()` never consults the rig tables.
##
## PERSONAL NAMES (NAME-R02, 2026-09-12). This store owns the ONE validator every naming path
## shares: `set_name()`, `restore_name()`, `command_dispatch.gd`'s NAME_RESIDENT arm, the §5.1
## automatic Warden assignment and `save_section_name_pool.gd`'s capture and restore all reach
## `name_refusal()`, and none of them carries a second copy of the rules. Before NAME-R02 this
## setter validated NOTHING -- it stored any StringName and derived `_named` from emptiness -- so
## a live row could hold a name the section 14 codec was then obliged to refuse. That asymmetry
## was the ruling's blocker N3 and it is closed here, not at the wire.
##
## The occupancy table is `name_occupancy_refusal()` and it is checked as a PAIR. A derived flag
## can only ever produce agreement, so it can only ever conceal a disagreement; `restore_name()`
## exists precisely so a save's `(named, name)` halves are validated against each other instead
## of one being recomputed from the other. Liveness is never consulted: a retained dead or
## departed row keeps its identity.
##
## MOVE-DEP-R02 requires the stage column to be persisted and hashed in save section §4 with an
## owner/schema increment. Decision 0132 adds the STORE half of that -- `copy_columns_into()` and
## `restore_columns()` below carry `_life_stage` as one of the nineteen §4 columns, in the
## registry's ordinal order -- and it infers nothing: the stage arrives in the column set or the
## call refuses, and no row is repaired to ADULT. The MIGRATION half is still not this module's
## and is still unwritten: refusing a PRE-COLUMN schema is the §4 codec's job through
## `owner_schema_version`, because this store is handed a column set and cannot see which schema
## version produced it. "Do not infer an arbitrary loaded resident is adult" holds either way.
##
## STILL MISSING, reported not invented: there is no §4 codec in this repository yet (see
## `docs/persistence_state_registry.md`'s "Blocked" section), so nothing reads or writes the wire
## bytes these columns travel as.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

## Resident typed rows, GDD §4.1: storage 512, living population never above 256.
const RESIDENT_CAPACITY: int = 512
const RESIDENT_LIVING_CAP: int = 256

# --- species catalog, GDD §4.3 --------------------------------------------------------------

const SPECIES_DOMAIN: String = "SpeciesDefinition"

## "Species catalog release 1: mouse, shrew, mole, ... wolverine", split by the following
## sentence: "Small species are the first six, medium the next six, large the last four."
const SPECIES_SMALL_KEYS: Array[StringName] = [
	&"mouse", &"shrew", &"mole", &"rat", &"squirrel", &"sparrow",
]
const SPECIES_MEDIUM_KEYS: Array[StringName] = [
	&"otter", &"hare", &"ferret", &"weasel", &"hedgehog", &"kestrel",
]
const SPECIES_LARGE_KEYS: Array[StringName] = [&"badger", &"fox", &"wildcat", &"wolverine"]

const SPECIES_COUNT: int = 16

# --- life stage, MOVE-DEP-R02 / GDD §4.2 (2026-09-12) ---------------------------------------

## The whole stage domain. Fixed and bounded, never an open enum: MOVE-DEP-R02 states the
## encoding is stable and that COUNT "is a bound, never a stored stage".
const LIFE_STAGE_ADULT: int = 0
const LIFE_STAGE_CHILD: int = 1
const LIFE_STAGE_ELDER: int = 2
const LIFE_STAGE_COUNT: int = 3

## Display/report names, indexed by the stage value. NOT a compiled catalog domain: §4.3 numbers
## this enum explicitly, so it is protected data and must never be renumbered from key order.
const LIFE_STAGE_KEYS: Array[StringName] = [&"ADULT", &"CHILD", &"ELDER"]

# --- logical rig identity, MOVE-DEP-R03 -----------------------------------------------------

const RIG_DOMAIN: String = "RigDefinition"

## MOVE-DEP-R03's table verbatim, one logical base/adult rig key per §4.3 species key. These are
## identities, not assets: none of the sixteen is claimed to have a skeleton or a clip.
const SPECIES_RIG_KEY: Dictionary = {
	&"badger": &"rig_badger_v1",
	&"ferret": &"rig_ferret_v1",
	&"fox": &"rig_fox_v1",
	&"hare": &"rig_hare_v1",
	&"hedgehog": &"rig_hedgehog_v1",
	&"kestrel": &"rig_kestrel_v1",
	&"mole": &"rig_mole_v1",
	&"mouse": &"rig_mouse_v1",
	&"otter": &"rig_otter_v1",
	&"rat": &"rig_rat_v1",
	&"shrew": &"rig_shrew_v1",
	&"sparrow": &"rig_sparrow_v1",
	&"squirrel": &"rig_squirrel_v1",
	&"weasel": &"rig_weasel_v1",
	&"wildcat": &"rig_wildcat_v1",
	&"wolverine": &"rig_wolverine_v1",
}

## One rig per species in release 1. A shared rig would make this smaller, and MOVE-DEP-R03
## forbids assuming one: "equal bone names alone do not establish compatible bindings".
const RIG_COUNT: int = 16

## Size classes, matching needs.gd so one resident has one size everywhere.
const SIZE_SMALL: int = NeedsScript.SIZE_SMALL
const SIZE_MEDIUM: int = NeedsScript.SIZE_MEDIUM
const SIZE_LARGE: int = NeedsScript.SIZE_LARGE
const SIZE_COUNT: int = NeedsScript.SIZE_COUNT

## GDD §5.2: "Small size multiplier 1000, medium 1200, large 1600, denominator 1000."
const SIZE_MULTIPLIER: Array[int] = NeedsScript.SIZE_MULTIPLIER
const SIZE_DENOMINATOR: int = NeedsScript.SIZE_DENOMINATOR

## GDD §5.2: "Carry capacities 12000/16000/24000 g; movement caps 3277/4096/3072 u/second."
## The large movement cap is genuinely below the medium one in the specification; it is copied,
## not corrected.
const SIZE_CARRY_G: Array[int] = [12000, 16000, 24000]
const SIZE_MOVEMENT_U_PER_S: Array[int] = [3277, 4096, 3072]

# --- daily nutrition demand, GDD §4.1 / §5.2 / §5.8 -----------------------------------------

## GDD §4.1: "small resident requires 6000/day at baseline".
const BASE_NUTRITION_PER_DAY_NP: int = 6000

## GDD §5.2 hunger row: "250 x size multiplier; winter x1.20". Non-winter seasons do not scale.
const SEASON_MULTIPLIER_WINTER: int = NeedsScript.WINTER_HUNGER_MULTIPLIER
const SEASON_MULTIPLIER_DEFAULT: int = NeedsScript.SEASON_DENOMINATOR
const SEASON_DENOMINATOR: int = NeedsScript.SEASON_DENOMINATOR

## One divisor for the compound size x season multiplication, applied after both multiplies so
## the §5.2 "compound multipliers are applied in int64 before division" rule holds.
const DEMAND_DENOMINATOR: int = SIZE_DENOMINATOR * SEASON_DENOMINATOR

# --- roles and skills, GDD §4.3 / §5.3 ------------------------------------------------------

const ROLE_RESIDENT: int = 0
const ROLE_WARDEN: int = 1
const ROLE_SPECIALIST: int = 2
const ROLE_COUNT: int = 3

## GDD §4.2 `Skills`: one fixed 12-column set per resident, indexed by JobKind.
const SKILL_COUNT: int = 12
const SKILL_KEEP: int = 10
## JobKind.RESERVED_3 carries no XP and no level (§5.1).
const SKILL_RESERVED_INDEX: int = 3

const SKILL_LEVEL_MAX: int = 10
## GDD §5.3: level = min(10, floor_sqrt(floor(xp/5000))), i.e. level L starts at 5000*L*L XP.
const SKILL_XP_PER_LEVEL_SQUARE: int = 5000

# --- initial settlement, GDD §5.1 -----------------------------------------------------------

## "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels); IDs 1-12" in the order written.
const INITIAL_SPECIES: Array[StringName] = [
	&"mouse", &"mouse", &"mouse", &"mouse", &"mouse", &"mouse",
	&"mole", &"mole", &"otter", &"otter", &"squirrel", &"squirrel",
]
const INITIAL_POPULATION: int = 12

## "ID 1 named Warden Rowan". The localization key format is unspecified, so the authored name
## is stored verbatim rather than as an invented key id.
const WARDEN_INDEX: int = 0
const WARDEN_NAME: StringName = &"Warden Rowan"

## "Warden KEEP XP=45000; other active initial skills XP=20000; reserved index 3 XP=0."
const INITIAL_ACTIVE_SKILL_XP: int = 20000
const WARDEN_KEEP_XP: int = 45000

## Starters exist from the first tick; GDD §5.1 puts tick 0 at 06:00 on day 1.
const INITIAL_ARRIVAL_TICK: int = 0

const NO_NAME_KEY: StringName = &""
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- personal names, NAME-R02 (2026-09-12) --------------------------------------------------

## NAME-R02 corrects SAVE-R09-002. The whole occupancy/name table, which is what makes a live
## anonymous resident legal:
##
##   | Resident row                                  | `_named` | `_name_key`                 |
##   |-----------------------------------------------|---------:|-----------------------------|
##   | Free                                          |        0 | empty                       |
##   | Present anonymous, INCLUDING a live resident   |        0 | empty                       |
##   | Present named                                 |        1 | nonempty valid personal name|
##
## The earlier reading -- "a live resident cannot load an empty name" taken literally -- refused
## the GDD §5.1 starter settlement outright: REQ-SET-040 makes naming trigger-based and eleven of
## the twelve founders are anonymous. A retained dead or departed row follows its own occupancy
## rule and keeps whatever identity it had; nothing here erases a name because `is_alive()` is
## false.

## SAVE-R09-002's S2 answer: at most 128 encoded UTF-8 bytes.
const NAME_MAX_UTF8_BYTES: int = 128
## ARCH-SAVE-005: 2-32 UNICODE SCALAR VALUES. Not bytes and not grapheme clusters -- the three
## differ, and NAME-R02 names counting either of the other two as the trap.
const NAME_MIN_SCALARS: int = 2
const NAME_MAX_SCALARS: int = 32

## Unicode general category Cc, written out as explicit bounds. NAME-R02: "This is an explicit
## control-code predicate, not an unversioned call to an engine Unicode category database", so
## the rule cannot change under this store when an engine upgrade reclassifies anything.
const CONTROL_C0_MAX: int = 0x1f
const CONTROL_DEL: int = 0x7f
const CONTROL_C1_MAX: int = 0x9f

## The strict-UTF-8 encodable range: a Unicode scalar value is 0..0x10FFFF excluding the
## surrogate block. A code point outside it has no strict UTF-8 encoding at all, so it can never
## reach the save arena and is refused here rather than replaced.
const UNICODE_SCALAR_MAX: int = 0x10ffff
const SURROGATE_MIN: int = 0xd800
const SURROGATE_MAX: int = 0xdfff

## The three strict-UTF-8 width boundaries, so `utf8_byte_length_of()` is arithmetic rather than
## an encode into a throwaway buffer.
const UTF8_ONE_BYTE_MAX: int = 0x7f
const UTF8_TWO_BYTE_MAX: int = 0x7ff
const UTF8_THREE_BYTE_MAX: int = 0xffff

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
const REFUSE_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
const REFUSE_UNKNOWN_SPECIES: StringName = &"UNKNOWN_SPECIES"
const REFUSE_INVALID_ROLE: StringName = &"INVALID_ROLE"
const REFUSE_INVALID_SKILL: StringName = &"INVALID_SKILL"
const REFUSE_INVALID_XP: StringName = &"INVALID_XP"
const REFUSE_INVALID_COUNT: StringName = &"INVALID_COUNT"
## NAME-R02's five name refusals. Five codes and not one, because a load report that said only
## "bad name" could not tell an over-long alias from a corrupted flag/string pair.
const REFUSE_NAME_BYTES: StringName = &"NAME_OVER_BYTE_CAP"
const REFUSE_NAME_SCALARS: StringName = &"NAME_SCALAR_COUNT"
const REFUSE_NAME_CONTROL: StringName = &"NAME_CONTROL_CHARACTER"
const REFUSE_NAME_NOT_UTF8: StringName = &"NAME_NOT_STRICT_UTF8"
## The occupancy half of the table: a named row cannot be empty, an anonymous row cannot hide a
## name, and a free row can carry neither.
const REFUSE_NAMED_ROW_EMPTY: StringName = &"NAMED_ROW_EMPTY_NAME"
const REFUSE_ANONYMOUS_ROW_NAMED: StringName = &"ANONYMOUS_ROW_HAS_NAME"
const REFUSE_FREE_ROW_NAMED: StringName = &"FREE_ROW_HAS_NAME"
const REFUSE_RESERVED_SKILL: StringName = &"RESERVED_SKILL_INDEX"
const REFUSE_SETTLEMENT_NOT_EMPTY: StringName = &"SETTLEMENT_NOT_EMPTY"
const REFUSE_NO_LIVING_RESIDENTS: StringName = &"NO_LIVING_RESIDENTS"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_SPECIES_CATALOG: StringName = &"SPECIES_CATALOG_INVALID"
const REFUSE_NO_EQUIPPED_TOOL: StringName = &"NO_EQUIPPED_TOOL"
const REFUSE_TOOL_ALREADY_EQUIPPED: StringName = &"TOOL_ALREADY_EQUIPPED"
const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
const REFUSE_INVALID_DURABILITY: StringName = &"INVALID_DURABILITY"
const REFUSE_INVALID_CONTAINER: StringName = &"INVALID_CONTAINER"
## MOVE-DEP-R02: a stage outside 0..2. Refused, never clamped to ADULT.
const REFUSE_INVALID_LIFE_STAGE: StringName = &"INVALID_LIFE_STAGE"
## A `(slot, generation)` pair the DIRECTORY no longer validates, or one of the wrong kind.
const REFUSE_STALE_REF: StringName = &"STALE_RESIDENT_REF"
## A malformed reference: a non-null pair whose slot is negative or whose generation is <= 0.
const REFUSE_INVALID_REF: StringName = &"INVALID_REF"
## MOVE-DEP-R03: no `(species, life_stage)` rig variant is authored for a non-adult stage.
const REFUSE_RIG_STAGE_UNBOUND: StringName = &"RIG_STAGE_VARIANT_UNBOUND"
## The RigDefinition domain failed to compile, so no rig identity can be answered at all.
const REFUSE_RIG_CATALOG: StringName = &"RIG_CATALOG_INVALID"
## The key is not one of the sixteen compiled rig identities.
const REFUSE_UNKNOWN_RIG: StringName = &"UNKNOWN_RIG"

## GDD §4.2 `Equipment`: four of its five I32 columns at length 512 (`clothing_tier` stays in
## `needs.gd`; see the header). Re-derived by `equipment_payload_bytes()`.
const EQUIPMENT_MIRROR_COLUMNS: int = 4
const EQUIPMENT_MIRROR_BYTES: int = 4 * EQUIPMENT_MIRROR_COLUMNS * RESIDENT_CAPACITY
## "No tool equipped". A cleared column value, never a refusal channel: `has_equipped_tool()`
## answers the question and every reader is an explicit `_into`/OpResult form.
const NO_TOOL_ITEM: int = -1


class OpResult:
	"""Outcome of one residents operation: success flag, refusal code, value and reference.

	`.ok` MUST be inspected before `.value` or `.ref` is used. A refusal always carries value 0
	and the null reference, and never a partially applied effect.
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


# --- collaborators ---------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _needs: NeedsScript = null
var _owns_collaborators: bool = false

# --- compiled species catalog ----------------------------------------------------------------

var _species_ids: Dictionary = {}
var _species_key: PackedStringArray = PackedStringArray()
var _species_size: PackedByteArray = PackedByteArray()
var _catalog_error: String = ""

# --- compiled rig catalog (MOVE-DEP-R03) ------------------------------------------------------

## Rig key -> compiled ascending-ASCII RigDefinition id, and the id -> key reverse table.
##
## DELIBERATELY NOT PACKED COLUMNS, and deliberately not a species_id -> rig_id column either.
## MOVE-DEP-R03 says "bind each SpeciesDefinition through its actual species key" and "no
## per-resident mutable rig column is needed": the whole binding is `SPECIES_RIG_KEY` plus this
## compiled id map, sixteen immutable catalog entries in the same class as `_species_ids`. A
## packed `species_id -> rig_id` column would be a third copy of a fact the constant table
## already states, and a renumbering of either domain could then leave it stale.
var _rig_ids: Dictionary = {}
var _rig_key_table: Array[StringName] = []
var _rig_catalog_error: String = ""

# --- Resident columns (ARCH-MEM-001: packed, allocated once, indexed by typed row) -----------

var _present: PackedByteArray = PackedByteArray()
var _species: PackedInt32Array = PackedInt32Array()
var _size_class: PackedByteArray = PackedByteArray()
var _named: PackedByteArray = PackedByteArray()
## MOVE-DEP-R02 `Resident.life_stage:B8[512]`. Assigned at creation, never mutated afterwards.
var _life_stage: PackedByteArray = PackedByteArray()
var _name_key: PackedStringArray = PackedStringArray()
var _arrival_tick: PackedInt64Array = PackedInt64Array()
var _role: PackedByteArray = PackedByteArray()
var _selected: PackedByteArray = PackedByteArray()
## `home` and `bed` EntityRefs, split into slot/generation columns so no Vector2i array exists.
var _home_slot: PackedInt32Array = PackedInt32Array()
var _home_generation: PackedInt32Array = PackedInt32Array()
var _bed_slot: PackedInt32Array = PackedInt32Array()
var _bed_generation: PackedInt32Array = PackedInt32Array()
## The directory reference that owns this row, so a row can hand back a validatable ref.
var _ref_slot: PackedInt32Array = PackedInt32Array()
var _ref_generation: PackedInt32Array = PackedInt32Array()

## GDD §4.2 `Equipment`, minus `clothing_tier` (needs.gd owns it). The tool columns MIRROR the
## authoritative `GearInstance` row in `gear.gd`; the satchel columns are this store's own.
var _equip_tool_item_id: PackedInt32Array = PackedInt32Array()
var _equip_tool_durability: PackedInt32Array = PackedInt32Array()
var _equip_satchel_slot: PackedInt32Array = PackedInt32Array()
var _equip_satchel_generation: PackedInt32Array = PackedInt32Array()

## GDD §4.2 `Skills`: xp int64[12] and level int32[12], resident-major in one 12-wide stripe.
var _skill_xp: PackedInt64Array = PackedInt64Array()
var _skill_level: PackedInt32Array = PackedInt32Array()

## Ascending list of spawned rows, so demand iterates the population and not all 512 slots.
var _live_slots: PackedInt32Array = PackedInt32Array()
var _live_count: int = 0

## Rows created by the in-flight spawn_initial_settlement(), so a mid-cohort refusal can undo
## exactly what that call made and nothing else. Sized once with every other column.
var _cohort_slots: PackedInt32Array = PackedInt32Array()

# --- scratch (not simulation state) ----------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## The bulk-column namespace's own refusal code (decision 0132). Category 3: not state, not
## persisted, and excluded from `state_bytes()` so a refusal cannot alter the image that proves
## it changed nothing.
var _last_column_refusal: StringName = REFUSE_NONE


func _init(p_directory: EntityDirectory = null, p_needs: NeedsScript = null) -> void:
	"""Compile the species catalog, allocate every column once, and adopt or build collaborators.

	Passing an existing directory and needs store shares them; passing neither creates a private
	pair, which is what a test or a standalone settlement wants.
	"""
	assert(RESIDENT_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_RESIDENT],
		"resident columns must match the directory's RESIDENT row capacity")
	assert(RESIDENT_LIVING_CAP == EntityDirectory.RESIDENT_LIVING_CAP,
		"resident living cap must match the directory's living cap")
	_owns_collaborators = p_directory == null and p_needs == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_needs = p_needs if p_needs != null else NeedsScript.new()
	assert(LIFE_STAGE_KEYS.size() == LIFE_STAGE_COUNT,
		"the life-stage name table must cover exactly the bounded stage domain")
	assert(SPECIES_RIG_KEY.size() == SPECIES_COUNT,
		"MOVE-DEP-R03 binds one rig key to each of the 16 species")
	_compile_species()
	_compile_rigs()
	_allocate_columns()
	clear()


func _compile_species() -> void:
	"""Compile the §4.3 species keys into ascending-ASCII ids and their size classes."""
	var keys: Array[StringName] = []
	keys.append_array(SPECIES_SMALL_KEYS)
	keys.append_array(SPECIES_MEDIUM_KEYS)
	keys.append_array(SPECIES_LARGE_KEYS)
	var compiled: Catalog.DomainResult = Catalog.compile_domain(SPECIES_DOMAIN, keys)
	if not compiled.ok or compiled.ids.size() != SPECIES_COUNT:
		_catalog_error = compiled.error if not compiled.ok else "species catalog size mismatch"
		return
	_species_ids = compiled.ids
	_species_key.resize(SPECIES_COUNT)
	_species_size.resize(SPECIES_COUNT)
	for key: StringName in keys:
		var species_id: int = int(_species_ids[key])
		_species_key[species_id] = String(key)
		_species_size[species_id] = _declared_size_of(key)


func _compile_rigs() -> void:
	"""Compile MOVE-DEP-R03's sixteen logical rig keys and bind each species to its own.

	Catalog-time, like `_compile_species()`: the reverse table is sized here once and never
	again. Refuses to compile at all if the species catalog failed, because a rig identity that
	no species can be resolved against is not a binding.

	The keys are fed to the compiler in DESCENDING declaration order on purpose. `rig_<species>`
	sorts the same way `<species>` does, so handing them over in declaration order would make
	"ids come from catalog.gd's ASCII sort" and "ids come from the order of the constant table"
	indistinguishable -- a mutation that replaced the sort with an enumeration survived exactly
	that coincidence. Reversed, only the sort can produce the published ids.
	"""
	_rig_key_table.resize(RIG_COUNT)
	_rig_key_table.fill(NO_NAME_KEY)
	if _catalog_error != "":
		_rig_catalog_error = "species catalog unavailable"
		return
	var species_keys: Array = SPECIES_RIG_KEY.keys()
	species_keys.reverse()
	var keys: Array[StringName] = []
	for species_key_value: StringName in species_keys:
		keys.append(SPECIES_RIG_KEY[species_key_value] as StringName)
	var compiled: Catalog.DomainResult = Catalog.compile_domain(RIG_DOMAIN, keys)
	if not compiled.ok or compiled.ids.size() != RIG_COUNT:
		_rig_catalog_error = compiled.error if not compiled.ok else "rig catalog size mismatch"
		return
	_rig_ids = compiled.ids
	for key: StringName in keys:
		_rig_key_table[int(_rig_ids[key])] = key


func _declared_size_of(key: StringName) -> int:
	"""Size class of one species key, straight from the §4.3 six/six/four split."""
	if SPECIES_SMALL_KEYS.has(key):
		return SIZE_SMALL
	if SPECIES_MEDIUM_KEYS.has(key):
		return SIZE_MEDIUM
	return SIZE_LARGE


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_present.resize(RESIDENT_CAPACITY)
	_species.resize(RESIDENT_CAPACITY)
	_size_class.resize(RESIDENT_CAPACITY)
	_named.resize(RESIDENT_CAPACITY)
	_life_stage.resize(RESIDENT_CAPACITY)
	_name_key.resize(RESIDENT_CAPACITY)
	_arrival_tick.resize(RESIDENT_CAPACITY)
	_role.resize(RESIDENT_CAPACITY)
	_selected.resize(RESIDENT_CAPACITY)
	_home_slot.resize(RESIDENT_CAPACITY)
	_home_generation.resize(RESIDENT_CAPACITY)
	_bed_slot.resize(RESIDENT_CAPACITY)
	_bed_generation.resize(RESIDENT_CAPACITY)
	_ref_slot.resize(RESIDENT_CAPACITY)
	_ref_generation.resize(RESIDENT_CAPACITY)
	_equip_tool_item_id.resize(RESIDENT_CAPACITY)
	_equip_tool_durability.resize(RESIDENT_CAPACITY)
	_equip_satchel_slot.resize(RESIDENT_CAPACITY)
	_equip_satchel_generation.resize(RESIDENT_CAPACITY)
	_skill_xp.resize(RESIDENT_CAPACITY * SKILL_COUNT)
	_skill_level.resize(RESIDENT_CAPACITY * SKILL_COUNT)
	_live_slots.resize(RESIDENT_CAPACITY)
	_cohort_slots.resize(INITIAL_POPULATION)


func clear() -> void:
	"""Return every column to its empty state without reallocating, and clear collaborators.

	Only a store that built its own directory and needs clears them; a shared pair belongs to
	its owner and is left alone.
	"""
	_clear_identity_columns()
	_clear_reference_columns()
	_skill_xp.fill(0)
	_skill_level.fill(0)
	_live_slots.fill(EntityDirectory.NULL_SLOT)
	_live_count = 0
	_cohort_slots.fill(EntityDirectory.NULL_SLOT)
	if _owns_collaborators:
		_directory.clear()
		_needs.clear()


func _clear_identity_columns() -> void:
	"""Reset the per-row identity and classification columns to their empty values.

	`_life_stage` goes to ADULT because MOVE-DEP-R02 makes 0 the canonical unused value; an
	empty row is still distinguished by `_present`, never by this byte.
	"""
	_present.fill(0)
	_species.fill(0)
	_size_class.fill(SIZE_SMALL)
	_named.fill(0)
	_life_stage.fill(LIFE_STAGE_ADULT)
	_name_key.fill(String(NO_NAME_KEY))
	_arrival_tick.fill(0)
	_role.fill(ROLE_RESIDENT)
	_selected.fill(0)


func _clear_reference_columns() -> void:
	"""Reset every stored EntityRef pair and the Equipment mirror to null/empty."""
	_home_slot.fill(EntityDirectory.NULL_SLOT)
	_home_generation.fill(EntityDirectory.NULL_GENERATION)
	_bed_slot.fill(EntityDirectory.NULL_SLOT)
	_bed_generation.fill(EntityDirectory.NULL_GENERATION)
	_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_equip_tool_item_id.fill(NO_TOOL_ITEM)
	_equip_tool_durability.fill(0)
	_equip_satchel_slot.fill(EntityDirectory.NULL_SLOT)
	_equip_satchel_generation.fill(EntityDirectory.NULL_GENERATION)


# --- collaborators and catalog readers -------------------------------------------------------

func directory() -> EntityDirectory:
	"""The allocator behind every resident reference."""
	return _directory


func needs() -> NeedsScript:
	"""The needs/health store whose rows share this store's typed slots."""
	return _needs


func catalog_error() -> String:
	"""Why the species catalog failed to compile, or empty when it is usable."""
	return _catalog_error


func has_species(species_key: StringName) -> bool:
	"""True when the key names one of the 16 release-1 species."""
	return _species_ids.has(species_key)


func species_id(species_key: StringName) -> IntMath.IntResult:
	"""Compiled ascending-ASCII id for a species key, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _species_ids.has(species_key):
		out.refuse(String(REFUSE_UNKNOWN_SPECIES))
		return out
	out.succeed(int(_species_ids[species_key]))
	return out


func species_key(species_id_value: int) -> StringName:
	"""Catalog key of a compiled species id, or the empty name when the id is out of range."""
	if species_id_value < 0 or species_id_value >= SPECIES_COUNT:
		return NO_NAME_KEY
	return StringName(_species_key[species_id_value])


func species_size_class(species_key_value: StringName) -> IntMath.IntResult:
	"""Size class of a species key, or an explicit refusal for an unknown key."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _species_ids.has(species_key_value):
		out.refuse(String(REFUSE_UNKNOWN_SPECIES))
		return out
	out.succeed(_species_size[int(_species_ids[species_key_value])])
	return out


func species_count() -> int:
	"""Number of species in the release-1 catalog."""
	return SPECIES_COUNT


func size_carry_g(size_class: int) -> IntMath.IntResult:
	"""GDD §5.2 carry capacity in grams for a size class, or an explicit refusal."""
	return _size_table_read(SIZE_CARRY_G, size_class)


func size_movement_u_per_s(size_class: int) -> IntMath.IntResult:
	"""GDD §5.2 movement cap in u/second for a size class, or an explicit refusal."""
	return _size_table_read(SIZE_MOVEMENT_U_PER_S, size_class)


func size_multiplier(size_class: int) -> IntMath.IntResult:
	"""GDD §5.2 hunger/size multiplier for a size class, or an explicit refusal."""
	return _size_table_read(SIZE_MULTIPLIER, size_class)


func _size_table_read(table: Array[int], size_class: int) -> IntMath.IntResult:
	"""Read one per-size-class constant, refusing rather than clamping an out-of-range class."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if size_class < 0 or size_class >= SIZE_COUNT:
		out.refuse(String(NeedsScript.REFUSE_INVALID_SIZE))
		return out
	out.succeed(table[size_class])
	return out


# --- season ----------------------------------------------------------------------------------

func set_winter(winter: bool) -> OpResult:
	"""Set the winter flag on the shared needs store, which owns the season for both modules."""
	var result: NeedsScript.OpResult = _needs.set_winter(winter)
	if not result.ok:
		return _refuse(result.error)
	return _succeed(0, NULL_REF)


func is_winter() -> bool:
	"""True while the shared needs store is in winter."""
	return _needs.is_winter()


func season_multiplier() -> int:
	"""Today's demand multiplier: GDD §5.2's winter x1.20, or 1.0 in every other season."""
	return SEASON_MULTIPLIER_WINTER if _needs.is_winter() else SEASON_MULTIPLIER_DEFAULT


# --- lifecycle ---------------------------------------------------------------------------------

func spawn(species_key_value: StringName) -> OpResult:
	"""Allocate one ADULT resident. The stage is passed by name, not defaulted silently.

	This is the only spawn path GDD-era callers use and it preserves `movement.gd`'s current
	"adult 0". Anything that wants a CHILD or ELDER must say so through `spawn_with_stage()`,
	so no non-adult can ever appear from a call that did not name a stage.
	"""
	return spawn_with_stage(species_key_value, LIFE_STAGE_ADULT)


func spawn_with_stage(species_key_value: StringName, life_stage: int) -> OpResult:
	"""Allocate one resident at an explicit, validated MOVE-DEP-R02 life stage.

	Refuses without allocating anything when the species is unknown, the catalog failed to
	compile, or the stage is outside 0..2 -- an out-of-domain stage is refused, never clamped
	to ADULT. A directory refusal (living cap, capacity, persistent-id exhaustion) is passed
	through with its own ARCH-ID-004 code, and no needs row is attached.

	No rig table is consulted: MOVE-DEP-R03 makes a missing rig a presentation/export gap, so a
	CHILD spawns whether or not any `(species, life_stage)` render binding exists.
	"""
	if _catalog_error != "":
		return _refuse(REFUSE_SPECIES_CATALOG)
	if not _species_ids.has(species_key_value):
		return _refuse(REFUSE_UNKNOWN_SPECIES)
	if not is_life_stage(life_stage):
		return _refuse(REFUSE_INVALID_LIFE_STAGE)
	var species_id_value: int = int(_species_ids[species_key_value])
	var size_class: int = _species_size[species_id_value]
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_RESIDENT)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	var attached: NeedsScript.OpResult = _needs.spawn(slot, size_class)
	if not attached.ok:
		_directory.destroy(ref)
		return _refuse(attached.error)
	_write_spawn_row(slot, ref, species_id_value, size_class, life_stage)
	return _succeed(slot, ref)


func _write_spawn_row(slot: int, ref: Vector2i, species_id_value: int, size_class: int,
		life_stage: int) -> void:
	"""Write every Resident and Skills column of one freshly spawned row to its §4.2 default.

	`life_stage` is written here rather than left at whatever the previous tenant of a reused
	slot held: MOVE-DEP-R02 requires free-slot reuse to initialize the stage explicitly.
	"""
	_present[slot] = 1
	_species[slot] = species_id_value
	_size_class[slot] = size_class
	_life_stage[slot] = life_stage
	_named[slot] = 0
	_name_key[slot] = String(NO_NAME_KEY)
	_arrival_tick[slot] = 0
	_role[slot] = ROLE_RESIDENT
	_selected[slot] = 0
	_home_slot[slot] = EntityDirectory.NULL_SLOT
	_home_generation[slot] = EntityDirectory.NULL_GENERATION
	_bed_slot[slot] = EntityDirectory.NULL_SLOT
	_bed_generation[slot] = EntityDirectory.NULL_GENERATION
	_ref_slot[slot] = ref.x
	_ref_generation[slot] = ref.y
	_clear_equipment_row(slot)
	var base: int = slot * SKILL_COUNT
	for skill: int in SKILL_COUNT:
		_skill_xp[base + skill] = 0
		_skill_level[base + skill] = 0
	_insert_live_slot(slot)


func _insert_live_slot(slot: int) -> void:
	"""Insert a spawned row into the ascending live list, keeping iteration order stable."""
	var index: int = _live_count
	while index > 0 and _live_slots[index - 1] > slot:
		_live_slots[index] = _live_slots[index - 1]
		index -= 1
	_live_slots[index] = slot
	_live_count += 1


func _remove_live_slot(slot: int) -> void:
	"""Remove a row from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _live_count and _live_slots[index] != slot:
		index += 1
	if index >= _live_count:
		return
	while index + 1 < _live_count:
		_live_slots[index] = _live_slots[index + 1]
		index += 1
	_live_count -= 1
	_live_slots[_live_count] = EntityDirectory.NULL_SLOT


func despawn(ref: Vector2i) -> OpResult:
	"""Release one resident: the needs row, this store's columns, and the directory slot.

	Refuses a stale or wrong-kind reference rather than clearing whatever row it points at.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESIDENT):
		return _refuse(REFUSE_NOT_PRESENT)
	var slot: int = _directory.get_typed_row(ref)
	if slot < 0 or slot >= RESIDENT_CAPACITY or _present[slot] == 0:
		return _refuse(REFUSE_NOT_PRESENT)
	if _needs.is_present(slot):
		_needs.despawn(slot)
	_present[slot] = 0
	_named[slot] = 0
	_life_stage[slot] = LIFE_STAGE_ADULT
	_name_key[slot] = String(NO_NAME_KEY)
	_role[slot] = ROLE_RESIDENT
	_selected[slot] = 0
	_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_clear_equipment_row(slot)
	_remove_live_slot(slot)
	_directory.destroy(ref)
	return _succeed(slot, NULL_REF)


func spawn_initial_settlement() -> OpResult:
	"""Spawn the exact GDD §5.1 starting cohort. Returns the number of residents created.

	Refuses on a non-empty store rather than adding a second cohort beside the first, so the
	§5.1 "IDs 1-12" contract cannot be quietly broken by a double call.

	A refusal partway through the twelve despawns every resident this call had already made.
	OpResult states that a refusal "never carries a partially applied effect", and a half-built
	cohort is exactly that: the caller is told nothing was created while the store holds a
	population it never asked for and can no longer name.
	"""
	if _live_count != 0 or _directory.live_count(EntityDirectory.KIND_RESIDENT) != 0:
		return _refuse(REFUSE_SETTLEMENT_NOT_EMPTY)
	for index: int in INITIAL_POPULATION:
		var spawned: OpResult = spawn_with_stage(INITIAL_SPECIES[index], LIFE_STAGE_ADULT)
		if not spawned.ok:
			_rollback_cohort(index)
			return _refuse(spawned.error)
		_cohort_slots[index] = spawned.value
		var written: StringName = _write_initial_resident(spawned.value, index)
		if written != REFUSE_NONE:
			_rollback_cohort(index + 1)
			return _refuse(written)
	return _succeed(INITIAL_POPULATION, NULL_REF)


func _rollback_cohort(created: int) -> void:
	"""Despawn the `created` starters an aborted spawn_initial_settlement() had already made.

	Reverse creation order, so the most recently allocated directory slot is released first.
	Nothing else is touched: the store was verified empty before the first spawn.
	"""
	var index: int = created
	while index > 0:
		index -= 1
		var slot: int = _cohort_slots[index]
		if slot != EntityDirectory.NULL_SLOT:
			despawn(ref_of(slot))
		_cohort_slots[index] = EntityDirectory.NULL_SLOT


func _write_initial_resident(slot: int, index: int) -> StringName:
	"""Apply the §5.1 role, name, arrival tick and starting XP to one starter resident.

	The Warden's authored name goes through `set_name()` rather than into the columns directly:
	NAME-R02 makes AUTOMATIC NAME ASSIGNMENT one of the shared validator's callers, so an authored
	constant that stopped satisfying the rule refuses the cohort instead of seeding a store the
	section 14 codec would later be unable to write. Returns REFUSE_NONE when the row is written.
	"""
	_arrival_tick[slot] = INITIAL_ARRIVAL_TICK
	var is_warden: bool = index == WARDEN_INDEX
	if is_warden:
		_role[slot] = ROLE_WARDEN
		var named: OpResult = set_name(slot, WARDEN_NAME)
		if not named.ok:
			return named.error
	var base: int = slot * SKILL_COUNT
	for skill: int in SKILL_COUNT:
		if skill == SKILL_RESERVED_INDEX:
			continue
		var xp: int = INITIAL_ACTIVE_SKILL_XP
		if is_warden and skill == SKILL_KEEP:
			xp = WARDEN_KEEP_XP
		_skill_xp[base + skill] = xp
		_skill_level[base + skill] = skill_level_for_xp(xp)
	return REFUSE_NONE


# --- readers -----------------------------------------------------------------------------------

func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a spawned resident row."""
	return slot >= 0 and slot < RESIDENT_CAPACITY and _present[slot] == 1


func is_alive(slot: int) -> bool:
	"""True when `slot` holds a spawned resident the needs store still counts as living."""
	return is_present(slot) and _needs.is_alive(slot)


func population() -> int:
	"""Number of spawned resident rows, including rows whose resident has died."""
	return _live_count


func living_count() -> int:
	"""Number of residents that are not dead, as the shared needs store counts them."""
	return _needs.living_count()


func ref_of(slot: int) -> Vector2i:
	"""The directory reference owning a row, or the null reference when the row is empty."""
	if not is_present(slot):
		return NULL_REF
	return Vector2i(_ref_slot[slot], _ref_generation[slot])


func persistent_id_of(slot: int) -> IntMath.IntResult:
	"""The never-reused persistent id of a row's resident, or an explicit refusal."""
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(_directory.get_persistent_id(ref_of(slot)))


func species_of(slot: int) -> IntMath.IntResult:
	"""Compiled species id of a row, or an explicit refusal."""
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(_species[slot])


func size_class_of(slot: int) -> IntMath.IntResult:
	"""Size class of a row's species, or an explicit refusal."""
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(_size_class[slot])


# --- life stage, MOVE-DEP-R02 -----------------------------------------------------------------

func is_life_stage(life_stage: int) -> bool:
	"""True for exactly ADULT, CHILD and ELDER. COUNT is a bound and is never a stage."""
	return life_stage >= LIFE_STAGE_ADULT and life_stage < LIFE_STAGE_COUNT


func life_stage_key(life_stage: int) -> StringName:
	"""Report name of a stage value, or the empty name when the value is outside the domain.

	A reporting helper for messages and fixtures. Nothing in the simulation branches on it; the
	stage VALUE is the authority and `is_life_stage()` is what decides validity.
	"""
	if not is_life_stage(life_stage):
		return NO_NAME_KEY
	return LIFE_STAGE_KEYS[life_stage]


func life_stage_of(slot: int) -> IntMath.IntResult:
	"""The row's assigned life stage, or an explicit refusal when the row holds no resident.

	Slot-addressed, so it carries no generation check. A caller holding an `EntityRef` -- which
	is every caller that could be holding a stale one -- must use `life_stage_of_ref()`.
	"""
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(_life_stage[slot])


func life_stage_of_ref(ref: Vector2i) -> IntMath.IntResult:
	"""Generation-checked `life_stage_of()`: refuses a stale or wrong-kind reference.

	MOVE-DEP-R02 requires generation-checked readers to reject stale refs rather than answer
	from whatever resident later took the slot. The generation namespace here is the DIRECTORY's
	(`entity_directory.gd`'s `_generation` on the directory slot), not `inventory.gd`'s
	container/lot spaces and not `navigation.gd`'s descriptor space.
	"""
	var resolved: IntMath.IntResult = slot_of_ref(ref)
	if not resolved.ok:
		return resolved
	return _read_value(_life_stage[resolved.value])


func life_stage_column_image() -> PackedByteArray:
	"""Exact copy of the whole life-stage column, including free rows.

	NOT a production call: it allocates, in the same way `equipment_state_bytes()` does. It
	exists so the canonical-unused-zero rule can be checked directly -- MOVE-DEP-R02 requires a
	free row to hold 0, and a retired ELDER that left a 2 behind would be a nonzero byte in a
	future section-4 hash that nothing else in this store can observe.
	"""
	return _life_stage.duplicate()


func life_stage_payload_bytes() -> int:
	"""Bytes the life-stage column actually occupies, re-derived from the column itself.

	Evidence for MOVE-DEP-R02's "+512 resident bytes" rather than a transcribed constant: change
	the column length and this number moves with it.
	"""
	return _life_stage.size()


# --- generation-safe reference resolution (MOVE-DEP-R05's identity half that lives here) ------

func slot_of_ref(ref: Vector2i) -> IntMath.IntResult:
	"""Resolve a resident `EntityRef` to its typed row, refusing a stale or wrong-kind pair.

	The directory validates `(slot, generation)`; this additionally requires the typed row to be
	occupied here, so a directory slot whose resident row was released cannot be read. Refusal
	is on its own channel: no caller can mistake a resolved row 0 for a failure.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESIDENT):
		return _read_refusal(REFUSE_STALE_REF)
	var slot: int = _directory.get_typed_row(ref)
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(slot)


func is_well_formed_ref(ref: Vector2i) -> bool:
	"""True for the null ref `(-1, 0)` or any pair whose slot is >= 0 and generation > 0.

	Shape only. It cannot say which generation namespace a non-resident reference belongs to,
	because this store holds no building, furniture or inventory reference to check it against.
	"""
	if ref == NULL_REF:
		return true
	return ref.x >= 0 and ref.y > 0


func home_is_live(slot: int) -> bool:
	"""True when the row's home reference still validates against the directory right now.

	MOVE-DEP-R05: a destination's identity is generation-safe or it is not a destination. A
	retired owner's slot may already hold a different entity, so a consumer must ask this and
	not merely test the stored pair against `(-1, 0)`.
	"""
	return _is_live_directory_ref(home_of(slot))


func bed_is_live(slot: int) -> bool:
	"""True when the row's bed reference still validates against the directory right now."""
	return _is_live_directory_ref(bed_of(slot))


func _is_live_directory_ref(ref: Vector2i) -> bool:
	"""True when a non-null pair is a currently valid directory reference of any kind."""
	if ref == NULL_REF:
		return false
	return _directory.is_valid(ref)


# --- logical rig identity, MOVE-DEP-R03 -------------------------------------------------------

func rig_catalog_error() -> String:
	"""Why the RigDefinition domain failed to compile, or empty when it is usable."""
	return _rig_catalog_error


func rig_count() -> int:
	"""Number of compiled logical rig identities: one per release-1 species."""
	return RIG_COUNT


func has_rig(rig_key_value: StringName) -> bool:
	"""True when the key is one of the sixteen compiled logical rig identities."""
	return _rig_ids.has(rig_key_value)


func rig_id(rig_key_value: StringName) -> IntMath.IntResult:
	"""Compiled ascending-ASCII id of a logical rig key, or an explicit refusal."""
	if _rig_catalog_error != "":
		return _read_refusal(REFUSE_RIG_CATALOG)
	if not _rig_ids.has(rig_key_value):
		return _read_refusal(REFUSE_UNKNOWN_RIG)
	return _read_value(int(_rig_ids[rig_key_value]))


func rig_key_of(rig_id_value: int) -> StringName:
	"""Logical rig key of a compiled id, or the empty name when the id is out of range."""
	if _rig_catalog_error != "" or rig_id_value < 0 or rig_id_value >= RIG_COUNT:
		return NO_NAME_KEY
	return _rig_key_table[rig_id_value]


func rig_binding(species_key_value: StringName, life_stage: int) -> OpResult:
	"""Compiled rig id bound to one `(species, life_stage)` pair, or an explicit refusal.

	ADULT resolves through MOVE-DEP-R03's sixteen logical base identities. CHILD and ELDER
	refuse with `RIG_STAGE_VARIANT_UNBOUND`: the ruling requires an explicit `(species,
	life_stage)` binding for a stage variant and forbids silently inheriting the adult rig, and
	no such binding is authored anywhere in this repository.

	A refusal is a PRESENTATION gap. It does not make the resident illegal and nothing in the
	spawn or movement-admission path calls this.
	"""
	if _rig_catalog_error != "":
		return _refuse(REFUSE_RIG_CATALOG)
	if not _species_ids.has(species_key_value):
		return _refuse(REFUSE_UNKNOWN_SPECIES)
	if not is_life_stage(life_stage):
		return _refuse(REFUSE_INVALID_LIFE_STAGE)
	if life_stage != LIFE_STAGE_ADULT:
		return _refuse(REFUSE_RIG_STAGE_UNBOUND)
	var rig: StringName = SPECIES_RIG_KEY[species_key_value] as StringName
	return _succeed(int(_rig_ids[rig]), NULL_REF)


func has_rig_binding(species_key_value: StringName, life_stage: int) -> bool:
	"""True when a `(species, life_stage)` pair has an authored logical rig identity."""
	return rig_binding(species_key_value, life_stage).ok


func rig_binding_by_species_id(species_id_value: int, life_stage: int) -> OpResult:
	"""`rig_binding()` for a caller holding a compiled species id rather than its key.

	Resolves the id back to its own key first, so the binding is still made through the species
	key MOVE-DEP-R03 names and an id from a different domain cannot index into this one.
	"""
	var key: StringName = species_key(species_id_value)
	if key == NO_NAME_KEY:
		return _refuse(REFUSE_UNKNOWN_SPECIES)
	return rig_binding(key, life_stage)


func role_of(slot: int) -> IntMath.IntResult:
	"""Role enum of a row, or an explicit refusal."""
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(_role[slot])


func is_named(slot: int) -> bool:
	"""True when a row carries an authored or player-supplied name."""
	return is_present(slot) and _named[slot] == 1


func name_key_of(slot: int) -> StringName:
	"""The authored name of a row, or the empty name when it is unnamed or absent."""
	if not is_present(slot):
		return NO_NAME_KEY
	return StringName(_name_key[slot])


func arrival_tick_of(slot: int) -> IntMath.IntResult:
	"""Arrival tick of a row's resident, or an explicit refusal."""
	if not is_present(slot):
		return _read_refusal(REFUSE_NOT_PRESENT)
	return _read_value(_arrival_tick[slot])


func home_of(slot: int) -> Vector2i:
	"""The row's home reference; null `(-1, 0)` while no building store exists."""
	if not is_present(slot):
		return NULL_REF
	return Vector2i(_home_slot[slot], _home_generation[slot])


func bed_of(slot: int) -> Vector2i:
	"""The row's bed reference; null `(-1, 0)` while no furniture store exists."""
	if not is_present(slot):
		return NULL_REF
	return Vector2i(_bed_slot[slot], _bed_generation[slot])


func is_selected(slot: int) -> bool:
	"""Presentation-only selection flag; never part of saved gameplay truth (GDD §4.2)."""
	return is_present(slot) and _selected[slot] == 1


func skill_xp_of(slot: int, skill: int) -> IntMath.IntResult:
	"""XP in one of the 12 skill columns, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	skill_xp_into(slot, skill, out)
	return out


func skill_xp_into(slot: int, skill: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `skill_xp_of()`: write one XP column into caller-owned `out`."""
	var code: StringName = _check_skill_address(slot, skill)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_skill_xp[slot * SKILL_COUNT + skill])


func skill_level_of(slot: int, skill: int) -> IntMath.IntResult:
	"""Level in one of the 12 skill columns, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	skill_level_into(slot, skill, out)
	return out


func skill_level_into(slot: int, skill: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `skill_level_of()`: write one level column into caller-owned `out`."""
	var code: StringName = _check_skill_address(slot, skill)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_skill_level[slot * SKILL_COUNT + skill])


func skill_level_for_xp(xp: int) -> int:
	"""GDD §5.3 level curve: the largest L <= 10 with xp >= 5000*L*L.

	Equivalent to min(10, floor_sqrt(floor(xp/5000))) without a square root, so the cumulative
	table 0, 5000, 20000, 45000, ... 500000 is reproduced exactly in integers.
	"""
	if xp < 0:
		return 0
	var level: int = 0
	while level < SKILL_LEVEL_MAX and xp >= SKILL_XP_PER_LEVEL_SQUARE * (level + 1) * (level + 1):
		level += 1
	return level


func _check_skill_address(slot: int, skill: int) -> StringName:
	"""REFUSE_NONE when `slot` holds a resident and `skill` is one of the 12 columns."""
	if not is_present(slot):
		return REFUSE_NOT_PRESENT
	if skill < 0 or skill >= SKILL_COUNT:
		return REFUSE_INVALID_SKILL
	return REFUSE_NONE


# --- NAME-R02: the one shared name validator ----------------------------------------------------

static func is_unicode_scalar(code_point: int) -> bool:
	"""True for a code point that strict UTF-8 can encode: 0..0x10FFFF, no surrogate.

	Static and public so the rule is testable on its own. A surrogate or an out-of-range code
	point has no strict UTF-8 encoding, so it can never be written to or read back from the save
	arena; NAME-R02 forbids replacing it, which leaves refusing it.
	"""
	if code_point < 0 or code_point > UNICODE_SCALAR_MAX:
		return false
	return code_point < SURROGATE_MIN or code_point > SURROGATE_MAX


static func is_control_scalar(code_point: int) -> bool:
	"""True for Unicode category Cc: U+0000-U+001F, U+007F DEL and U+0080-U+009F.

	Written as three explicit bounds. NAME-R02 requires an explicit control-code predicate rather
	than a call into whatever Unicode category tables the engine build happens to carry, so an
	engine upgrade cannot silently change which names this store admits.
	"""
	if code_point <= CONTROL_C0_MAX:
		return true
	return code_point >= CONTROL_DEL and code_point <= CONTROL_C1_MAX


static func utf8_byte_length_of(name_value: StringName) -> int:
	"""Strict-UTF-8 encoded byte length, computed from the scalar width boundaries.

	Arithmetic rather than `to_utf8_buffer().size()`, so the check allocates nothing and the
	rule reads as the rule. Only meaningful once every scalar satisfies `is_unicode_scalar()`;
	`name_refusal()` proves that before it asks.
	"""
	var text: String = String(name_value)
	var total: int = 0
	for index: int in text.length():
		var code_point: int = text.unicode_at(index)
		if code_point <= UTF8_ONE_BYTE_MAX:
			total += 1
		elif code_point <= UTF8_TWO_BYTE_MAX:
			total += 2
		elif code_point <= UTF8_THREE_BYTE_MAX:
			total += 3
		else:
			total += 4
	return total


static func scalar_length_of(name_value: StringName) -> int:
	"""Number of Unicode SCALAR VALUES in a name -- not bytes and not grapheme clusters.

	Godot's String is UTF-32, so `length()` is already the scalar count: "Mo" + U+0301 + "le" is
	5 scalars and 4 grapheme clusters, and a three-scalar ZWJ sequence is one cluster and 11
	bytes. The three units disagree, which is exactly why NAME-R02 names the unit.
	"""
	return String(name_value).length()


static func name_refusal(name_value: StringName) -> StringName:
	"""THE shared personal-name validator (NAME-R02). REFUSE_NONE when the name is admissible.

	Used by `set_name()`, `restore_name()`, the NAME_RESIDENT command path, automatic name
	assignment and the section 14 codec, so one rule cannot hold at the setter and a different
	one at the wire. The EMPTY name is admitted: it is the anonymous row, the common case.

	Nothing is normalized, truncated or replaced. The order is encodability, then the 128-byte
	cap, then the 2-32 scalar rule, then the control-code predicate, which is the order
	SAVE-R09-002 states and the order the section 14 refusal codes were pinned against.
	"""
	var text: String = String(name_value)
	if text.is_empty():
		return REFUSE_NONE
	var scalars: int = text.length()
	for index: int in scalars:
		if not is_unicode_scalar(text.unicode_at(index)):
			return REFUSE_NAME_NOT_UTF8
	if utf8_byte_length_of(name_value) > NAME_MAX_UTF8_BYTES:
		return REFUSE_NAME_BYTES
	if scalars < NAME_MIN_SCALARS or scalars > NAME_MAX_SCALARS:
		return REFUSE_NAME_SCALARS
	for index: int in scalars:
		if is_control_scalar(text.unicode_at(index)):
			return REFUSE_NAME_CONTROL
	return REFUSE_NONE


static func name_occupancy_refusal(present: bool, named: bool,
		name_value: StringName) -> StringName:
	"""NAME-R02's three-row table, checked as a pair rather than derived from one half.

	A free row and a present anonymous row share the SAME shape -- flag 0 and an empty name --
	so occupancy alone never decides whether a name is legal. `present` is still taken separately
	so a caller that hangs a name on a free row is refused with its own code.

	Deriving the flag from emptiness is what this function exists to replace: a derivation can
	only ever produce agreement, and therefore can only ever conceal a disagreement.
	"""
	var invalid: StringName = name_refusal(name_value)
	if invalid != REFUSE_NONE:
		return invalid
	var empty: bool = String(name_value).is_empty()
	if not present:
		if named or not empty:
			return REFUSE_FREE_ROW_NAMED
		return REFUSE_NONE
	if named and empty:
		return REFUSE_NAMED_ROW_EMPTY
	if not named and not empty:
		return REFUSE_ANONYMOUS_ROW_NAMED
	return REFUSE_NONE


func row_name_refusal(slot: int) -> StringName:
	"""Check one LIVE row's stored `(_named, _name_key)` pair against the NAME-R02 table.

	Reads the physical columns rather than the public readers, because `name_key_of()` masks an
	absent row's stored key behind the empty name and would report a stale key as clean.
	"""
	if slot < 0 or slot >= RESIDENT_CAPACITY:
		return REFUSE_INVALID_SLOT
	return name_occupancy_refusal(_present[slot] == 1, _named[slot] == 1,
		StringName(_name_key[slot]))


# --- mutators -----------------------------------------------------------------------------------

func set_role(slot: int, role: int) -> OpResult:
	"""Set a resident's Role enum. Refuses an unknown role rather than storing it."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if role < 0 or role >= ROLE_COUNT:
		return _refuse(REFUSE_INVALID_ROLE)
	_role[slot] = role
	return _succeed(role, ref_of(slot))


func set_name(slot: int, name_value: StringName) -> OpResult:
	"""Name a present resident, or install the empty name of an anonymous row (NAME-R02).

	VALIDATES THROUGH THE SHARED VALIDATOR, which is the closure of blocker N3: this setter used
	to store any StringName at all and derive `_named` from emptiness, so a live store could hold
	a 40-scalar name with control characters that the section 14 codec then had to refuse. One
	rule now holds at the setter and at the wire.

	The EMPTY name stays legal here because this is also the entry point that creates and
	restores an anonymous row. It is not a player-facing "clear personal identity" action:
	NAME-R02 gives alias entry no such command, and `command_dispatch.gd` refuses an empty alias
	payload before it ever reaches this function.

	A REFUSAL WRITES NOTHING. Both columns are written only after the name has been admitted, so
	a refused call leaves the row byte-identical.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	var invalid: StringName = name_refusal(name_value)
	if invalid != REFUSE_NONE:
		return _refuse(invalid)
	_name_key[slot] = String(name_value)
	_named[slot] = 0 if name_value == NO_NAME_KEY else 1
	return _succeed(slot, ref_of(slot))


func restore_name(slot: int, named: bool, name_value: StringName) -> OpResult:
	"""Install a save's `(named, name)` PAIR on one present row without deriving either half.

	NAME-R02's ordering rule, verbatim: "apply names last must not conceal corruption".
	`set_name()` recomputes `_named` from emptiness, so a save whose section 4 flag and section 14
	string disagree would be quietly repaired into a self-consistent row and the corruption would
	never be reported. This entry point takes both halves explicitly, validates the pair against
	the occupancy table BEFORE it writes a byte, and refuses the disagreement in either
	direction.

	Restore may install an earlier valid ANONYMOUS snapshot -- `named` false with the empty name
	-- with no operational naming trigger involved.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	var invalid: StringName = name_occupancy_refusal(true, named, name_value)
	if invalid != REFUSE_NONE:
		return _refuse(invalid)
	_name_key[slot] = String(name_value)
	_named[slot] = 1 if named else 0
	return _succeed(slot, ref_of(slot))


func set_selected(slot: int, selected: bool) -> OpResult:
	"""Set the presentation-only selection flag."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	_selected[slot] = 1 if selected else 0
	return _succeed(slot, ref_of(slot))


func set_arrival_tick(slot: int, tick: int) -> OpResult:
	"""Record the tick a resident joined the settlement."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	_arrival_tick[slot] = tick
	return _succeed(tick, ref_of(slot))


func set_home(slot: int, home_ref: Vector2i) -> OpResult:
	"""Point a resident at a home, or clear it with the null ref `(-1, 0)`.

	Refuses a malformed pair rather than storing it: MOVE-DEP-R05 makes the owner reference half
	of a destination's identity, and a stored `(5, 0)` would be a reference that can never be
	validated and never be recognised as null. The DOMAIN is not checked here -- this store holds
	no building reference to check it against -- only the shape.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if not is_well_formed_ref(home_ref):
		return _refuse(REFUSE_INVALID_REF)
	_home_slot[slot] = home_ref.x
	_home_generation[slot] = home_ref.y
	return _succeed(slot, ref_of(slot))


func set_bed(slot: int, bed_ref: Vector2i) -> OpResult:
	"""Point a resident at a bed, or clear it with the null ref `(-1, 0)`.

	Refuses a malformed pair for the same reason `set_home()` does. `bed_is_live()` is what a
	consumer asks before treating the stored pair as a live destination.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if not is_well_formed_ref(bed_ref):
		return _refuse(REFUSE_INVALID_REF)
	_bed_slot[slot] = bed_ref.x
	_bed_generation[slot] = bed_ref.y
	return _succeed(slot, ref_of(slot))


func set_skill_xp(slot: int, skill: int, xp: int) -> OpResult:
	"""Write one skill's XP and re-derive its level from the §5.3 curve.

	Refuses the reserved index 3, which §5.1 fixes at XP and level 0, and refuses negative XP.
	"""
	var code: StringName = _check_skill_address(slot, skill)
	if code != REFUSE_NONE:
		return _refuse(code)
	if skill == SKILL_RESERVED_INDEX:
		return _refuse(REFUSE_RESERVED_SKILL)
	if xp < 0:
		return _refuse(REFUSE_INVALID_XP)
	var index: int = slot * SKILL_COUNT + skill
	_skill_xp[index] = xp
	_skill_level[index] = skill_level_for_xp(xp)
	return _succeed(_skill_level[index], ref_of(slot))


# --- GDD §5.8 daily nutrition demand ------------------------------------------------------------

func resident_daily_demand_np(slot: int) -> IntMath.IntResult:
	"""One resident's daily nutrition requirement at today's season, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	_demand_of_size_into(_size_class[slot], season_multiplier(), out)
	return out


func _demand_of_size_into(size_class: int, season: int, out: IntMath.IntResult) -> bool:
	"""floor(6000 * size_multiplier * season_multiplier / 1000000), int64 before the divide.

	GDD §4.1 fixes the 6000 NP/day small baseline, §5.2 the size multipliers and the winter
	x1.20, and §5.2's integration rule requires compound multipliers to be applied in int64
	before any division. `out` doubles as this call's own scratch.
	"""
	if not IntMath.checked_mul_into(BASE_NUTRITION_PER_DAY_NP, SIZE_MULTIPLIER[size_class], out):
		return false
	if not IntMath.checked_mul_into(out.value, season, out):
		return false
	return IntMath.floor_div_into(out.value, DEMAND_DENOMINATOR, out)


func daily_demand_np() -> IntMath.IntResult:
	"""GDD §5.8's food-days DENOMINATOR: today's total daily nutrition demand in NP.

	Sums every LIVING resident's size-scaled and season-scaled baseline requirement; §5.8 states
	wounded residents still count, and a dead row does not. Refuses when the settlement has no
	living resident: §5.8 gives no food-days value for a demand of zero and a division there
	would either divide by zero or display an infinite reserve.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	daily_demand_np_into(out)
	return out


func daily_demand_np_into(out: IntMath.IntResult) -> bool:
	"""Non-allocating daily_demand_np(): write the demand into `out` and return out.ok.

	`out` is caller-owned and doubles as this call's scratch, so it must not be a result the
	caller still needs. Nothing is allocated per resident.
	"""
	var season: int = season_multiplier()
	var total: int = 0
	var counted: int = 0
	for index: int in _live_count:
		var slot: int = _live_slots[index]
		if not _needs.is_alive(slot):
			continue
		if not _demand_of_size_into(_size_class[slot], season, out):
			return false
		if not IntMath.checked_add_into(total, out.value, out):
			return false
		total = out.value
		counted += 1
	if counted == 0:
		return out.refuse(String(REFUSE_NO_LIVING_RESIDENTS))
	return out.succeed(total)


func daily_demand_for_cohort(small: int, medium: int, large: int) -> IntMath.IntResult:
	"""Daily demand of a hypothetical size cohort, for forecasts and the §7.1 fixtures.

	Reads no store state except the season, so a projection cannot mutate or depend on the live
	population. Refuses a negative count or an empty cohort.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if small < 0 or medium < 0 or large < 0:
		out.refuse(String(REFUSE_INVALID_COUNT))
		return out
	if small + medium + large == 0:
		out.refuse(String(REFUSE_NO_LIVING_RESIDENTS))
		return out
	_cohort_demand_into(small, medium, large, out)
	return out


func _cohort_demand_into(small: int, medium: int, large: int, out: IntMath.IntResult) -> bool:
	"""Sum the three size classes' demands, each already scaled by today's season multiplier."""
	var season: int = season_multiplier()
	var counts: Array[int] = [small, medium, large]
	var total: int = 0
	for size_class: int in SIZE_COUNT:
		if not _demand_of_size_into(size_class, season, out):
			return false
		if not IntMath.checked_mul_into(out.value, counts[size_class], out):
			return false
		if not IntMath.checked_add_into(total, out.value, out):
			return false
		total = out.value
	return out.succeed(total)


# --- Equipment mirror (GDD §4.2 Equipment; decision 0061) ------------------------------------

func equipment_payload_bytes() -> int:
	"""Bytes the four ledgered Equipment columns actually occupy, re-derived from the columns.

	Evidence for the §3 ledger rather than a transcribed constant: a column length change moves
	this number and the test that pins it fails.
	"""
	return 4 * (_equip_tool_item_id.size() + _equip_tool_durability.size()
		+ _equip_satchel_slot.size() + _equip_satchel_generation.size())


func _clear_equipment_row(slot: int) -> void:
	"""Reset one row's Equipment columns to "nothing equipped, no satchel". Caller bounds `slot`."""
	_equip_tool_item_id[slot] = NO_TOOL_ITEM
	_equip_tool_durability[slot] = 0
	_equip_satchel_slot[slot] = EntityDirectory.NULL_SLOT
	_equip_satchel_generation[slot] = EntityDirectory.NULL_GENERATION


func has_equipped_tool(slot: int) -> bool:
	"""True when a present resident row currently mirrors an equipped tool."""
	return is_present(slot) and _equip_tool_item_id[slot] != NO_TOOL_ITEM


func equipped_tool_item_id_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Write the mirrored equipped tool's compiled item id into `out`, or refuse explicitly."""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if _equip_tool_item_id[slot] == NO_TOOL_ITEM:
		return out.refuse(String(REFUSE_NO_EQUIPPED_TOOL))
	return out.succeed(_equip_tool_item_id[slot])


func equipped_tool_durability_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Write the mirrored equipped tool's durability into `out`, or refuse explicitly.

	The authoritative value is the `GearInstance` row; this is the resident-side view `gear.gd`
	writes through on every durability change.
	"""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if _equip_tool_item_id[slot] == NO_TOOL_ITEM:
		return out.refuse(String(REFUSE_NO_EQUIPPED_TOOL))
	return out.succeed(_equip_tool_durability[slot])


func set_equipped_tool(slot: int, item_id: int, durability: int) -> OpResult:
	"""Write the mirror for a newly equipped tool. `gear.equip()` is the only legitimate caller.

	Refuses an occupied row rather than overwriting it: §4.2 gives a resident exactly one tool
	field, so a second equip is a caller error and not a silent replacement.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _equip_tool_item_id[slot] != NO_TOOL_ITEM:
		return _refuse(REFUSE_TOOL_ALREADY_EQUIPPED)
	if item_id < 0 or not IntMath.fits_int32(item_id):
		return _refuse(REFUSE_INVALID_ITEM_ID)
	if durability < 0 or not IntMath.fits_int32(durability):
		return _refuse(REFUSE_INVALID_DURABILITY)
	_equip_tool_item_id[slot] = item_id
	_equip_tool_durability[slot] = durability
	return _succeed(durability, ref_of(slot))


func set_equipped_tool_durability(slot: int, durability: int) -> OpResult:
	"""Refresh the mirrored durability of an already equipped tool, or refuse.

	`gear.gd` funnels every durability write through this, so wear and repair cannot leave the
	mirror behind. Refusing on an empty row is what keeps it from inventing an equipped tool.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _equip_tool_item_id[slot] == NO_TOOL_ITEM:
		return _refuse(REFUSE_NO_EQUIPPED_TOOL)
	if durability < 0 or not IntMath.fits_int32(durability):
		return _refuse(REFUSE_INVALID_DURABILITY)
	_equip_tool_durability[slot] = durability
	return _succeed(durability, ref_of(slot))


func clear_equipped_tool(slot: int) -> OpResult:
	"""Empty the mirrored tool fields. `gear.unequip()` is the only legitimate caller."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _equip_tool_item_id[slot] == NO_TOOL_ITEM:
		return _refuse(REFUSE_NO_EQUIPPED_TOOL)
	_equip_tool_item_id[slot] = NO_TOOL_ITEM
	_equip_tool_durability[slot] = 0
	return _succeed(0, ref_of(slot))


func satchel_of(slot: int) -> Vector2i:
	"""The resident's satchel container reference, or the null reference when it has none."""
	if not is_present(slot):
		return NULL_REF
	return Vector2i(_equip_satchel_slot[slot], _equip_satchel_generation[slot])


func set_satchel(slot: int, container_ref: Vector2i) -> OpResult:
	"""Bind or clear a resident's satchel container reference.

	The container itself is `inventory.gd`'s; this stores only the §4.2 reference. Equipped gear
	is outside satchel capacity (GDD §5.7) by construction: an equipped lot sits in no container
	at all, so it can charge no satchel mass.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if container_ref != NULL_REF and (container_ref.x < 0 or container_ref.y <= 0):
		return _refuse(REFUSE_INVALID_CONTAINER)
	_equip_satchel_slot[slot] = container_ref.x
	_equip_satchel_generation[slot] = container_ref.y
	return _succeed(container_ref.x, ref_of(slot))


func equipment_state_bytes() -> PackedByteArray:
	"""Exact image of the four Equipment columns, for byte-identical rollback checks.

	NOT a production call: it allocates. Every column at its full allocated length, so two images
	of identical state compare equal and a half-applied equip does not.
	"""
	var out: PackedByteArray = PackedByteArray()
	out.append_array(var_to_bytes(_equip_tool_item_id))
	out.append_array(var_to_bytes(_equip_tool_durability))
	out.append_array(var_to_bytes(_equip_satchel_slot))
	out.append_array(var_to_bytes(_equip_satchel_generation))
	return out


# --- result helpers -------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never
	carries a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)


func _read_value(value: int) -> IntMath.IntResult:
	"""Build a reader's successful IntResult."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	out.succeed(value)
	return out


func _read_refusal(code: StringName) -> IntMath.IntResult:
	"""Build a reader's refused IntResult, which carries value 0 and the reason."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	out.refuse(String(code))
	return out


# --- ARCH-SAVE-002 section 4 bulk column API (decision 0132) ----------------------------------
#
# Section 4 COMPONENT_COLUMNS captures and applies this store's nineteen category-1 columns as one
# set. Every other reader here refuses a row whose `_present` is 0, so a FREE row's retained
# bytes were unreachable without reaching into `_species` or `_skill_xp` from another file. No
# module in this repository reads another's private columns, and this pair is what makes that
# unnecessary for section 4.
#
# `docs/persistence_state_registry.md` classifies every member and
# `docs/planning/canonical_state_registry.json` numbers the nineteen ordinals; COLUMN_KEYS is
# transcribed from that artifact in its ordinal order, and `test_residents.gd` re-reads the
# artifact and compares.
#
# `_name_key` IS NOT HERE, AND ITS ABSENCE IS THE CONTRACT. The registry assigns it to §14
# NAME_POOL, while §4 owns the `_named` flag beside it. `restore_columns()` therefore installs
# `_named` and empties every name, and §14 completes each present row through the ONE name entry
# point decision 0112 published, `restore_name()`, which takes both halves and refuses their
# disagreement. There is no second name path here. Between the two sections a restored named row
# holds a flag with no string; `unresolved_name_row_count()` counts exactly those rows, so a load
# that never ran §14 is observable rather than silent.
#
# `_selected` IS NOT HERE EITHER: ARCH-HASH-001 excludes selection by name and the registry
# classifies it category 3.
#
# GENERATION NAMESPACES, WHICH ARE NOT ONE NAMESPACE. `_ref_*`, `_home_*` and `_bed_*` are
# DIRECTORY generations and are validated as such. `_equip_satchel_generation` is an
# `inventory.gd` CONTAINER generation and is checked for shape only -- this store holds no
# inventory, so validating it against the directory would accept a stale handle whose two
# integers happen to match a live directory slot. Lot and route generations do not appear here.

const COLUMN_TYPE_U8: int = 0
const COLUMN_TYPE_I32: int = 2
const COLUMN_TYPE_I64: int = 4

## The nineteen §4 category-1 columns in the registry's declared ordinal order.
const COLUMN_COUNT: int = 19
const COLUMN_KEYS: Array[StringName] = [
	&"_present", &"_species", &"_size_class", &"_named", &"_life_stage", &"_arrival_tick",
	&"_role", &"_home_slot", &"_home_generation", &"_bed_slot", &"_bed_generation",
	&"_ref_slot", &"_ref_generation", &"_equip_tool_item_id", &"_equip_tool_durability",
	&"_equip_satchel_slot", &"_equip_satchel_generation", &"_skill_xp", &"_skill_level",
]
const COLUMN_TYPE_CODES: Array[int] = [
	COLUMN_TYPE_U8, COLUMN_TYPE_I32, COLUMN_TYPE_U8, COLUMN_TYPE_U8, COLUMN_TYPE_U8,
	COLUMN_TYPE_I64, COLUMN_TYPE_U8, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I32,
	COLUMN_TYPE_I32, COLUMN_TYPE_I32, COLUMN_TYPE_I64, COLUMN_TYPE_I32,
]
const COLUMN_EXTENTS: Array[int] = [
	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
	RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY, RESIDENT_CAPACITY,
	RESIDENT_CAPACITY, RESIDENT_CAPACITY * SKILL_COUNT, RESIDENT_CAPACITY * SKILL_COUNT,
]

## Bulk column refusals, read through `last_column_refusal()` and never through an OpResult.
## Every code is prefixed `COLUMN_`, so a load can never clobber the reason a `spawn()` or a
## `set_name()` was refused before its caller read it, and no code value is shared with those.
const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSE_COLUMN_CATALOG: StringName = &"COLUMN_SPECIES_CATALOG"
const REFUSE_COLUMN_PRESENT_BYTE: StringName = &"COLUMN_PRESENT_BYTE"
const REFUSE_COLUMN_NAMED_BYTE: StringName = &"COLUMN_NAMED_BYTE"
const REFUSE_COLUMN_ENUM_BYTE: StringName = &"COLUMN_ENUM_BYTE"
const REFUSE_COLUMN_SPECIES: StringName = &"COLUMN_SPECIES"
const REFUSE_COLUMN_SIZE_CLASS: StringName = &"COLUMN_SIZE_CLASS_MISMATCH"
const REFUSE_COLUMN_ARRIVAL_TICK: StringName = &"COLUMN_ARRIVAL_TICK"
const REFUSE_COLUMN_REF_SHAPE: StringName = &"COLUMN_REF_SHAPE"
const REFUSE_COLUMN_DIRECTORY_REF: StringName = &"COLUMN_DIRECTORY_REF"
const REFUSE_COLUMN_EQUIPMENT: StringName = &"COLUMN_EQUIPMENT"
const REFUSE_COLUMN_SKILL_XP: StringName = &"COLUMN_SKILL_XP"
const REFUSE_COLUMN_SKILL_LEVEL: StringName = &"COLUMN_SKILL_LEVEL"
const REFUSE_COLUMN_RESERVED_SKILL: StringName = &"COLUMN_RESERVED_SKILL"
const REFUSE_COLUMN_FREE_ROW: StringName = &"COLUMN_FREE_ROW"
const REFUSE_COLUMN_LIVING_CAP: StringName = &"COLUMN_LIVING_CAP"


class Columns:
	"""Caller-owned image of the nineteen §4 category-1 columns, allocated once to capacity.

	One object per save or per load, never one per resident. Field order is COLUMN_KEYS order,
	which is the registry's ordinal order. `name_key` is deliberately absent: it is §14's.
	"""
	var present: PackedByteArray = PackedByteArray()
	var species: PackedInt32Array = PackedInt32Array()
	var size_class: PackedByteArray = PackedByteArray()
	var named: PackedByteArray = PackedByteArray()
	var life_stage: PackedByteArray = PackedByteArray()
	var arrival_tick: PackedInt64Array = PackedInt64Array()
	var role: PackedByteArray = PackedByteArray()
	var home_slot: PackedInt32Array = PackedInt32Array()
	var home_generation: PackedInt32Array = PackedInt32Array()
	var bed_slot: PackedInt32Array = PackedInt32Array()
	var bed_generation: PackedInt32Array = PackedInt32Array()
	var ref_slot: PackedInt32Array = PackedInt32Array()
	var ref_generation: PackedInt32Array = PackedInt32Array()
	var equip_tool_item_id: PackedInt32Array = PackedInt32Array()
	var equip_tool_durability: PackedInt32Array = PackedInt32Array()
	var equip_satchel_slot: PackedInt32Array = PackedInt32Array()
	var equip_satchel_generation: PackedInt32Array = PackedInt32Array()
	var skill_xp: PackedInt64Array = PackedInt64Array()
	var skill_level: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Size all nineteen columns to their declared extents. The only place this class resizes."""
		skill_xp.resize(RESIDENT_CAPACITY * SKILL_COUNT)
		skill_level.resize(RESIDENT_CAPACITY * SKILL_COUNT)
		arrival_tick.resize(RESIDENT_CAPACITY)
		for column: PackedInt32Array in [species, home_slot, home_generation, bed_slot,
				bed_generation, ref_slot, ref_generation, equip_tool_item_id,
				equip_tool_durability, equip_satchel_slot, equip_satchel_generation]:
			column.resize(RESIDENT_CAPACITY)
		for column: PackedByteArray in [present, size_class, named, life_stage, role]:
			column.resize(RESIDENT_CAPACITY)
		clear()

	func clear() -> void:
		"""Refill every column with the value this store's own `clear()` leaves, not with zero.

		The six reference columns go to the §4.1 null pair `(-1, 0)` and the equipped tool to
		`NO_TOOL_ITEM`; "use zero only where the owner declares zero".
		"""
		skill_xp.fill(0)
		skill_level.fill(0)
		arrival_tick.fill(0)
		species.fill(0)
		for column: PackedInt32Array in [home_slot, bed_slot, ref_slot, equip_satchel_slot]:
			column.fill(EntityDirectory.NULL_SLOT)
		for column: PackedInt32Array in [home_generation, bed_generation, ref_generation,
				equip_satchel_generation]:
			column.fill(EntityDirectory.NULL_GENERATION)
		equip_tool_item_id.fill(NO_TOOL_ITEM)
		equip_tool_durability.fill(0)
		present.fill(0)
		named.fill(0)
		size_class.fill(SIZE_SMALL)
		life_stage.fill(LIFE_STAGE_ADULT)
		role.fill(ROLE_RESIDENT)

	func equals(other: Columns) -> bool:
		"""True when all nineteen columns are byte-identical. Proves a refusal changed nothing."""
		return present == other.present and species == other.species \
			and size_class == other.size_class and named == other.named \
			and life_stage == other.life_stage and arrival_tick == other.arrival_tick \
			and role == other.role and home_slot == other.home_slot \
			and home_generation == other.home_generation and bed_slot == other.bed_slot \
			and bed_generation == other.bed_generation and ref_slot == other.ref_slot \
			and ref_generation == other.ref_generation \
			and equip_tool_item_id == other.equip_tool_item_id \
			and equip_tool_durability == other.equip_tool_durability \
			and equip_satchel_slot == other.equip_satchel_slot \
			and equip_satchel_generation == other.equip_satchel_generation \
			and skill_xp == other.skill_xp and skill_level == other.skill_level


func last_column_refusal() -> StringName:
	"""The code from the most recent refused bulk column call, or REFUSE_NONE after a success.

	A SEPARATE channel from the OpResult every mutator returns, and from `catalog_error()`. A
	caller reads a spawn or name refusal off its own result; a load writing into that channel
	would make one operation report another's problem. Every code here is prefixed `COLUMN_`.
	"""
	return _last_column_refusal


func unresolved_name_row_count() -> int:
	"""Present rows whose `_named` flag is set but whose §14 name has not been installed yet.

	A restored section 4 carries the flag and no string, so this is the number of rows still
	owed a `restore_name()` call. Zero before any restore, zero again once §14 has run, and
	NON-ZERO in between -- which is what makes a load that skipped section 14 observable instead
	of silently leaving named residents with no name. It is a count and never a sentinel: no
	value of it encodes a failure.
	"""
	var total: int = 0
	var slot: int = _present.find(1, 0)
	while slot >= 0:
		if _named[slot] == 1 and _name_key[slot].is_empty():
			total += 1
		slot = _present.find(1, slot + 1)
	return total


func copy_columns_into(out: Columns) -> bool:
	"""Copy the nineteen §4 category-1 columns into caller-owned buffers. False refuses.

	Section 4's capture step, and the ONLY way to read a released row's retained species, skills
	or arrival tick -- `despawn()` leaves those columns at the last tenant's values and every
	public reader refuses the row. Section 14 captures `_name_key` separately through its own
	codec; it is not duplicated here.

	The copies are snapshots: mutating `out` afterwards cannot reach a column.
	"""
	if not _columns_are_capacity_sized(out):
		_last_column_refusal = REFUSE_COLUMN_SHAPE
		return false
	_refill_bytes(out.present, _present)
	_refill_bytes(out.size_class, _size_class)
	_refill_bytes(out.named, _named)
	_refill_bytes(out.life_stage, _life_stage)
	_refill_bytes(out.role, _role)
	_refill_i64(out.arrival_tick, _arrival_tick)
	_refill_i64(out.skill_xp, _skill_xp)
	_refill_i32(out.skill_level, _skill_level)
	_refill_i32(out.species, _species)
	_copy_reference_columns_into(out)
	_last_column_refusal = REFUSE_NONE
	return true


func _copy_reference_columns_into(out: Columns) -> void:
	"""Refill the ten reference and Equipment int32 columns. Split out to stay under 30 lines."""
	_refill_i32(out.home_slot, _home_slot)
	_refill_i32(out.home_generation, _home_generation)
	_refill_i32(out.bed_slot, _bed_slot)
	_refill_i32(out.bed_generation, _bed_generation)
	_refill_i32(out.ref_slot, _ref_slot)
	_refill_i32(out.ref_generation, _ref_generation)
	_refill_i32(out.equip_tool_item_id, _equip_tool_item_id)
	_refill_i32(out.equip_tool_durability, _equip_tool_durability)
	_refill_i32(out.equip_satchel_slot, _equip_satchel_slot)
	_refill_i32(out.equip_satchel_generation, _equip_satchel_generation)


func restore_columns(columns: Columns) -> bool:
	"""Replace the nineteen §4 columns, empty every name, and rebuild the live list. False refuses.

	Section 4's apply step, and it requires SECTION 3 TO HAVE BEEN RESTORED FIRST. Each present
	row's `(_ref_slot, _ref_generation)` is resolved through the directory and must name a live
	KIND_RESIDENT slot whose typed row is this row. That resolution IS the rebuild's validator, in
	the same way the directory's owner map is its own: a directory slot owns exactly one typed
	row, so two resident rows claiming one slot cannot both satisfy it, and a row whose reference
	the directory does not honour is refused rather than installed.

	`_live_slots` and `_live_count` are REBUILT ascending from the restored `_present`, never read
	from the caller. `_name_key` is emptied on every row: the names belong to §14 and a string
	left over from the previous world would be exactly the concealed corruption NAME-R02 forbids.
	`_selected` is not touched, being presentation state outside the canonical hash.

	Allocate before consume (decision 0059): every rule is checked before the first write, so a
	refusal leaves the store byte-identical and `state_bytes()` proves it by comparison.
	"""
	var refusal: StringName = _restore_column_refusal(columns)
	if refusal != REFUSE_NONE:
		_last_column_refusal = refusal
		return false
	_install_columns(columns)
	_name_key.fill(String(NO_NAME_KEY))
	_rebuild_live_slots()
	_last_column_refusal = REFUSE_NONE
	return true


func state_bytes() -> PackedByteArray:
	"""Diagnostic image of every member a restore can reach, for byte-identical rollback checks.

	NOT A PRODUCTION CALL: it allocates. Included: the nineteen persisted columns, `_name_key`
	(which a restore empties), the rebuilt live list over its live prefix, `_live_count` and
	`_selected`, so a restore that touched presentation state would show. Excluded: the live
	list's tail beyond `_live_count`, which is stale residue two identical stores can disagree
	on, and `_last_column_refusal`, which is category 3.
	"""
	var image: PackedByteArray = PackedByteArray()
	image.append_array(_present)
	image.append_array(_species.to_byte_array())
	for column: PackedByteArray in [_size_class, _named, _life_stage, _role, _selected]:
		image.append_array(column)
	image.append_array(_arrival_tick.to_byte_array())
	for column: PackedInt32Array in [_home_slot, _home_generation, _bed_slot, _bed_generation,
			_ref_slot, _ref_generation, _equip_tool_item_id, _equip_tool_durability,
			_equip_satchel_slot, _equip_satchel_generation, _skill_level]:
		image.append_array(column.to_byte_array())
	image.append_array(_skill_xp.to_byte_array())
	for slot: int in RESIDENT_CAPACITY:
		image.append_array(_name_key[slot].to_utf8_buffer())
		image.append_array(PackedInt32Array([_name_key[slot].length()]).to_byte_array())
	image.append_array(_live_slots.slice(0, _live_count).to_byte_array())
	image.append_array(PackedInt64Array([_live_count]).to_byte_array())
	return image


func _columns_are_capacity_sized(columns: Columns) -> bool:
	"""True when every one of the nineteen buffers is exactly its declared extent."""
	if columns.skill_xp.size() != RESIDENT_CAPACITY * SKILL_COUNT:
		return false
	if columns.skill_level.size() != RESIDENT_CAPACITY * SKILL_COUNT:
		return false
	if columns.arrival_tick.size() != RESIDENT_CAPACITY:
		return false
	for column: PackedInt32Array in [columns.species, columns.home_slot, columns.home_generation,
			columns.bed_slot, columns.bed_generation, columns.ref_slot, columns.ref_generation,
			columns.equip_tool_item_id, columns.equip_tool_durability,
			columns.equip_satchel_slot, columns.equip_satchel_generation]:
		if column.size() != RESIDENT_CAPACITY:
			return false
	for column: PackedByteArray in [columns.present, columns.size_class, columns.named,
			columns.life_stage, columns.role]:
		if column.size() != RESIDENT_CAPACITY:
			return false
	return true


func _restore_column_refusal(columns: Columns) -> StringName:
	"""Every rule a restored column set must satisfy, checked before a single column is written."""
	if _catalog_error != "":
		return REFUSE_COLUMN_CATALOG
	if not _columns_are_capacity_sized(columns):
		return REFUSE_COLUMN_SHAPE
	var bytes: StringName = _column_byte_domain_refusal(columns)
	if bytes != REFUSE_NONE:
		return bytes
	var skills: StringName = _column_skill_refusal(columns)
	if skills != REFUSE_NONE:
		return skills
	var references: StringName = _column_reference_refusal(columns)
	if references != REFUSE_NONE:
		return references
	var free_rows: StringName = _column_free_row_refusal(columns)
	if free_rows != REFUSE_NONE:
		return free_rows
	if columns.present.count(1) > RESIDENT_LIVING_CAP:
		return REFUSE_COLUMN_LIVING_CAP
	return _column_live_row_refusal(columns)


func _column_byte_domain_refusal(columns: Columns) -> StringName:
	"""Every byte column holds only values its own enumeration declares (ARCH-SAVE-005)."""
	if not _byte_column_below(columns.present, 2):
		return REFUSE_COLUMN_PRESENT_BYTE
	if not _byte_column_below(columns.named, 2):
		return REFUSE_COLUMN_NAMED_BYTE
	if not _byte_column_below(columns.size_class, SIZE_COUNT):
		return REFUSE_COLUMN_ENUM_BYTE
	if not _byte_column_below(columns.life_stage, LIFE_STAGE_COUNT):
		return REFUSE_COLUMN_ENUM_BYTE
	if not _byte_column_below(columns.role, ROLE_COUNT):
		return REFUSE_COLUMN_ENUM_BYTE
	return REFUSE_NONE


func _column_skill_refusal(columns: Columns) -> StringName:
	"""XP is non-negative, every level is the §5.3 curve's own answer, and index 3 stays empty.

	Checked over the WHOLE column and not the live rows alone: `despawn()` leaves the skills of a
	released row untouched, so a free row still carries a consistent pair and a load that broke
	one would otherwise pass. The level rule reuses `skill_level_for_xp()`, so the restore path
	and `set_skill_xp()` cannot drift apart.
	"""
	if not _int64_column_within(columns.skill_xp, 0, IntMath.INT64_MAX):
		return REFUSE_COLUMN_SKILL_XP
	for index: int in RESIDENT_CAPACITY * SKILL_COUNT:
		if columns.skill_level[index] != skill_level_for_xp(columns.skill_xp[index]):
			return REFUSE_COLUMN_SKILL_LEVEL
	for slot: int in RESIDENT_CAPACITY:
		var reserved: int = slot * SKILL_COUNT + SKILL_RESERVED_INDEX
		if columns.skill_xp[reserved] != 0 or columns.skill_level[reserved] != 0:
			return REFUSE_COLUMN_RESERVED_SKILL
	return REFUSE_NONE


func _column_reference_refusal(columns: Columns) -> StringName:
	"""Shape of every stored reference pair and of the Equipment mirror, over the whole column.

	SHAPE ONLY, and by namespace. The home, bed and self references are DIRECTORY pairs and are
	resolved against the directory for live rows in `_column_live_row_refusal()`; the satchel pair
	is an `inventory.gd` CONTAINER pair and is checked here for well-formedness and nowhere for
	liveness, because this store holds no inventory to resolve it against.
	"""
	for slot: int in RESIDENT_CAPACITY:
		if not _is_well_formed_pair(columns.home_slot[slot], columns.home_generation[slot]):
			return REFUSE_COLUMN_REF_SHAPE
		if not _is_well_formed_pair(columns.bed_slot[slot], columns.bed_generation[slot]):
			return REFUSE_COLUMN_REF_SHAPE
		if not _is_well_formed_pair(columns.ref_slot[slot], columns.ref_generation[slot]):
			return REFUSE_COLUMN_REF_SHAPE
		if not _is_well_formed_pair(columns.equip_satchel_slot[slot],
				columns.equip_satchel_generation[slot]):
			return REFUSE_COLUMN_REF_SHAPE
		var item: int = columns.equip_tool_item_id[slot]
		var durability: int = columns.equip_tool_durability[slot]
		if item < NO_TOOL_ITEM or durability < 0:
			return REFUSE_COLUMN_EQUIPMENT
		if item == NO_TOOL_ITEM and durability != 0:
			return REFUSE_COLUMN_EQUIPMENT
	return REFUSE_NONE


func _is_well_formed_pair(slot: int, generation: int) -> bool:
	"""True for the §4.1 null pair `(-1, 0)` or any pair with slot >= 0 and generation > 0."""
	if slot == EntityDirectory.NULL_SLOT:
		return generation == EntityDirectory.NULL_GENERATION
	return slot >= 0 and generation > 0


func _column_free_row_refusal(columns: Columns) -> StringName:
	"""Every `_present == 0` row carries exactly what `despawn()` and `clear()` leave behind.

	The species, size class, arrival tick, home, bed and skills are NOT here, deliberately:
	`despawn()` leaves all six at the last tenant's values, so demanding an unused value would
	refuse a column set this store itself can produce. The `_named` half goes through the shared
	NAME-R02 table rather than a second copy of its rule.
	"""
	var slot: int = columns.present.find(0, 0)
	while slot >= 0:
		if name_occupancy_refusal(false, columns.named[slot] == 1, NO_NAME_KEY) != REFUSE_NONE:
			return REFUSE_COLUMN_FREE_ROW
		if columns.life_stage[slot] != LIFE_STAGE_ADULT or columns.role[slot] != ROLE_RESIDENT:
			return REFUSE_COLUMN_FREE_ROW
		if columns.ref_slot[slot] != EntityDirectory.NULL_SLOT:
			return REFUSE_COLUMN_FREE_ROW
		if columns.equip_tool_item_id[slot] != NO_TOOL_ITEM:
			return REFUSE_COLUMN_FREE_ROW
		if columns.equip_satchel_slot[slot] != EntityDirectory.NULL_SLOT:
			return REFUSE_COLUMN_FREE_ROW
		slot = columns.present.find(0, slot + 1)
	return REFUSE_NONE


func _column_live_row_refusal(columns: Columns) -> StringName:
	"""Each present row's species, size class, arrival tick and DIRECTORY self-reference.

	The size class is re-derived from the species table rather than trusted: `_write_spawn_row()`
	takes it from the catalog and nothing mutates it afterwards, so a save whose two disagree is
	corrupt rather than merely unusual. The reference resolution is the section-3 dependency
	named in `restore_columns()`.
	"""
	var slot: int = columns.present.find(1, 0)
	while slot >= 0:
		var species_id: int = columns.species[slot]
		if species_id < 0 or species_id >= SPECIES_COUNT:
			return REFUSE_COLUMN_SPECIES
		if columns.size_class[slot] != _species_size[species_id]:
			return REFUSE_COLUMN_SIZE_CLASS
		if columns.arrival_tick[slot] < 0:
			return REFUSE_COLUMN_ARRIVAL_TICK
		var ref: Vector2i = Vector2i(columns.ref_slot[slot], columns.ref_generation[slot])
		if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESIDENT):
			return REFUSE_COLUMN_DIRECTORY_REF
		if _directory.get_typed_row(ref) != slot:
			return REFUSE_COLUMN_DIRECTORY_REF
		slot = columns.present.find(1, slot + 1)
	return REFUSE_NONE


func _install_columns(columns: Columns) -> void:
	"""Take a private copy of each validated column. `duplicate()` so the caller cannot alias one."""
	_present = columns.present.duplicate()
	_species = columns.species.duplicate()
	_size_class = columns.size_class.duplicate()
	_named = columns.named.duplicate()
	_life_stage = columns.life_stage.duplicate()
	_arrival_tick = columns.arrival_tick.duplicate()
	_role = columns.role.duplicate()
	_home_slot = columns.home_slot.duplicate()
	_home_generation = columns.home_generation.duplicate()
	_bed_slot = columns.bed_slot.duplicate()
	_bed_generation = columns.bed_generation.duplicate()
	_ref_slot = columns.ref_slot.duplicate()
	_ref_generation = columns.ref_generation.duplicate()
	_equip_tool_item_id = columns.equip_tool_item_id.duplicate()
	_equip_tool_durability = columns.equip_tool_durability.duplicate()
	_equip_satchel_slot = columns.equip_satchel_slot.duplicate()
	_equip_satchel_generation = columns.equip_satchel_generation.duplicate()
	_skill_xp = columns.skill_xp.duplicate()
	_skill_level = columns.skill_level.duplicate()


func _rebuild_live_slots() -> void:
	"""Refill the live list ASCENDING from the INSTALLED `_present`, and recount it.

	Ascending is load-bearing rather than cosmetic: `_insert_live_slot()` keeps the live store's
	list ascending, so a restored store iterates residents in the same order as the one that
	saved it only if this rebuild reproduces that arrangement.
	"""
	_live_slots.fill(EntityDirectory.NULL_SLOT)
	_live_count = 0
	var slot: int = _present.find(1, 0)
	while slot >= 0:
		_live_slots[_live_count] = slot
		_live_count += 1
		slot = _present.find(1, slot + 1)


func _byte_column_below(column: PackedByteArray, bound: int) -> bool:
	"""True when every byte is in [0, bound). One C++ count per legal value, no per-row loop."""
	var total: int = 0
	for value: int in range(bound):
		total += column.count(value)
	return total == column.size()


func _int64_column_within(column: PackedInt64Array, low: int, high: int) -> bool:
	"""True when every signed int64 entry lies in [low, high]. Sorts a copy and reads both ends.

	The int32/int64 sign trap lives here: these arrive already read as SIGNED, so the bytes
	`00 00 00 80` are -2147483648 and not the 2147483648 no int32 can hold. The low bound is
	compared explicitly and nothing is clamped.
	"""
	var sorted: PackedInt64Array = column.duplicate()
	sorted.sort()
	return sorted[0] >= low and sorted[sorted.size() - 1] <= high


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
