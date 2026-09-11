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
##   * `SpeciesDefinition.rig_id` is required by §4.3 but its value is given for no species
##     anywhere in the specification, so no rig column exists here.
##   * §5.1 lists the starting cohort as "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels);
##     IDs 1-12" without stating which ID gets which species. INITIAL_SPECIES below takes the
##     sentence's own order. The §7.1 starter fixture depends only on the 10-small/2-medium
##     split, which every ordering produces, so the food-days arithmetic does not rest on this
##     reading -- but a later spec revision could reorder the individuals.

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

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
const REFUSE_NOT_PRESENT: StringName = &"RESIDENT_NOT_PRESENT"
const REFUSE_UNKNOWN_SPECIES: StringName = &"UNKNOWN_SPECIES"
const REFUSE_INVALID_ROLE: StringName = &"INVALID_ROLE"
const REFUSE_INVALID_SKILL: StringName = &"INVALID_SKILL"
const REFUSE_INVALID_XP: StringName = &"INVALID_XP"
const REFUSE_INVALID_COUNT: StringName = &"INVALID_COUNT"
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

# --- Resident columns (ARCH-MEM-001: packed, allocated once, indexed by typed row) -----------

var _present: PackedByteArray = PackedByteArray()
var _species: PackedInt32Array = PackedInt32Array()
var _size_class: PackedByteArray = PackedByteArray()
var _named: PackedByteArray = PackedByteArray()
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
	_compile_species()
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
	_present.fill(0)
	_species.fill(0)
	_size_class.fill(SIZE_SMALL)
	_named.fill(0)
	_name_key.fill(String(NO_NAME_KEY))
	_arrival_tick.fill(0)
	_role.fill(ROLE_RESIDENT)
	_selected.fill(0)
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
	_skill_xp.fill(0)
	_skill_level.fill(0)
	_live_slots.fill(EntityDirectory.NULL_SLOT)
	_live_count = 0
	_cohort_slots.fill(EntityDirectory.NULL_SLOT)
	if _owns_collaborators:
		_directory.clear()
		_needs.clear()


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
	"""Allocate one resident: a directory slot, a needs row, and this store's Resident columns.

	Refuses without allocating anything when the species is unknown or the catalog failed to
	compile. A directory refusal (living cap, capacity, persistent-id exhaustion) is passed
	through with its own ARCH-ID-004 code, and no needs row is attached.
	"""
	if _catalog_error != "":
		return _refuse(REFUSE_SPECIES_CATALOG)
	if not _species_ids.has(species_key_value):
		return _refuse(REFUSE_UNKNOWN_SPECIES)
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
	_write_spawn_row(slot, ref, species_id_value, size_class)
	return _succeed(slot, ref)


func _write_spawn_row(slot: int, ref: Vector2i, species_id_value: int, size_class: int) -> void:
	"""Write every Resident and Skills column of one freshly spawned row to its §4.2 default."""
	_present[slot] = 1
	_species[slot] = species_id_value
	_size_class[slot] = size_class
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
		var spawned: OpResult = spawn(INITIAL_SPECIES[index])
		if not spawned.ok:
			_rollback_cohort(index)
			return _refuse(spawned.error)
		_cohort_slots[index] = spawned.value
		_write_initial_resident(spawned.value, index)
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


func _write_initial_resident(slot: int, index: int) -> void:
	"""Apply the §5.1 role, name, arrival tick and starting XP to one starter resident."""
	_arrival_tick[slot] = INITIAL_ARRIVAL_TICK
	var is_warden: bool = index == WARDEN_INDEX
	if is_warden:
		_role[slot] = ROLE_WARDEN
		_named[slot] = 1
		_name_key[slot] = String(WARDEN_NAME)
	var base: int = slot * SKILL_COUNT
	for skill: int in SKILL_COUNT:
		if skill == SKILL_RESERVED_INDEX:
			continue
		var xp: int = INITIAL_ACTIVE_SKILL_XP
		if is_warden and skill == SKILL_KEEP:
			xp = WARDEN_KEEP_XP
		_skill_xp[base + skill] = xp
		_skill_level[base + skill] = skill_level_for_xp(xp)


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
	"""Name a resident, or clear the name by passing the empty name."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	_name_key[slot] = String(name_value)
	_named[slot] = 0 if name_value == NO_NAME_KEY else 1
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
	"""Point a resident at a home. Nothing allocates buildings yet, so callers pass NULL_REF."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	_home_slot[slot] = home_ref.x
	_home_generation[slot] = home_ref.y
	return _succeed(slot, ref_of(slot))


func set_bed(slot: int, bed_ref: Vector2i) -> OpResult:
	"""Point a resident at a bed. Nothing allocates furniture yet, so callers pass NULL_REF."""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
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
