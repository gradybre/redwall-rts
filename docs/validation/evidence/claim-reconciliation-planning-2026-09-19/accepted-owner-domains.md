# fishing.gd:290-311
```gdscript

## Read from catalog.gd, never mirrored: `Catalog.HABITAT_TYPE[...]` is a constant expression, so
## there is exactly one copy of each id (GDD §4.2's closing paragraph via decision 0018's rule).
const HABITAT_TYPE_DOMAIN: String = Catalog.HABITAT_TYPE_DOMAIN
const HABITAT_COAST: int = Catalog.HABITAT_TYPE["COAST"]
const HABITAT_LAKE: int = Catalog.HABITAT_TYPE["LAKE"]
const HABITAT_RIVER: int = Catalog.HABITAT_TYPE["RIVER"]
const HABITAT_TYPE_COUNT: int = 3

## §5.4: "Habitat effort capacity: river 4, lake 6, coast 6." Indexed by the COMPILED habitat id,
## so a caller can never supply a slot count that disagrees with the specification. _init()
## asserts each entry against its named habitat, so this literal cannot drift out of that order.
const RIVER_EFFORT_SLOTS: int = 4
const LAKE_EFFORT_SLOTS: int = 6
const COAST_EFFORT_SLOTS: int = 6
const EFFORT_SLOTS_BY_TYPE: Array[int] = [
	COAST_EFFORT_SLOTS, LAKE_EFFORT_SLOTS, RIVER_EFFORT_SLOTS,
]

# --- GDD §5.4 gear table: its "Workers/effort slots" column ONLY (see the header) -------------------

## §5.4's five gear rows. These are MODULE-LOCAL TABLE ROWS, not catalog ids: the gear catalog is
```

# fishing.gd:2760-2850
```gdscript

# SAVE-CLAIMS-R01 v2 -- APPEND FRAGMENT for godot/scripts/core/fishing.gd.
#
# This file is not a script of its own: it carries no `extends`, no preload and no redefinition
# of any existing fishing.gd member. Append it verbatim to the end of fishing.gd.
#
# It installs ONLY the eight section 7 FishingEffortClaim columns and their derived live count.
# Section 4's habitats and stocks, `_habitat_effort_used`, `_effort_total_scratch`, `_pending_*`,
# `_math*`, `_owns_directory` and every existing diagnostic are untouched, and no existing
# clearer, writer, rebuilder, aggregate validator, purge, release or hot mutator is called.
# The returned bool and the new diagnostic describe STRUCTURAL ADMISSION, not a reconciled
# world: actual row/Directory/Job association, reference liveness, habitat presence, per-habitat
# effort capacity and checked aggregate totals against SAVED section 4 columns all remain the
# coordinator's obligation under SAVE-CLAIM-RECONCILIATION.

# --- SAVE-CLAIMS-R01 v2: the FishingEffortClaim column block -------------------------------------

const COLUMN_FISH_CLAIM_SHAPE: StringName = &"COLUMN_FISH_CLAIM_SHAPE"
const COLUMN_FISH_CLAIM_OCCUPANCY: StringName = &"COLUMN_FISH_CLAIM_OCCUPANCY"
const COLUMN_FISH_CLAIM_BLANK: StringName = &"COLUMN_FISH_CLAIM_BLANK"
const COLUMN_FISH_CLAIM_REF: StringName = &"COLUMN_FISH_CLAIM_REF"
const COLUMN_FISH_CLAIM_SLOT_COUNT: StringName = &"COLUMN_FISH_CLAIM_SLOT_COUNT"
const COLUMN_FISH_CLAIM_SOURCE_COUNT: StringName = &"COLUMN_FISH_CLAIM_SOURCE_COUNT"

## The exact blank a released claim row carries, spelled from the directory's own empty values.
const CLAIM_COLUMN_BLANK_SLOT: int = EntityDirectory.NULL_SLOT
const CLAIM_COLUMN_BLANK_GENERATION: int = EntityDirectory.NULL_GENERATION
const CLAIM_COLUMN_BLANK_SLOT_COUNT: int = 0

## A stored habitat or Job reference is a DIRECTORY slot, not a typed row, so it is bounded by
## the directory's own capacity. The row index itself is the Expedition's typed row and is never
## looked up or reconstructed here.
const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1

## Code of the most recent claim-column refusal. Set only on refusal, cleared only on success,
## and separate from every existing diagnostic in this module.
var _last_claim_column_refusal: StringName = REFUSE_NONE


class EffortClaimColumns:
	"""The eight fixed claim columns, 512 cells each, with no metadata and no count field.

	The constructor takes no arguments: 512 is the native Expedition row capacity and cannot be
	reconfigured by a record. A freshly constructed record is the exact blank table.
	"""
	var effort_claim_active: PackedByteArray = PackedByteArray()
	var effort_claim_expedition_generation: PackedInt32Array = PackedInt32Array()
	## FISH-ID-R01's appended wire ordinal 7: the owner's stored Directory slot.
	var effort_claim_expedition_slot: PackedInt32Array = PackedInt32Array()
	var effort_claim_habitat_slot: PackedInt32Array = PackedInt32Array()
	var effort_claim_habitat_generation: PackedInt32Array = PackedInt32Array()
	var effort_claim_job_slot: PackedInt32Array = PackedInt32Array()
	var effort_claim_job_generation: PackedInt32Array = PackedInt32Array()
	var effort_claim_slot_count: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate all eight columns at 512 cells and fill each with its exact blank."""
		effort_claim_active.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_expedition_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_expedition_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_habitat_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_habitat_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_job_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_job_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_slot_count.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_active.fill(0)
		effort_claim_expedition_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		effort_claim_expedition_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		effort_claim_habitat_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		effort_claim_habitat_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		effort_claim_job_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		effort_claim_job_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		effort_claim_slot_count.fill(CLAIM_COLUMN_BLANK_SLOT_COUNT)


class EffortClaimTally:
	"""Per-call active-row tally. A tiny native object, never a per-row one and never a Dictionary."""
	var active_rows: int = 0


func last_claim_column_refusal() -> StringName:
	"""The code of the last claim-column refusal, or the empty code after a success."""
	return _last_claim_column_refusal


func claim_column_detail() -> String:
	"""The claim-column detail: an exact echo of the code, as the Gear owner precedent does."""
	return String(_last_claim_column_refusal)


func copy_effort_claim_columns_into(out: EffortClaimColumns) -> bool:
```

# fishing.gd:2950-3011
```gdscript
		expedition_generation: PackedInt32Array, expedition_slot: PackedInt32Array,
		habitat_slot: PackedInt32Array, habitat_generation: PackedInt32Array,
		job_slot: PackedInt32Array, job_generation: PackedInt32Array,
		slot_count: PackedInt32Array, tally: EffortClaimTally) -> StringName:
	"""The one payload validator, over eight typed arrays. REFUSE_NONE leaves the tally usable.

	Every active byte is validated across the WHOLE table before any per-row field is read, so a
	single stray flag cannot be masked by an earlier row's blank or field failure. Active rows
	are then validated in wire order: Expedition generation, habitat reference, Job reference,
	slot count, then the appended Expedition slot. No directory lookup and no per-habitat capacity lookup occurs here.
	"""
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if active[row] > 1:
			return COLUMN_FISH_CLAIM_OCCUPANCY
	var counted: int = 0
	var slot_ceiling: int = _max_effort_slot_capacity()
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if active[row] == 0:
			if expedition_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or expedition_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or habitat_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or habitat_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or job_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or job_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or slot_count[row] != CLAIM_COLUMN_BLANK_SLOT_COUNT:
				return COLUMN_FISH_CLAIM_BLANK
			continue
		counted += 1
		if expedition_generation[row] <= 0:
			return COLUMN_FISH_CLAIM_REF
		if habitat_slot[row] < 0 or habitat_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FISH_CLAIM_REF
		if habitat_generation[row] <= 0:
			return COLUMN_FISH_CLAIM_REF
		if job_slot[row] < 0 or job_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FISH_CLAIM_REF
		if job_generation[row] <= 0:
			return COLUMN_FISH_CLAIM_REF
		if slot_count[row] < 1 or slot_count[row] > slot_ceiling:
			return COLUMN_FISH_CLAIM_SLOT_COUNT
		if expedition_slot[row] < 0 or expedition_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FISH_CLAIM_REF
	tally.active_rows = counted
	return REFUSE_NONE


static func _max_effort_slot_capacity() -> int:
	"""The largest existing habitat effort capacity, read off EFFORT_SLOTS_BY_TYPE itself.

	A deliberately stronger owner gate than the codec's `>= 1`, and NOT a new gameplay cap: it
	is derived by integer iteration over the constants every existing public habitat write
	already uses, allocating no array and sorting nothing.
	"""
	var largest: int = 0
	for habitat_type: int in HABITAT_TYPE_COUNT:
		if EFFORT_SLOTS_BY_TYPE[habitat_type] > largest:
			largest = EFFORT_SLOTS_BY_TYPE[habitat_type]
	return largest


func _refuse_claim_column(code: StringName) -> bool:
	"""Record one claim-column refusal and return false. Changes no other field."""
```

# forage.gd:374-396
```gdscript
## scheme exists and none can drift.
const QUOTA_MODE_KEYS: Array[StringName] = [&"automatic", &"inherit", &"manual"]
## Ruling §4.6: Automatic is a BASIN mode, Inherit is a DESIGNATION mode, Manual is either.
const QUOTA_MODE_AUTOMATIC: int = 0
const QUOTA_MODE_INHERIT: int = 1
const QUOTA_MODE_MANUAL: int = 2
const QUOTA_MODE_COUNT: int = 3

## Ruling §4.6: "This policy uses an 80% stock management target", as `floor(800 * K / 1000)`.
const AUTOMATIC_TARGET_PER_1000: int = 800
const AUTOMATIC_TARGET_DENOMINATOR: int = 1000
## `floor((K - target) * r * S / 1000000) + 1000`, the existing additive 1 U regrowth term.
const AUTOMATIC_ALLOWANCE_DENOMINATOR: int = 1000000
const AUTOMATIC_ALLOWANCE_TERM_MILLI: int = MILLI_PER_UNIT

## Ruling §4.6: "Minimum is zero: no unlimited sentinel is supported. Maximum is `sum(K_i)` across
## the basin's five patches: currently 1180000 milli-U/day." `_init()` asserts the sum.
const MANUAL_QUOTA_MIN_MILLI: int = 0
const MANUAL_QUOTA_MAX_MILLI: int = 1180000

# --- packed payload accounting (ruling §4.7 / R05-QUOTA-024) --------------------------------------

const BYTES_PER_BYTE_COLUMN: int = 1
```

# forage.gd:3200-3290
```gdscript

# --- SAVE-CLAIMS-R01 v2: the ForageClaim column block --------------------------------------------

const COLUMN_FORAGE_CLAIM_SHAPE: StringName = &"COLUMN_FORAGE_CLAIM_SHAPE"
const COLUMN_FORAGE_CLAIM_OCCUPANCY: StringName = &"COLUMN_FORAGE_CLAIM_OCCUPANCY"
const COLUMN_FORAGE_CLAIM_BLANK: StringName = &"COLUMN_FORAGE_CLAIM_BLANK"
const COLUMN_FORAGE_CLAIM_REF: StringName = &"COLUMN_FORAGE_CLAIM_REF"
const COLUMN_FORAGE_CLAIM_KIND: StringName = &"COLUMN_FORAGE_CLAIM_KIND"
const COLUMN_FORAGE_CLAIM_QUANTITY: StringName = &"COLUMN_FORAGE_CLAIM_QUANTITY"
const COLUMN_FORAGE_CLAIM_ORDER_KEY: StringName = &"COLUMN_FORAGE_CLAIM_ORDER_KEY"
const COLUMN_FORAGE_CLAIM_SOURCE_COUNT: StringName = &"COLUMN_FORAGE_CLAIM_SOURCE_COUNT"

## The exact blank a released claim row carries.
const CLAIM_COLUMN_BLANK_SLOT: int = EntityDirectory.NULL_SLOT
const CLAIM_COLUMN_BLANK_GENERATION: int = EntityDirectory.NULL_GENERATION
const CLAIM_COLUMN_BLANK_KIND: int = -1
const CLAIM_COLUMN_BLANK_I64: int = 0

## Each stored zone reference is a DIRECTORY slot, not a claim row and not a typed zone row; the
## row index itself is the owning Job's typed row, so the stored Job slot is NOT equal to it.
const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1

## Code of the most recent claim-column refusal. Set only on refusal, cleared only on success,
## and deliberately separate from this module's existing section 1 diagnostic.
var _last_claim_column_refusal: StringName = REFUSE_NONE


class ForageClaimColumns:
	"""The eleven fixed claim columns, 8192 cells each, with no metadata and no count field.

	The constructor takes no arguments: 8192 is the native Job row capacity and cannot be
	reconfigured by a record. A freshly constructed record is the exact blank table.
	"""
	var claim_active: PackedByteArray = PackedByteArray()
	var claim_job_slot: PackedInt32Array = PackedInt32Array()
	var claim_job_generation: PackedInt32Array = PackedInt32Array()
	var claim_designation_slot: PackedInt32Array = PackedInt32Array()
	var claim_designation_generation: PackedInt32Array = PackedInt32Array()
	var claim_basin_slot: PackedInt32Array = PackedInt32Array()
	var claim_basin_generation: PackedInt32Array = PackedInt32Array()
	var claim_patch_kind: PackedInt32Array = PackedInt32Array()
	var claim_remaining_milli: PackedInt64Array = PackedInt64Array()
	var claim_created_tick: PackedInt64Array = PackedInt64Array()
	var claim_persistent_id: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate all eleven columns at 8192 cells and fill each with its exact blank."""
		claim_active.resize(FORAGE_CLAIM_CAPACITY)
		claim_job_slot.resize(FORAGE_CLAIM_CAPACITY)
		claim_job_generation.resize(FORAGE_CLAIM_CAPACITY)
		claim_designation_slot.resize(FORAGE_CLAIM_CAPACITY)
		claim_designation_generation.resize(FORAGE_CLAIM_CAPACITY)
		claim_basin_slot.resize(FORAGE_CLAIM_CAPACITY)
		claim_basin_generation.resize(FORAGE_CLAIM_CAPACITY)
		claim_patch_kind.resize(FORAGE_CLAIM_CAPACITY)
		claim_remaining_milli.resize(FORAGE_CLAIM_CAPACITY)
		claim_created_tick.resize(FORAGE_CLAIM_CAPACITY)
		claim_persistent_id.resize(FORAGE_CLAIM_CAPACITY)
		claim_active.fill(0)
		claim_job_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		claim_job_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		claim_designation_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		claim_designation_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		claim_basin_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		claim_basin_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		claim_patch_kind.fill(CLAIM_COLUMN_BLANK_KIND)
		claim_remaining_milli.fill(CLAIM_COLUMN_BLANK_I64)
		claim_created_tick.fill(CLAIM_COLUMN_BLANK_I64)
		claim_persistent_id.fill(CLAIM_COLUMN_BLANK_I64)


class ForageClaimTally:
	"""Per-call active-row tally. A tiny native object, never a per-row one and never a Dictionary."""
	var active_rows: int = 0


func last_claim_column_refusal() -> StringName:
	"""The code of the last claim-column refusal, or the empty code after a success."""
	return _last_claim_column_refusal


func claim_column_detail() -> String:
	"""The claim-column detail: an exact echo of the code, as the Gear owner precedent does."""
	return String(_last_claim_column_refusal)


func copy_forage_claim_columns_into(out: ForageClaimColumns) -> bool:
	"""Publish eleven independent duplicates of the live claim table, or refuse touching nothing.

	Order is deterministic and the first gate wins: caller null or any caller/live array length
	mismatch; the whole table's active bytes; ascending rows; and only THEN the native count
```

# forage.gd:3400-3465
```gdscript
func _forage_claim_payload_code(active: PackedByteArray, job_slot: PackedInt32Array,
		job_generation: PackedInt32Array, designation_slot: PackedInt32Array,
		designation_generation: PackedInt32Array, basin_slot: PackedInt32Array,
		basin_generation: PackedInt32Array, patch_kind: PackedInt32Array,
		remaining_milli: PackedInt64Array, created_tick: PackedInt64Array,
		persistent_id: PackedInt64Array, tally: ForageClaimTally) -> StringName:
	"""The one payload validator, over eleven typed arrays. REFUSE_NONE leaves the tally usable.

	Every active byte is validated across the WHOLE table before any per-row field is read. Active
	rows are then validated in wire order: the owning Job reference, the designation reference,
	the basin reference, the patch kind, the remaining quantity and the two ordering keys.

	A remaining quantity of zero REFUSES on an active row: a claim collected to zero is closed by
	existing code, so a live zero is corruption rather than an empty promise. The upper bound is
	the existing manual quota ceiling. Nothing is clamped or masked.
	"""
	for row: int in FORAGE_CLAIM_CAPACITY:
		if active[row] > 1:
			return COLUMN_FORAGE_CLAIM_OCCUPANCY
	var counted: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if active[row] == 0:
			if job_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or job_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or designation_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or designation_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or basin_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or basin_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or patch_kind[row] != CLAIM_COLUMN_BLANK_KIND \
					or remaining_milli[row] != CLAIM_COLUMN_BLANK_I64 \
					or created_tick[row] != CLAIM_COLUMN_BLANK_I64 \
					or persistent_id[row] != CLAIM_COLUMN_BLANK_I64:
				return COLUMN_FORAGE_CLAIM_BLANK
			continue
		counted += 1
		if job_slot[row] < 0 or job_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FORAGE_CLAIM_REF
		if job_generation[row] <= 0:
			return COLUMN_FORAGE_CLAIM_REF
		if designation_slot[row] < 0 \
				or designation_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FORAGE_CLAIM_REF
		if designation_generation[row] <= 0:
			return COLUMN_FORAGE_CLAIM_REF
		if basin_slot[row] < 0 or basin_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FORAGE_CLAIM_REF
		if basin_generation[row] <= 0:
			return COLUMN_FORAGE_CLAIM_REF
		if patch_kind[row] < 0 or patch_kind[row] >= PATCHES_PER_ZONE:
			return COLUMN_FORAGE_CLAIM_KIND
		if remaining_milli[row] < 1 or remaining_milli[row] > MANUAL_QUOTA_MAX_MILLI:
			return COLUMN_FORAGE_CLAIM_QUANTITY
		if created_tick[row] < 0 or persistent_id[row] < 0:
			return COLUMN_FORAGE_CLAIM_ORDER_KEY
	tally.active_rows = counted
	return REFUSE_NONE


func _refuse_claim_column(code: StringName) -> bool:
	"""Record one claim-column refusal and return false. Changes no other field."""
	_last_claim_column_refusal = code
	return false
```

# entity_directory.gd:63-140
```gdscript
## Largest int32. Bounds generation, persistent ID, and every packed column.
const MAX_INT32: int = 2147483647

## The first persistent identity a new world issues (REG-R01, §1 `_next_persistent_id`).
const PERSISTENT_ID_MIN: int = 1

## The cursor left AFTER the final signed-int32 identity has been issued. It is a legal SAVED
## cursor and an illegal COLUMN value: no live `_persistent_id` may ever carry it.
const PERSISTENT_ID_EXHAUSTED: int = MAX_INT32 + 1

## Kind IDs are the index of each key in ascending ASCII order (ARCH-ID-001).
const KIND_BUILDING: int = 0
const KIND_CONSTRUCTION: int = 1
const KIND_EXPEDITION: int = 2
const KIND_FARM_PLOT: int = 3
const KIND_FEAST: int = 4
const KIND_FISH_HABITAT: int = 5
const KIND_FURNITURE: int = 6
const KIND_HARVEST_ZONE: int = 7
const KIND_HIVE: int = 8
const KIND_INVENTORY_CONTAINER: int = 9
const KIND_INVENTORY_LOT: int = 10
const KIND_JOB: int = 11
const KIND_ORCHARD_PLOT: int = 12
const KIND_PRODUCTION_ORDER: int = 13
const KIND_RESIDENT: int = 14
const KIND_RESOURCE_NODE: int = 15
const KIND_ROOM: int = 16
const KIND_WORLD: int = 17
const KIND_COUNT: int = 18

## Kind keys in the ascending ASCII order that fixes the IDs above.
const KIND_KEYS: Array[StringName] = [
	&"building", &"construction", &"expedition", &"farm_plot", &"feast",
	&"fish_habitat", &"furniture", &"harvest_zone", &"hive",
	&"inventory_container", &"inventory_lot", &"job", &"orchard_plot",
	&"production_order", &"resident", &"resource_node", &"room", &"world",
]

## Maximum rows per kind, systems_architecture.md §2.1. Sums to DIRECTORY_CAPACITY.
const KIND_CAPACITY: Array[int] = [
	1024, 82944, 512, 4096, 1,
	32, 81920, 128, 1024,
	101376, 16384, 8192, 1024,
	32768, 512, 4096, 16384, 1,
]

## Refusal code per kind, ARCH-ID-004 `CAPACITY_<STORE>`. Precomputed so the
## refusal path never concatenates a string.
const KIND_CAPACITY_REFUSAL: Array[StringName] = [
	&"CAPACITY_BUILDING", &"CAPACITY_CONSTRUCTION", &"CAPACITY_EXPEDITION",
	&"CAPACITY_FARM_PLOT", &"CAPACITY_FEAST", &"CAPACITY_FISH_HABITAT",
	&"CAPACITY_FURNITURE", &"CAPACITY_HARVEST_ZONE", &"CAPACITY_HIVE",
	&"CAPACITY_INVENTORY_CONTAINER", &"CAPACITY_INVENTORY_LOT", &"CAPACITY_JOB",
	&"CAPACITY_ORCHARD_PLOT", &"CAPACITY_PRODUCTION_ORDER", &"CAPACITY_RESIDENT",
	&"CAPACITY_RESOURCE_NODE", &"CAPACITY_ROOM", &"CAPACITY_WORLD",
]

## Directory length G, systems_architecture.md §2.1.
const DIRECTORY_CAPACITY: int = 352418

## Resident storage is 512 slots but living residents never exceed 256 (GDD §4.1).
const RESIDENT_LIVING_CAP: int = 256

const REFUSAL_NONE: StringName = &""
const REFUSAL_UNKNOWN_KIND: StringName = &"UNKNOWN_KIND"
const REFUSAL_DIRECTORY_FULL: StringName = &"CAPACITY_DIRECTORY"
const REFUSAL_PERSISTENT_ID: StringName = &"PERSISTENT_ID_EXHAUSTED"
const REFUSAL_LIVING_CAP: StringName = &"LIVING_CAP_RESIDENT"

## Bulk column refusals, read through `last_column_refusal()` and never through `last_refusal()`.
## ARCH-ID-004 numbers the `create()` codes above; it publishes no registry for column operations,
## so these spellings are this module's PROPOSAL (decision 0105) and change if one lands.
const REFUSAL_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSAL_COLUMN_ACTIVE_BYTE: StringName = &"COLUMN_ACTIVE_BYTE"
const REFUSAL_COLUMN_RETIRED_BYTE: StringName = &"COLUMN_RETIRED_BYTE"
const REFUSAL_COLUMN_GENERATION_NEGATIVE: StringName = &"COLUMN_GENERATION_NEGATIVE"
const REFUSAL_COLUMN_LIVE_GENERATION: StringName = &"COLUMN_LIVE_GENERATION"
```
