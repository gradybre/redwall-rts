extends RefCounted
## GearInstance store: 16384 rows allocated from the lowest free index, with exclusive Job claims.
##
## Closes blocker **U5**. The ruling is `docs/rulings/2026-09-09_ready06_open_item_answers.md` §4,
## adopted by Brendan; the owning budget is `docs/systems_architecture.md` §3 (ARCH-STATE-001 and
## the new ARCH-STATE-007) and decision 0038.
##
## WHAT U5 ACTUALLY WAS. The 16384 rows and their 540672-byte fixed-field payload were already
## budgeted in §3 -- eight int32 columns plus one byte column. What was missing was the allocator
## and the ownership bookkeeping: nothing said which rows were live, which row a new gear object
## should take, or which Job exclusively holds a piece of gear while it works. This module adds
## exactly that, at the already-budgeted capacity. It does NOT mint one gear row per resident and
## it does NOT grow `entity_directory.gd`.
##
## | Storage                                            | Bytes  |
## |----------------------------------------------------|-------:|
## | `occupied` B8[16384]                                |  16384 |
## | free-row min-heap I32[16384]                        |  65536 |
## | free count I32                                      |      4 |
## | claim Job slot/generation, two I32[16384]           | 131072 |
## | **Additional packed payload**                       | **212996** |
##
## The allocator alone is 81924 bytes; the remaining 131072 identifies the Job that exclusively
## claims the gear, as REQ-SET-044 requires.
##
## ---------------------------------------------------------------------------------------
## NO RAW GEAR-ROW INDEX ESCAPES. Every public entry point is keyed on the gear object's
## `InventoryLot` reference and resolves the row internally, verifying the row's recorded
## `(lot_slot, lot_generation)` identity. A row index is an allocation detail with no generation
## of its own, so handing one out would be handing out a handle that silently re-points when the
## row is reused. If a later consumer needs a persistent `GearRef`, that needs its own budgeted
## generation column and retirement rule FIRST -- see "named next increments" below. Nothing here
## may be read as permission to add one.
##
## The cost of that choice is honest: `_resolve_row()` is a bounded ascending scan, stopping once
## it has passed every live row, because the ruling explicitly excludes "later reverse indexes"
## from this allocator's budget. Gear operations happen at cycle start, cycle completion, repair
## and manufacture -- never inside a per-tick loop -- and at realistic live counts (the 24 starter
## tools plus a handful of nets and traps) the scan ends after a couple of dozen comparisons. A
## lot-indexed reverse column is a separate, budgeted increment.
##
## ---------------------------------------------------------------------------------------
## DELIBERATE REDUNDANCY, DO NOT "TIDY". `_write_new_row()` initialises every column of a fresh
## row AND `_blank_row()` clears every column of a released one. Either alone would be enough for
## any path this module has today -- a mutation removing one is not observable -- and both are
## kept anyway, because the invariant is "a row is never half-written and never half-blanked",
## not "whichever of the two happens to run last is correct".
##
## ALLOCATE BEFORE CONSUME (the hazard decision 0024 named). `preflight_create()` answers
## "could this gear object exist?" -- pool capacity, item eligibility and manufacture validity --
## WITHOUT touching anything, so a manufacture transaction asks before it consumes wood and iron
## or creates a loose output lot. `create_gear()` re-checks everything itself, because state can
## move between the two calls, and refuses whole: a full pool leaves no half-written row, no
## consumed material and no orphan lot. Every field of a row is written before `occupied` is set,
## and `_free_row()` blanks the row before returning it to the heap.
##
## ---------------------------------------------------------------------------------------
## INSTANCE ELIGIBILITY IS A NAMED PREDICATE, NOT A CATEGORY TEST. `is_instance_required_item()`
## admits exactly `tool`, `net`, `trap`, `ice_kit` and `outfit_tier2`. `candle` shares their GEAR
## category and is deliberately NOT admitted: it stays ordinary stackable consumable inventory.
## That single counter-example is why "category == GEAR" is the wrong predicate, and it is why
## `test_gear.gd` tests the predicate independently of the category.
##
## Basic versus iron tool manufacture uses the EXISTING §5.7 recipe metadata (`tool` versus
## `iron_tool`), not a fabricated second item ID: both produce catalog item `tool`, and only the
## manufacture method differs -- 1000 cap versus 1500 cap. Starter tier-1 clothing stays the
## existing spawn-equipment tier (GDD §4.2 `Equipment.clothing_tier`); no `ItemDefinition` is
## invented for it.
##
## Tier-2 outfits keep identity so an equipment transfer can name a specific outfit, but their
## canonical durability and cap are 0/0 and both wear and repair are refused as INAPPLICABLE.
## This module therefore introduces no clothing degradation mechanic, which is what the ruling
## requires. An outfit is also not claimable: a claim reserves durability, and an outfit has
## none. Tier-2-clothing gating for an ice-kit cycle is an `Equipment` check, not a durability
## reservation.
##
## ---------------------------------------------------------------------------------------
## TWO WEAR MODELS, KEPT DISTINCT. Collapsing them would silently rewrite balance.
##
##   GENERAL (`tool`), GDD §5.7: "1 equipped tool durability per completed 10 WU; preserve
##   remainder across tasks". Basic tools cap 1000, iron tools cap 1500. Repair uses
##   **wood 1 + stone 0.5** and 30 WU to restore 200 points up to the cap.
##
##   FISHING (`net`, `trap`, `ice_kit`), GDD §5.4: cap 1000 for all of them, and a fixed per-cycle
##   wear read off the gear table -- net 20, trap 10, ice kit 20. Repair uses **wood 1 + rope
##   0.25** and 30 WU per 200 restored points.
##
## Repair CLAMPS to the model's own cap and is emphatically not a full durability reset; that
## clamp is the one the ruling states, and is the only clamp in this module. Everything else
## refuses.
##
## The general model's remainder is NOT stored here. `ResidentRuntime.wear_remainder` already
## carries it in the §3 ledger at length 512, and allocating a second copy would be exactly the
## double-allocation ARCH-STATE-005 forbids for the scan cursor. `apply_general_wear_into()`
## therefore takes the remainder in and hands the new one back: a parameterised operation this
## store owns, driven by whoever owns the resident row.
##
## ---------------------------------------------------------------------------------------
## CLAIMS BELONG TO THE JOB, NOT THE WORKER (decision 0017). One gear object carries at most one
## claim, held by the cycle/coordinator Job. Refused, explicitly:
##   * a second owner -- `GEAR_ALREADY_CLAIMED`, whoever asks;
##   * a repair or an equipment-ownership change while claimed -- `GEAR_CLAIMED`;
##   * a cycle whose available durability is below its specified wear -- `INSUFFICIENT_DURABILITY`,
##     so exact wear starts and one below refuses.
##
## The cycle's gear/method/wear contract is frozen STRUCTURALLY rather than by copying numbers
## into a column the ledger does not have: per-cycle wear is a pure function of the gear row
## (`cycle_wear_into()`), the row's item and manufacture cannot change once created, and nothing
## may repair or re-own the gear while the claim stands. A completion therefore cannot debit a
## different number from the one the claim was checked against.
##
## Completion applies wear exactly once and releases the claim, so a repeated completion finds no
## claim and refuses `GEAR_NOT_CLAIMED` rather than double-debiting. Cancellation before
## completion releases the claim and applies nothing; a repeated cancellation refuses the same
## way. Wear application is a parameterised operation this store owns -- it is NOT a callback into
## `jobs.gd`, because the Expedition and cycle columns that would drive one do not exist.
##
## ---------------------------------------------------------------------------------------
## SAVE AND LOAD. `occupied` and the authoritative fields are the saved state; the free heap is
## derived and is rebuilt ASCENDING by `finish_restore()`, so a loaded world allocates the same
## rows in the same order as the world that saved it. `state_bytes()` is the deterministic image,
## ordered by lot slot rather than by row index, so two worlds that allocated the same gear
## through different row histories compare equal. The save FORMAT itself does not exist yet --
## no header, chunk layout or version field is specified for this store -- so reading an image
## back is deferred, exactly as in `reservations.gd`.
##
## ---------------------------------------------------------------------------------------
## NAMED NEXT INCREMENTS -- documented, deliberately not faked here.
##
##  1. THE EQUIPPED-LOT INVENTORY AMENDMENT IS NOW DONE -- decision 0061, READY_07 §7.2 step 5.
##     `equip()` and `unequip()` below keep the SAME lot row and the SAME gear row alive across
##     the transition: no clone, no merge, no durability reset, no second lot. `inventory.gd` was
##     not weakened to admit a null container; it was tightened. It now demands a PROOF, and this
##     store is the thing that supplies it: `is_equipped_record()` is the attestation it calls,
##     and it answers true only for a live row whose `equipped` byte is set and whose recorded
##     owner is still a live KIND_RESIDENT in the directory. A lot with a null container that
##     nobody attests for is an orphan, which `inventory.audit()` refuses.
##
##     STILL OPEN, and named rather than guessed: `restore_row()` cannot restore an equipped
##     record. Doing so needs the matching InventoryLot image restored in the same step -- a lot
##     whose container is null and whose gear row attests -- and `inventory.gd` has no restore
##     path and this store has no save FORMAT. DEPENDENCY: the save module.
##
##     ALSO OPEN: only the general `tool` may be equipped. GDD §4.2's Equipment row is
##     `tool_item_id, tool_durability, clothing_tier, satchel`, so it has exactly one mirror
##     field pair and no field for a carried net, trap or ice kit, and tier-2 outfits transfer
##     through `clothing_tier`, which `needs.gd` owns and this store must not write. Equipping
##     those four refuses EQUIP_KIND_UNSUPPORTED rather than inventing a mirror field.
##     DEPENDENCY: an Equipment row shape that names carried gear, and needs.gd for outfits.
##
##  2. INSTALLED GEAR (boats and weirs). §5.4's weir and boat are installed structures, not
##     `ItemDefinition` inventory output, and the ruling states plainly that the boat
##     owner/instance discriminator is unresolved and belongs to the expedition/installed-gear
##     contract -- a boathouse is not identical to every boat it services. So no fake boat
##     `InventoryLot` is minted here, `WEAR_PER_CYCLE` carries no boat or weir entry, and
##     `set_owner()` admits only a live `KIND_RESIDENT` reference. Hand-net, trap and ice-kit
##     gear proceed without pretending installed-boat representation is settled. DEPENDENCY: the
##     expedition/installed-gear contract, whose owner capacity, discriminator and directory
##     delta must be recorded before it is implemented.
##
##  3. A PERSISTENT `GearRef`. Needs budgeted generations and a retirement rule; see above.
##
##  4. A LOT-INDEXED REVERSE COLUMN, if a profile ever shows the bounded scan mattering.
##
## ---------------------------------------------------------------------------------------
## RESOLVED, NOT SPECIFIED -- recorded as resolutions in decision 0038 rather than presented as
## rules the GDD states.
##
##  * `manufacture` is a TWO-MEMBER LOCAL domain (`MANUFACTURE_BASIC`, `MANUFACTURE_IRON`), not a
##    compiled `RecipeDefinition` id. `catalog_ids.gd` says outright that no module implements
##    the RecipeDefinition domain and that transcribing the balance tables into a registry would
##    be the hand-written second copy it exists to prevent, so no recipe id exists to store. The
##    ledger column is named `manufacture_recipe` and MUST be migrated to carry the compiled
##    recipe id once that domain is compiled; the byte layout is unchanged by the migration but
##    the values are not, so it moves the save digest.
##  * `MANUFACTURE_IRON` is refused for anything but `tool`, because `tool` is the only §5.7
##    output with two recipes.
##  * A general-tool wear application that exceeds the remaining durability debits the durability
##    to exactly 0 and reports `broke`. GDD §5.7 fixes the rate and says "Broken tools block
##    tool-required work"; it does not name this case. Refusing would leave completed work having
##    cost nothing, which is worse, and the floor at 0 is the break the GDD already describes.
##    The remainder is still carried forward, and the outcome reports the shortfall so a caller
##    cannot mistake it for a clean debit.
##  * An ice kit is a separate gear object from the net it modifies, so a frozen-lake cycle
##    claims and wears both, 20 each. §5.4 gives the ice kit its own construction cost, its own
##    wear column and its own row.

const Inventory := preload("res://scripts/core/inventory.gd")
const ItemDefinitions := preload("res://scripts/core/item_definitions.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Residents := preload("res://scripts/core/residents.gd")

## GearInstance rows, systems_architecture.md §3. Already budgeted before this change.
const ROW_CAPACITY: int = 16384
## InventoryLot rows, matching `inventory.gd`'s LOT_CAPACITY. Bounds every lot reference here.
const LOT_CAPACITY: int = 16384
## Job rows, systems_architecture.md §2.1. Bounds the claim columns.
const JOB_CAPACITY: int = 8192

## "No such row". A terminator for an internal lookup, NEVER a public refusal value.
const NULL_ROW: int = -1
const NULL_SLOT: int = -1
const NULL_GENERATION: int = 0
const NULL_REF: Vector2i = Vector2i(NULL_SLOT, NULL_GENERATION)

const INT32_MIN: int = -2147483648
const INT32_MAX: int = 2147483647

## ARCH-STATE-001: a gear lot is indivisible at exactly one unit.
const GEAR_LOT_QUANTITY_MILLI: int = 1000

## The five portable instance-required item keys (ruling §4). `candle` is GEAR and is NOT here.
const INSTANCE_REQUIRED_KEYS: Array[StringName] = [
	&"tool", &"net", &"trap", &"ice_kit", &"outfit_tier2",
]
const KEY_TOOL: StringName = &"tool"
const KEY_NET: StringName = &"net"
const KEY_TRAP: StringName = &"trap"
const KEY_ICE_KIT: StringName = &"ice_kit"
const KEY_OUTFIT_TIER2: StringName = &"outfit_tier2"

## Wear models. NONE is a real, applicable answer for tier-2 outfits, not a failure value.
const WEAR_MODEL_NONE: int = 0
const WEAR_MODEL_GENERAL: int = 1
const WEAR_MODEL_FISHING: int = 2

## Manufacture methods. A LOCAL two-member domain, not a compiled RecipeDefinition id.
const MANUFACTURE_BASIC: int = 0
const MANUFACTURE_IRON: int = 1

## GDD §5.7: "Basic tools cap 1000, iron tools cap 1500".
const CAP_GENERAL_BASIC: int = 1000
const CAP_GENERAL_IRON: int = 1500
## GDD §5.4: "Fishing gear durability is 0-1000".
const CAP_FISHING: int = 1000
## Ruling §4: tier-2 outfits have canonical durability and cap 0/0.
const CAP_OUTFIT: int = 0

## GDD §5.7: 1 durability per completed 10 WU. Work is carried in milli-WU throughout.
const MWU_PER_WU: int = 1000
const GENERAL_WEAR_MWU_PER_POINT: int = 10 * MWU_PER_WU

## GDD §5.4 gear table, "Wear/cycle". Weir 5 and boat 15 are INSTALLED gear and deliberately
## absent: see named next increment 2 in the header.
const WEAR_PER_CYCLE_NET: int = 20
const WEAR_PER_CYCLE_TRAP: int = 10
const WEAR_PER_CYCLE_ICE_KIT: int = 20

## Both repair recipes cost 30 WU and restore 200 points; their MATERIALS differ, and preserving
## that difference is an explicit requirement of the ruling.
const REPAIR_WORK_MWU: int = 30 * MWU_PER_WU
const REPAIR_DURABILITY_PER_JOB: int = 200
## GDD §5.7 general-tool repair: wood 1 + stone 0.5.
const REPAIR_GENERAL_WOOD_MILLI: int = 1000
const REPAIR_GENERAL_SECONDARY_MILLI: int = 500
const REPAIR_GENERAL_SECONDARY_KEY: StringName = &"stone"
## GDD §5.4 fishing-gear repair: wood 1 + rope 0.25.
const REPAIR_FISHING_WOOD_MILLI: int = 1000
const REPAIR_FISHING_SECONDARY_MILLI: int = 250
const REPAIR_FISHING_SECONDARY_KEY: StringName = &"rope"
const REPAIR_WOOD_KEY: StringName = &"wood"

## Ruling §4's ledger, in bytes at full capacity. `allocator_bytes()` and `claim_bytes()`
## re-derive these from the columns actually allocated, so a layout change cannot drift.
const BUDGET_ALLOCATOR_BYTES: int = 81924
const BUDGET_CLAIM_BYTES: int = 131072
const BUDGET_ADDITIONAL_BYTES: int = 212996
## The fixed-field payload §3 already carried before this change: 8 x I32 + 1 x B8 at 16384.
const BUDGET_PAYLOAD_BYTES: int = 540672

const REFUSE_NONE: StringName = &""
const REFUSE_NO_INVENTORY: StringName = &"NO_INVENTORY"
const REFUSE_NO_DEFINITIONS: StringName = &"NO_DEFINITIONS"
const REFUSE_NO_DIRECTORY: StringName = &"NO_DIRECTORY"
const REFUSE_DEFINITIONS_NOT_LOADED: StringName = &"DEFINITIONS_NOT_LOADED"
const REFUSE_INVENTORY_TRANSACTION_OPEN: StringName = &"INVENTORY_TRANSACTION_OPEN"
const REFUSE_LOT_OUT_OF_RANGE: StringName = &"LOT_OUT_OF_RANGE"
const REFUSE_INVALID_LOT: StringName = &"INVALID_LOT"
const REFUSE_LOT_STILL_LIVE: StringName = &"LOT_STILL_LIVE"
const REFUSE_NOT_INSTANCE_REQUIRED: StringName = &"GEAR_NOT_INSTANCE_REQUIRED"
const REFUSE_LOT_NOT_INDIVISIBLE: StringName = &"GEAR_LOT_NOT_INDIVISIBLE"
const REFUSE_GEAR_ALREADY_EXISTS: StringName = &"GEAR_ALREADY_EXISTS"
const REFUSE_GEAR_STALE_RECORD: StringName = &"GEAR_STALE_RECORD"
const REFUSE_NO_SUCH_GEAR: StringName = &"NO_SUCH_GEAR"
const REFUSE_CAPACITY_GEAR_INSTANCE: StringName = &"CAPACITY_GEAR_INSTANCE"
const REFUSE_INVALID_MANUFACTURE: StringName = &"INVALID_MANUFACTURE"
const REFUSE_INVALID_OWNER: StringName = &"INVALID_OWNER"
const REFUSE_OWNER_KIND_UNSUPPORTED: StringName = &"OWNER_KIND_UNSUPPORTED"
const REFUSE_JOB_OUT_OF_RANGE: StringName = &"JOB_OUT_OF_RANGE"
const REFUSE_INVALID_JOB: StringName = &"INVALID_JOB"
const REFUSE_GEAR_ALREADY_CLAIMED: StringName = &"GEAR_ALREADY_CLAIMED"
const REFUSE_GEAR_CLAIMED: StringName = &"GEAR_CLAIMED"
const REFUSE_GEAR_NOT_CLAIMED: StringName = &"GEAR_NOT_CLAIMED"
const REFUSE_GEAR_CLAIM_MISMATCH: StringName = &"GEAR_CLAIM_MISMATCH"
const REFUSE_GEAR_NOT_CLAIMABLE: StringName = &"GEAR_NOT_CLAIMABLE"
const REFUSE_INSUFFICIENT_DURABILITY: StringName = &"INSUFFICIENT_DURABILITY"
const REFUSE_REPAIR_INAPPLICABLE: StringName = &"REPAIR_INAPPLICABLE"
const REFUSE_WRONG_WEAR_MODEL: StringName = &"WRONG_WEAR_MODEL"
const REFUSE_INVALID_WORK: StringName = &"INVALID_WORK"
const REFUSE_INVALID_REMAINDER: StringName = &"INVALID_REMAINDER"
const REFUSE_INVALID_REPAIR_POINTS: StringName = &"INVALID_REPAIR_POINTS"
const REFUSE_INVALID_DURABILITY: StringName = &"INVALID_DURABILITY"
const REFUSE_ROW_OUT_OF_RANGE: StringName = &"ROW_OUT_OF_RANGE"
const REFUSE_ROW_OCCUPIED: StringName = &"ROW_OCCUPIED"
const REFUSE_ROW_NOT_INITIALISED: StringName = &"ROW_NOT_INITIALISED"
const REFUSE_RESTORE_OPEN: StringName = &"RESTORE_OPEN"
const REFUSE_RESTORE_NOT_OPEN: StringName = &"RESTORE_NOT_OPEN"
const REFUSE_AUDIT_OCCUPANCY: StringName = &"AUDIT_OCCUPANCY_MISMATCH"
const REFUSE_AUDIT_HEAP: StringName = &"AUDIT_HEAP_MISMATCH"
const REFUSE_AUDIT_DUPLICATE_LOT: StringName = &"AUDIT_DUPLICATE_LOT"
const REFUSE_AUDIT_DURABILITY: StringName = &"AUDIT_DURABILITY_RANGE"
const REFUSE_AUDIT_CLAIM: StringName = &"AUDIT_CLAIM_MALFORMED"
const REFUSE_NO_RESIDENTS: StringName = &"NO_RESIDENTS"
const REFUSE_NOT_BOUND: StringName = &"EQUIPMENT_NOT_BOUND"
const REFUSE_GEAR_EQUIPPED: StringName = &"GEAR_EQUIPPED"
const REFUSE_GEAR_NOT_EQUIPPED: StringName = &"GEAR_NOT_EQUIPPED"
const REFUSE_EQUIP_KIND_UNSUPPORTED: StringName = &"EQUIP_KIND_UNSUPPORTED"
const REFUSE_OWNER_NOT_RESIDENT_ROW: StringName = &"OWNER_NOT_RESIDENT_ROW"
const REFUSE_OWNER_ALREADY_EQUIPPED: StringName = &"OWNER_ALREADY_EQUIPPED"
const REFUSE_INVALID_OWNER_COUNT: StringName = &"INVALID_OWNER_COUNT"
const REFUSE_DUPLICATE_OWNER: StringName = &"DUPLICATE_OWNER"
const REFUSE_AUDIT_MIRROR: StringName = &"AUDIT_EQUIPMENT_MIRROR_MISMATCH"

## GDD §5.9's starter tool allotment, quoted rather than apportioned here: "The 24 initial tool
## units include 12 equipped tools (one per resident) and 12 stored tools; they are not
## duplicated", at "initial tool durability 1000". Tier-1 clothing is spawn equipment in the same
## sentence -- `needs.gd`'s `clothing_tier`, NOT twelve invented `outfit_tier2` ItemDefinitions.
const STARTER_TOOL_TOTAL: int = 24
const STARTER_TOOL_EQUIPPED: int = 12
const STARTER_TOOL_STORED: int = 12
const STARTER_TOOL_DURABILITY: int = CAP_GENERAL_BASIC


class WearOutcome:
	"""Caller-owned result of one wear application: no allocation on a repeated call.

	`durability_spent` is what was ACTUALLY debited, which is below the demand when the tool ran
	out mid-application; `broke` says so explicitly so a shortfall can never read as a clean
	debit. `remainder_after` is the §5.7 sub-point remainder to carry into the next task.
	"""
	var ok: bool = false
	var error: StringName = &""
	var durability_spent: int = 0
	var durability_after: int = 0
	var remainder_after: int = 0
	var broke: bool = false

	func succeed(p_spent: int, p_after: int, p_remainder: int, p_broke: bool) -> bool:
		"""Record a successful wear application; always returns true."""
		ok = true
		error = &""
		durability_spent = p_spent
		durability_after = p_after
		remainder_after = p_remainder
		broke = p_broke
		return true

	func refuse(p_error: StringName) -> bool:
		"""Record an explicit refusal that applied nothing; always returns false.

		Every field is zeroed rather than left stale, so an ignored refusal cannot surface an
		earlier application's numbers as if they belonged to this one.
		"""
		ok = false
		error = p_error
		durability_spent = 0
		durability_after = 0
		remainder_after = 0
		broke = false
		return false


# --- GearInstance payload columns (systems_architecture.md §3: 8 x I32 + 1 x B8) --------------
var _lot_slot: PackedInt32Array = PackedInt32Array()
var _lot_generation: PackedInt32Array = PackedInt32Array()
var _item_id: PackedInt32Array = PackedInt32Array()
var _durability: PackedInt32Array = PackedInt32Array()
var _durability_cap: PackedInt32Array = PackedInt32Array()
var _owner_slot: PackedInt32Array = PackedInt32Array()
var _owner_generation: PackedInt32Array = PackedInt32Array()
var _manufacture_recipe: PackedInt32Array = PackedInt32Array()
var _equipped: PackedByteArray = PackedByteArray()

# --- Allocator columns, ruling §4's ledger ----------------------------------------------------
## 1 while a row holds a live gear instance.
var _occupied: PackedByteArray = PackedByteArray()
## Free rows as a min-heap, so an allocation always returns the LOWEST free index. Same shape as
## `reservations.gd` and `entity_directory.gd`; a stack would reuse the most recently freed row.
var _free_heap: PackedInt32Array = PackedInt32Array()
var _free_count: int = 0

# --- Exclusive Job claim columns, ruling §4's ledger ------------------------------------------
var _claim_job_slot: PackedInt32Array = PackedInt32Array()
var _claim_job_generation: PackedInt32Array = PackedInt32Array()

## Compiled ids of the five instance-required keys, bound from the loaded catalog by
## `capture_item_ids()`. NOT a mirror of the catalog: five integers, rebound on every capture,
## existing only so a row reader need not depend on the caller still holding an
## `ItemDefinitions`. -1 until bound, which is why every row reader is written in the `_into`
## form and refuses rather than guessing a model.
var _id_tool: int = -1
var _id_net: int = -1
var _id_trap: int = -1
var _id_ice_kit: int = -1
var _id_outfit_tier2: int = -1

## Equip/unequip wiring. Not packed state and not saved: three collaborator references, exactly
## as `residents.gd` holds a directory. `bind_equipment()` is the only writer.
var _inventory: Inventory = null
var _directory_binding: EntityDirectory = null
var _residents: Residents = null

## Bootstrap scratch for `seed_starter_tools()`, sized once: the lot references it created so far,
## so a mid-seed refusal can undo exactly those and nothing else. Not simulation state.
var _seed_lot_slot: PackedInt32Array = PackedInt32Array()
var _seed_lot_generation: PackedInt32Array = PackedInt32Array()
var _seed_count: int = 0
## Live rows whose `equipped` byte is set. Maintained by equip/unequip alone -- destroy_gear()
## and set_owner() refuse while equipped -- and re-derived by audit().
var _equipped_count: int = 0

var _row_capacity: int = 0
var _active_count: int = 0
## True between `begin_restore()` and `finish_restore()`, while the free heap is not yet derived.
var _restoring: bool = false


func _init(p_row_capacity: int = ROW_CAPACITY) -> void:
	"""Allocate every column once at the requested capacity.

	The default is the specification bound. A bounded harness may ask for less; a larger request
	is clamped down, because the memory ledger fixes the maximum.
	"""
	_row_capacity = clampi(p_row_capacity, 1, ROW_CAPACITY)
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""The only place that sizes a packed column (ARCH-MEM-005: allocate once)."""
	_lot_slot.resize(_row_capacity)
	_lot_generation.resize(_row_capacity)
	_item_id.resize(_row_capacity)
	_durability.resize(_row_capacity)
	_durability_cap.resize(_row_capacity)
	_owner_slot.resize(_row_capacity)
	_owner_generation.resize(_row_capacity)
	_manufacture_recipe.resize(_row_capacity)
	_equipped.resize(_row_capacity)
	_occupied.resize(_row_capacity)
	_free_heap.resize(_row_capacity)
	_seed_lot_slot.resize(STARTER_TOOL_TOTAL)
	_seed_lot_generation.resize(STARTER_TOOL_TOTAL)
	_claim_job_slot.resize(_row_capacity)
	_claim_job_generation.resize(_row_capacity)


func clear() -> void:
	"""Drop every gear record and refill the free heap ascending, reallocating nothing.

	This is world teardown, not a gameplay operation: it destroys no inventory lot and releases
	no Job's claim anywhere else. A caller holding live gear lots must destroy their records
	first, or those lots outlive the instances that carried their durability.
	"""
	_lot_slot.fill(NULL_SLOT)
	_lot_generation.fill(NULL_GENERATION)
	_item_id.fill(-1)
	_durability.fill(0)
	_durability_cap.fill(0)
	_owner_slot.fill(NULL_SLOT)
	_owner_generation.fill(NULL_GENERATION)
	_manufacture_recipe.fill(MANUFACTURE_BASIC)
	_equipped.fill(0)
	_occupied.fill(0)
	_claim_job_slot.fill(NULL_SLOT)
	_claim_job_generation.fill(NULL_GENERATION)
	_refill_heap_ascending()
	_active_count = 0
	_equipped_count = 0
	_seed_count = 0
	_restoring = false


func _refill_heap_ascending() -> void:
	"""Put every unoccupied row into the heap in ascending order and recount the free rows.

	Ascending insertion already satisfies the min-heap property, so this is both the fresh-world
	fill and the ruling's "rebuild the heap ascending on load".
	"""
	var count: int = 0
	for row: int in range(_row_capacity):
		if _occupied[row] == 1:
			continue
		_free_heap[count] = row
		count += 1
	for index: int in range(count, _row_capacity):
		_free_heap[index] = NULL_ROW
	_free_count = count


# --- Capacity and budget ----------------------------------------------------------------------

func row_capacity() -> int:
	"""Total GearInstance rows this store was allocated."""
	return _row_capacity


func free_row_count() -> int:
	"""Gear rows still available to allocate."""
	return _free_count


func active_gear_count() -> int:
	"""Gear rows currently holding a live instance."""
	return _active_count


func allocator_bytes() -> int:
	"""Bytes of the ruling's allocator allocation, re-derived from the live columns.

	Occupancy byte column, free-row min-heap, and the int32 heap count. At full capacity this
	must equal BUDGET_ALLOCATOR_BYTES.
	"""
	return _occupied.size() + (_free_heap.size() * 4) + 4


func claim_bytes() -> int:
	"""Bytes of the exclusive-Job-claim columns, re-derived from the live columns."""
	return (_claim_job_slot.size() + _claim_job_generation.size()) * 4


func payload_bytes() -> int:
	"""Bytes of the GearInstance fixed-field payload §3 already budgeted before this change."""
	var int32_fields: int = _lot_slot.size() + _lot_generation.size() + _item_id.size() \
		+ _durability.size() + _durability_cap.size() + _owner_slot.size() \
		+ _owner_generation.size() + _manufacture_recipe.size()
	return (int32_fields * 4) + _equipped.size()


# --- Instance eligibility, a named predicate --------------------------------------------------

func is_instance_required_item(definitions: ItemDefinitions, compiled_item_id: int) -> bool:
	"""True for exactly the five portable instance-required keys of ruling §4.

	Deliberately NOT a category test: `candle` is category GEAR and returns false here, because
	it stays stackable consumable inventory. The compiled ids are read straight out of the loaded
	`ItemDefinitions` on every call rather than mirrored into a local table, so a recompiled
	catalog cannot leave a stale copy behind.
	"""
	if definitions == null or not definitions.is_loaded() or compiled_item_id < 0:
		return false
	for key: StringName in INSTANCE_REQUIRED_KEYS:
		if definitions.compiled_id(key) == compiled_item_id:
			return true
	return false


func wear_model_for_item_into(definitions: ItemDefinitions, compiled_item_id: int,
		out: IntMath.IntResult) -> bool:
	"""Write an instance-required item's wear model into `out`; refuse for anything else.

	WEAR_MODEL_NONE is a real answer -- it is the tier-2 outfit -- so this is written in the
	`_into` form rather than returning a model that could be mistaken for a failure.
	"""
	if not is_instance_required_item(definitions, compiled_item_id):
		return out.refuse(String(REFUSE_NOT_INSTANCE_REQUIRED))
	if compiled_item_id == definitions.compiled_id(KEY_TOOL):
		return out.succeed(WEAR_MODEL_GENERAL)
	if compiled_item_id == definitions.compiled_id(KEY_OUTFIT_TIER2):
		return out.succeed(WEAR_MODEL_NONE)
	return out.succeed(WEAR_MODEL_FISHING)


func cycle_wear_for_item_into(definitions: ItemDefinitions, compiled_item_id: int,
		out: IntMath.IntResult) -> bool:
	"""Write a fishing item's GDD §5.4 per-cycle wear into `out`; refuse for any other model.

	Weir 5 and boat 15 are installed gear with no ItemDefinition and are not answerable here.
	"""
	if not wear_model_for_item_into(definitions, compiled_item_id, out):
		return false
	if out.value != WEAR_MODEL_FISHING:
		return out.refuse(String(REFUSE_WRONG_WEAR_MODEL))
	if compiled_item_id == definitions.compiled_id(KEY_NET):
		return out.succeed(WEAR_PER_CYCLE_NET)
	if compiled_item_id == definitions.compiled_id(KEY_TRAP):
		return out.succeed(WEAR_PER_CYCLE_TRAP)
	return out.succeed(WEAR_PER_CYCLE_ICE_KIT)


func durability_cap_for_into(definitions: ItemDefinitions, compiled_item_id: int, manufacture: int,
		out: IntMath.IntResult) -> bool:
	"""Write the canonical cap for an item and manufacture method into `out`.

	General tools split 1000/1500 on the §5.7 `tool` versus `iron_tool` recipe; fishing gear is
	1000 whatever its manufacture; a tier-2 outfit is the ruling's canonical 0.
	"""
	if not is_manufacture_valid_for_item(definitions, compiled_item_id, manufacture):
		return out.refuse(String(REFUSE_INVALID_MANUFACTURE))
	if not wear_model_for_item_into(definitions, compiled_item_id, out):
		return false
	var model: int = out.value
	if model == WEAR_MODEL_NONE:
		return out.succeed(CAP_OUTFIT)
	if model == WEAR_MODEL_FISHING:
		return out.succeed(CAP_FISHING)
	return out.succeed(CAP_GENERAL_IRON if manufacture == MANUFACTURE_IRON else CAP_GENERAL_BASIC)


func is_manufacture_valid_for_item(definitions: ItemDefinitions, compiled_item_id: int,
		manufacture: int) -> bool:
	"""True when this manufacture method exists for this item under the §5.7 recipe table.

	`tool` is the only output with two recipes, so MANUFACTURE_IRON is valid for it alone.
	"""
	if not is_instance_required_item(definitions, compiled_item_id):
		return false
	if manufacture == MANUFACTURE_BASIC:
		return true
	if manufacture != MANUFACTURE_IRON:
		return false
	return compiled_item_id == definitions.compiled_id(KEY_TOOL)


# --- Creation ---------------------------------------------------------------------------------

func preflight_create(definitions: ItemDefinitions, compiled_item_id: int,
		manufacture: int) -> Inventory.OpResult:
	"""Answer "could this gear object exist?" without touching a single byte of state.

	A manufacture transaction calls this BEFORE it consumes materials or creates a loose output
	lot, so a full pool refuses while nothing has been spent -- the allocate-before-consume
	hazard decision 0024 named. `.value` is the free-row count at the moment of the check.
	"""
	if definitions == null:
		return _refuse(REFUSE_NO_DEFINITIONS)
	if not definitions.is_loaded():
		return _refuse(REFUSE_DEFINITIONS_NOT_LOADED)
	if not is_instance_required_item(definitions, compiled_item_id):
		return _refuse(REFUSE_NOT_INSTANCE_REQUIRED)
	if not is_manufacture_valid_for_item(definitions, compiled_item_id, manufacture):
		return _refuse(REFUSE_INVALID_MANUFACTURE)
	if _restoring:
		return _refuse(REFUSE_RESTORE_OPEN)
	if _free_count <= 0:
		return _refuse(REFUSE_CAPACITY_GEAR_INSTANCE)
	return _ok(NULL_REF, _free_count)


func create_gear(inventory: Inventory, definitions: ItemDefinitions, lot_ref: Vector2i,
		manufacture: int) -> Inventory.OpResult:
	"""Record one gear instance against an existing indivisible gear lot, or refuse whole.

	Durability starts at the item's canonical cap: §5.7's `iron_tool` produces "tool 1 at 1500
	durability" and §4.2's starter tools are at 1000, both of which are full. `.value` is the
	starting durability; `.ref` is the lot the instance now belongs to. A load path that must
	restore a partly worn instance uses `begin_restore()`/`restore_row()` instead.
	"""
	var code: StringName = _check_create(inventory, definitions, lot_ref, manufacture)
	if code != REFUSE_NONE:
		return _refuse(code)
	var compiled_item_id: int = inventory.lot_item_id(lot_ref)
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not durability_cap_for_into(definitions, compiled_item_id, manufacture, out):
		return _refuse(REFUSE_INVALID_MANUFACTURE)
	var bound: Inventory.OpResult = capture_item_ids(definitions)
	if not bound.ok:
		return bound
	var row: int = _allocate_row()
	_write_new_row(row, lot_ref, compiled_item_id, out.value, manufacture)
	if not _publish_row(row):
		_return_unpublished_row(row)
		return _refuse(REFUSE_ROW_NOT_INITIALISED)
	return _ok(lot_ref, out.value)


func _check_create(inventory: Inventory, definitions: ItemDefinitions, lot_ref: Vector2i,
		manufacture: int) -> StringName:
	"""Validate a create_gear() call completely before a single byte is written."""
	if inventory == null:
		return REFUSE_NO_INVENTORY
	if inventory.is_transaction_open():
		# A gear row written against an uncommitted lot would survive a rollback that erases the
		# lot, leaving an instance pointing at a reference that never existed. Refuse instead.
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	if lot_ref.x < 0 or lot_ref.x >= LOT_CAPACITY:
		return REFUSE_LOT_OUT_OF_RANGE
	if not inventory.is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	var preflight: Inventory.OpResult = preflight_create(definitions,
		inventory.lot_item_id(lot_ref), manufacture)
	if not preflight.ok:
		return preflight.error
	if inventory.lot_quantity_milli(lot_ref) != GEAR_LOT_QUANTITY_MILLI:
		return REFUSE_LOT_NOT_INDIVISIBLE
	return _check_lot_slot_free(lot_ref)


func _check_lot_slot_free(lot_ref: Vector2i) -> StringName:
	"""Refuse when this lot slot already carries a gear record, live or stale.

	A stale record -- same slot, older generation -- means a previous lot retired without its
	instance being destroyed. Refusing here forces the caller to clean it up explicitly rather
	than letting two rows quietly share one lot slot.
	"""
	var existing: int = _resolve_row_by_lot_slot(lot_ref.x)
	if existing == NULL_ROW:
		return REFUSE_NONE
	if _lot_generation[existing] == lot_ref.y:
		return REFUSE_GEAR_ALREADY_EXISTS
	return REFUSE_GEAR_STALE_RECORD


func _write_new_row(row: int, lot_ref: Vector2i, compiled_item_id: int, cap: int,
		manufacture: int) -> void:
	"""Write EVERY field of a freshly taken row. Runs strictly before `_publish_row()`."""
	_lot_slot[row] = lot_ref.x
	_lot_generation[row] = lot_ref.y
	_item_id[row] = compiled_item_id
	_durability[row] = cap
	_durability_cap[row] = cap
	_owner_slot[row] = NULL_SLOT
	_owner_generation[row] = NULL_GENERATION
	_manufacture_recipe[row] = manufacture
	_equipped[row] = 0
	_claim_job_slot[row] = NULL_SLOT
	_claim_job_generation[row] = NULL_GENERATION


func _publish_row(row: int) -> bool:
	"""Publish a fully initialised row, or refuse to publish it at all.

	The ruling requires every field to be initialised BEFORE occupancy is published. That order is
	enforced here rather than merely followed: publishing a row whose identity columns are still
	blank would make a half-written row visible to `_resolve_row()`, so this checks and returns
	false instead. A caller that gets false must return the row unpublished; there is no path that
	leaves an unpublished row marked occupied.
	"""
	if _item_id[row] < 0 or _lot_slot[row] == NULL_SLOT or _lot_generation[row] <= NULL_GENERATION:
		return false
	_occupied[row] = 1
	_active_count += 1
	return true


func _return_unpublished_row(row: int) -> void:
	"""Blank and re-heap a row that was taken but never published, leaving the live count alone."""
	_blank_row(row)
	_push_free(row)
	_free_count += 1


func destroy_gear(inventory: Inventory, definitions: ItemDefinitions,
		lot_ref: Vector2i) -> Inventory.OpResult:
	"""Destroy the gear record of a lot that has already retired. `.value` is 1 on success.

	Gear records die with their lot: while the lot is still live this refuses LOT_STILL_LIVE, so
	the call cannot be used to strip durability off a piece of gear somebody is still holding.
	A claimed record refuses too -- releasing a Job's claim is that Job's business.
	`definitions` is accepted for signature symmetry with the rest of the store and is not read.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if inventory.is_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if inventory.is_lot_valid(lot_ref):
		return _refuse(REFUSE_LOT_STILL_LIVE)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _equipped[row] == 1:
		return _refuse(REFUSE_GEAR_EQUIPPED)
	_free_row(row)
	return _ok(lot_ref, 1)


# --- Ownership --------------------------------------------------------------------------------

func set_owner(directory: EntityDirectory, lot_ref: Vector2i,
		owner_ref: Vector2i) -> Inventory.OpResult:
	"""Bind a gear instance to a live resident. Refused while the gear is claimed.

	§5.4's "worker owns net while trap/weir/boat owns installed gear" needs two owner kinds, and
	only the resident half is settled: the installed-owner discriminator belongs to the
	expedition/installed-gear contract (named next increment 2), so a non-resident reference is
	refused OWNER_KIND_UNSUPPORTED rather than guessed at. This changes no inventory container:
	the equipped-lot amendment is a separate increment.
	"""
	if directory == null:
		return _refuse(REFUSE_NO_DIRECTORY)
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _equipped[row] == 1:
		# The owner of an equipped record is what `inventory.gd` validates its null container
		# against. Re-pointing it here would strand that lot; `unequip()` is the way out.
		return _refuse(REFUSE_GEAR_EQUIPPED)
	if not directory.is_valid(owner_ref):
		return _refuse(REFUSE_INVALID_OWNER)
	if not directory.is_valid_of_kind(owner_ref, EntityDirectory.KIND_RESIDENT):
		return _refuse(REFUSE_OWNER_KIND_UNSUPPORTED)
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	return _ok(lot_ref, 1)


func clear_owner(lot_ref: Vector2i) -> Inventory.OpResult:
	"""Return a gear instance to unowned stock. Refused while claimed, and while equipped."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _equipped[row] == 1:
		return _refuse(REFUSE_GEAR_EQUIPPED)
	_owner_slot[row] = NULL_SLOT
	_owner_generation[row] = NULL_GENERATION
	return _ok(lot_ref, 1)


func owner_of(lot_ref: Vector2i) -> Vector2i:
	"""The recorded owner EntityRef, or NULL_REF when the gear is unowned or unknown.

	NULL_REF here is the GDD's own null reference, not a failure code: `has_gear()` distinguishes
	"no such gear" from "gear with no owner".
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return NULL_REF
	return Vector2i(_owner_slot[row], _owner_generation[row])


func has_live_owner(directory: EntityDirectory, lot_ref: Vector2i) -> bool:
	"""True when the gear's recorded owner reference still resolves in the directory.

	A stale owner handle -- a resident who has died and whose slot was reused -- fails here,
	because the recorded generation no longer matches the directory's.
	"""
	if directory == null:
		return false
	var recorded: Vector2i = owner_of(lot_ref)
	if recorded == NULL_REF:
		return false
	return directory.is_valid(recorded)


# --- Equipped gear (ruling §4; READY_07 §7.2 step 5; decision 0061) ---------------------------

func bind_equipment(inventory: Inventory, directory: EntityDirectory,
		residents: Residents) -> Inventory.OpResult:
	"""Wire the three stores an equip needs, and register this store as inventory's authority.

	Refused while any row is equipped: the bindings are what `is_equipped_record()` answers from,
	so swapping them under a live equipped record would change the answer to a proof
	`inventory.gd` has already accepted. `.value` is the equipped-row count.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if directory == null:
		return _refuse(REFUSE_NO_DIRECTORY)
	if residents == null:
		return _refuse(REFUSE_NO_RESIDENTS)
	if _equipped_count > 0:
		return _refuse(REFUSE_GEAR_EQUIPPED)
	var registered: Inventory.OpResult = inventory.set_equipment_authority(self)
	if not registered.ok:
		return registered
	_inventory = inventory
	_directory_binding = directory
	_residents = residents
	return _ok(NULL_REF, _equipped_count)


func is_equipment_bound() -> bool:
	"""True when all three equip collaborators are wired."""
	return _inventory != null and _directory_binding != null and _residents != null


func equipped_count() -> int:
	"""Number of live gear rows currently equipped by a resident."""
	return _equipped_count


func is_equipped_record(lot_ref: Vector2i) -> bool:
	"""THE PROOF `inventory.gd` demands before it will let a lot carry a null container.

	True only when all three hold at once: a live gear row records exactly this
	`(slot, generation)` lot reference; its `equipped` byte is set; and its recorded owner still
	resolves in the directory as a live resident. An owner who dies stops attesting immediately,
	which is how `inventory.audit()` finds the orphan rather than the orphan staying invisible.

	PURE READ, and it must stay one: `inventory.gd` refuses every mutator while this runs.
	"""
	if _directory_binding == null:
		return false
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW or _equipped[row] != 1:
		return false
	return _directory_binding.is_valid_of_kind(
		Vector2i(_owner_slot[row], _owner_generation[row]), EntityDirectory.KIND_RESIDENT)


func preflight_equip(lot_ref: Vector2i, owner_ref: Vector2i) -> Inventory.OpResult:
	"""Answer "could this tool be equipped?" without writing a byte. `.value` is its durability."""
	var code: StringName = _check_equip(lot_ref, owner_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _ok(lot_ref, _durability[_resolve_row(lot_ref)])


func equip(lot_ref: Vector2i, owner_ref: Vector2i) -> Inventory.OpResult:
	"""Put a stored tool onto a resident: the SAME lot, the SAME instance, the SAME durability.

	Nothing is cloned, merged or re-rolled. `.value` is the durability, which is identical before
	and after. Three stores change together -- the resident's Equipment mirror, this row's owner
	and `equipped` byte, and the lot's container -- and an equip that cannot finish leaves all
	three byte-identical, because the fallible steps run first and every write after one is an
	unconditional column assignment that the failure path reverses.
	"""
	var code: StringName = _check_equip(lot_ref, owner_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	var row: int = _resolve_row(lot_ref)
	var owner_row: int = _directory_binding.get_typed_row(owner_ref)
	var applied: StringName = _apply_equip(row, lot_ref, owner_ref, owner_row)
	if applied != REFUSE_NONE:
		return _refuse(applied)
	return _ok(lot_ref, _durability[row])


func _apply_equip(row: int, lot_ref: Vector2i, owner_ref: Vector2i, owner_row: int) -> StringName:
	"""Write the mirror, the ownership and the null container; undo all three on a refusal."""
	var mirrored: Residents.OpResult = _residents.set_equipped_tool(owner_row, _item_id[row],
		_durability[row])
	if not mirrored.ok:
		return mirrored.error
	var previous_slot: int = _owner_slot[row]
	var previous_generation: int = _owner_generation[row]
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	_equipped[row] = 1
	_equipped_count += 1
	var detached: Inventory.OpResult = _inventory.detach_lot_to_equipment(lot_ref)
	if detached.ok:
		return REFUSE_NONE
	_equipped[row] = 0
	_equipped_count -= 1
	_owner_slot[row] = previous_slot
	_owner_generation[row] = previous_generation
	_residents.clear_equipped_tool(owner_row)
	return detached.error


func _check_equip(lot_ref: Vector2i, owner_ref: Vector2i) -> StringName:
	"""Every precondition for equipping, checked before a single byte moves.

	Only the general `tool` is admitted; see named next increment 1 for why a net, a trap, an ice
	kit and a tier-2 outfit refuse instead of being given an invented Equipment mirror field.
	"""
	if not is_equipment_bound():
		return REFUSE_NOT_BOUND
	if _inventory.is_transaction_open():
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return REFUSE_NO_SUCH_GEAR
	if _equipped[row] == 1:
		return REFUSE_GEAR_EQUIPPED
	if _claim_job_slot[row] != NULL_SLOT:
		return REFUSE_GEAR_CLAIMED
	if _item_id[row] != _id_tool:
		return REFUSE_EQUIP_KIND_UNSUPPORTED
	var owner_code: StringName = _check_equip_owner(owner_ref)
	if owner_code != REFUSE_NONE:
		return owner_code
	var ready: Inventory.OpResult = _inventory.preflight_detach_to_equipment(lot_ref)
	return REFUSE_NONE if ready.ok else ready.error


func _check_equip_owner(owner_ref: Vector2i) -> StringName:
	"""The owner must be a live resident with a present row and no tool already equipped.

	§4.2 gives a resident exactly one `tool_item_id`, so a second tool refuses rather than
	displacing the first into a lot with no container and no mirror.
	"""
	if not _directory_binding.is_valid(owner_ref):
		return REFUSE_INVALID_OWNER
	if not _directory_binding.is_valid_of_kind(owner_ref, EntityDirectory.KIND_RESIDENT):
		return REFUSE_OWNER_KIND_UNSUPPORTED
	var owner_row: int = _directory_binding.get_typed_row(owner_ref)
	if not _residents.is_present(owner_row):
		return REFUSE_OWNER_NOT_RESIDENT_ROW
	if _residents.has_equipped_tool(owner_row):
		return REFUSE_OWNER_ALREADY_EQUIPPED
	return REFUSE_NONE


func preflight_unequip(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> Inventory.OpResult:
	"""Answer "could this tool be shelved here?" without writing a byte. `.value` is durability."""
	var code: StringName = _check_unequip(lot_ref, dest_ref, from_reserved_mass)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _ok(lot_ref, _durability[_resolve_row(lot_ref)])


func unequip(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> Inventory.OpResult:
	"""Return THE SAME lot to a valid destination container. Durability is not reset or rolled.

	`from_reserved_mass` spends grams the destination reserved for exactly this lot, which is
	what ruling §4's "valid reserved destination" buys. `.value` is the durability, unchanged.
	"""
	var code: StringName = _check_unequip(lot_ref, dest_ref, from_reserved_mass)
	if code != REFUSE_NONE:
		return _refuse(code)
	var row: int = _resolve_row(lot_ref)
	var applied: StringName = _apply_unequip(row, lot_ref, dest_ref, from_reserved_mass)
	if applied != REFUSE_NONE:
		return _refuse(applied)
	return _ok(lot_ref, _durability[row])


func _apply_unequip(row: int, lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> StringName:
	"""Drop the equipped relation, shelve the same lot, then empty the Equipment mirror.

	The relation is dropped FIRST because `inventory.gd` refuses to shelve a lot its authority
	still calls equipped -- which is the door that would otherwise admit a lot charging container
	mass while counting as equipment. A refused shelving puts the relation back exactly.
	"""
	var owner_ref: Vector2i = Vector2i(_owner_slot[row], _owner_generation[row])
	_equipped[row] = 0
	_equipped_count -= 1
	_owner_slot[row] = NULL_SLOT
	_owner_generation[row] = NULL_GENERATION
	var attached: Inventory.OpResult = _inventory.attach_equipped_lot(lot_ref, dest_ref,
		from_reserved_mass)
	if not attached.ok:
		_equipped[row] = 1
		_equipped_count += 1
		_owner_slot[row] = owner_ref.x
		_owner_generation[row] = owner_ref.y
		return attached.error
	_clear_owner_mirror(owner_ref)
	return REFUSE_NONE


func _check_unequip(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> StringName:
	"""Every precondition for unequipping, checked before a single byte moves."""
	if not is_equipment_bound():
		return REFUSE_NOT_BOUND
	if _inventory.is_transaction_open():
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return REFUSE_NO_SUCH_GEAR
	if _equipped[row] != 1:
		return REFUSE_GEAR_NOT_EQUIPPED
	if _claim_job_slot[row] != NULL_SLOT:
		return REFUSE_GEAR_CLAIMED
	var ready: Inventory.OpResult = _inventory.preflight_attach_equipped_lot(lot_ref, dest_ref,
		from_reserved_mass)
	return REFUSE_NONE if ready.ok else ready.error


func _clear_owner_mirror(owner_ref: Vector2i) -> void:
	"""Empty a former owner's Equipment tool fields, when that owner still has a row.

	A resident who died while equipped has no row left -- `despawn()` already cleared it -- so
	there is nothing to clear and nothing to refuse.
	"""
	var owner_row: int = _directory_binding.get_typed_row(owner_ref)
	if owner_row == EntityDirectory.NULL_SLOT or not _residents.is_present(owner_row):
		return
	_residents.clear_equipped_tool(owner_row)


func _set_durability(row: int, value: int) -> void:
	"""THE ONE place a live row's durability changes, so the Equipment mirror cannot fall behind.

	Fishing completion, general wear and repair all land here. When the row is equipped the
	owner's `Equipment.tool_durability` is rewritten in the same breath, which is why
	`residents.gd` calls itself a mirror and not a second authority. An owner whose reference has
	gone stale has no mirror row to write; `inventory.audit()` is what reports that orphan.
	"""
	_durability[row] = value
	if _equipped[row] != 1:
		return
	var owner_row: int = _directory_binding.get_typed_row(
		Vector2i(_owner_slot[row], _owner_generation[row]))
	if owner_row == EntityDirectory.NULL_SLOT:
		return
	_residents.set_equipped_tool_durability(owner_row, value)


# --- Starter tool seeding (GDD §5.9; READY_07 §7.2 step 5) ------------------------------------

func preflight_seed_starter_tools(definitions: ItemDefinitions,
		owner_refs: Array[Vector2i]) -> Inventory.OpResult:
	"""Answer "could the §5.9 starter tools exist?" without writing a byte. `.value` is 24.

	Checks this store's own concerns -- bindings, the twelve distinct unequipped resident owners,
	pool capacity for all 24 rows. Container capacity and lot capacity belong to `inventory.gd`
	and are refused there, which `seed_starter_tools()` undoes whole.
	"""
	if not is_equipment_bound():
		return _refuse(REFUSE_NOT_BOUND)
	if owner_refs.size() != STARTER_TOOL_EQUIPPED:
		return _refuse(REFUSE_INVALID_OWNER_COUNT)
	if definitions == null:
		return _refuse(REFUSE_NO_DEFINITIONS)
	var ready: Inventory.OpResult = preflight_create(definitions,
		definitions.compiled_id(KEY_TOOL), MANUFACTURE_BASIC)
	if not ready.ok:
		return ready
	if _free_count < STARTER_TOOL_TOTAL:
		return _refuse(REFUSE_CAPACITY_GEAR_INSTANCE)
	var owners: StringName = _check_seed_owners(owner_refs)
	if owners != REFUSE_NONE:
		return _refuse(owners)
	return _ok(NULL_REF, STARTER_TOOL_TOTAL)


func _check_seed_owners(owner_refs: Array[Vector2i]) -> StringName:
	"""Twelve DISTINCT live residents, each without a tool: §5.9's "one per resident"."""
	for index: int in range(owner_refs.size()):
		var owner: Vector2i = owner_refs[index]
		var code: StringName = _check_equip_owner(owner)
		if code != REFUSE_NONE:
			return code
		for other: int in range(index):
			if owner_refs[other] == owner:
				return REFUSE_DUPLICATE_OWNER
	return REFUSE_NONE


func seed_starter_tools(definitions: ItemDefinitions, container_ref: Vector2i,
		owner_refs: Array[Vector2i], quality: int, provenance: int) -> Inventory.OpResult:
	"""Create GDD §5.9's 24 starter tools: twelve equipped, twelve stored, durability 1000.

	`.value` is 24. NO `outfit_tier2` item is minted: §5.9 supplies tier-1 clothing as spawn
	equipment, which `needs.gd` already applies at spawn, and twelve invented outfit items would
	be the fabricated ItemDefinition ruling §4 forbids. `quality` and `provenance` are passed in
	because they are opaque compiled catalog enum values (§5.9's PLAIN and STARTER) that this
	store must not number for itself. A refusal at any point undoes every lot and gear row this
	call made, leaving both stores exactly as it found them.
	"""
	var ready: Inventory.OpResult = preflight_seed_starter_tools(definitions, owner_refs)
	if not ready.ok:
		return ready
	_seed_count = 0
	for index: int in range(STARTER_TOOL_TOTAL):
		var owner: Vector2i = owner_refs[index] if index < STARTER_TOOL_EQUIPPED else NULL_REF
		var code: StringName = _seed_one_tool(definitions, container_ref, owner, quality,
			provenance)
		if code == REFUSE_NONE:
			continue
		_rollback_seed(container_ref)
		return _refuse(code)
	return _ok(container_ref, STARTER_TOOL_TOTAL)


func _seed_one_tool(definitions: ItemDefinitions, container_ref: Vector2i, owner_ref: Vector2i,
		quality: int, provenance: int) -> StringName:
	"""Create one indivisible starter tool lot and its instance, equipping it when named."""
	var lot: Inventory.OpResult = _inventory.create_lot(container_ref,
		definitions.compiled_id(KEY_TOOL), GEAR_LOT_QUANTITY_MILLI, quality, provenance, 0, 0, 0)
	if not lot.ok:
		return lot.error
	var made: Inventory.OpResult = create_gear(_inventory, definitions, lot.ref,
		MANUFACTURE_BASIC)
	if not made.ok:
		_inventory.sink_lot_quantity(lot.ref, GEAR_LOT_QUANTITY_MILLI)
		return made.error
	_seed_lot_slot[_seed_count] = lot.ref.x
	_seed_lot_generation[_seed_count] = lot.ref.y
	_seed_count += 1
	if owner_ref == NULL_REF:
		return REFUSE_NONE
	var fitted: Inventory.OpResult = equip(lot.ref, owner_ref)
	return REFUSE_NONE if fitted.ok else fitted.error


func _rollback_seed(container_ref: Vector2i) -> void:
	"""Undo exactly the lots and gear rows this seeding call made, newest first.

	Newest first is what keeps it solvent: the stored tools come back first and free their grams,
	and each equipped tool needs only its own mass back -- the very mass its equip released --
	before it is sunk again. Nothing else can have taken that space inside one call.
	"""
	while _seed_count > 0:
		_seed_count -= 1
		var lot_ref: Vector2i = Vector2i(_seed_lot_slot[_seed_count],
			_seed_lot_generation[_seed_count])
		if is_equipped(lot_ref):
			unequip(lot_ref, container_ref, false)
		_inventory.sink_lot_quantity(lot_ref, GEAR_LOT_QUANTITY_MILLI)
		destroy_gear(_inventory, null, lot_ref)


# --- Equipment mirror audit -------------------------------------------------------------------

func audit_equipment_mirror() -> Inventory.OpResult:
	"""Re-derive every resident's Equipment tool fields from this store; refuse on divergence.

	DIAGNOSTIC, not a tick call: it allocates two 512-entry scratch columns. `.value` is the
	number of residents whose mirror matched. A mirror that can silently disagree with the
	authoritative GearInstance is the same defect class as counting one lot twice, so it is
	re-derived here rather than trusted.
	"""
	if not is_equipment_bound():
		return _refuse(REFUSE_NOT_BOUND)
	var expected_item: PackedInt32Array = PackedInt32Array()
	expected_item.resize(Residents.RESIDENT_CAPACITY)
	expected_item.fill(Residents.NO_TOOL_ITEM)
	var expected_durability: PackedInt32Array = PackedInt32Array()
	expected_durability.resize(Residents.RESIDENT_CAPACITY)
	var code: StringName = _collect_expected_mirror(expected_item, expected_durability)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _compare_mirror(expected_item, expected_durability)


func _collect_expected_mirror(items: PackedInt32Array,
		durabilities: PackedInt32Array) -> StringName:
	"""Fill the expected mirror from every equipped row; refuse a row whose owner is unusable."""
	for row: int in range(_row_capacity):
		if _occupied[row] == 0 or _equipped[row] != 1:
			continue
		var owner_row: int = _directory_binding.get_typed_row(
			Vector2i(_owner_slot[row], _owner_generation[row]))
		if owner_row == EntityDirectory.NULL_SLOT:
			return REFUSE_AUDIT_MIRROR
		if items[owner_row] != Residents.NO_TOOL_ITEM:
			return REFUSE_AUDIT_MIRROR
		items[owner_row] = _item_id[row]
		durabilities[owner_row] = _durability[row]
	return REFUSE_NONE


func _compare_mirror(items: PackedInt32Array,
		durabilities: PackedInt32Array) -> Inventory.OpResult:
	"""Compare the derived expectation against every resident row, present or not."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var matched: int = 0
	for slot: int in range(Residents.RESIDENT_CAPACITY):
		if items[slot] == Residents.NO_TOOL_ITEM:
			if _residents.has_equipped_tool(slot):
				return _refuse(REFUSE_AUDIT_MIRROR)
			continue
		if not _residents.equipped_tool_item_id_into(slot, out) or out.value != items[slot]:
			return _refuse(REFUSE_AUDIT_MIRROR)
		if not _residents.equipped_tool_durability_into(slot, out):
			return _refuse(REFUSE_AUDIT_MIRROR)
		if out.value != durabilities[slot]:
			return _refuse(REFUSE_AUDIT_MIRROR)
		matched += 1
	return _ok(NULL_REF, matched)


# --- Exclusive Job claims (decision 0017, REQ-SET-044) ----------------------------------------

func claim_for_job(lot_ref: Vector2i, job_ref: Vector2i) -> Inventory.OpResult:
	"""Reserve one gear object exclusively for one cycle/coordinator Job. `.value` is the wear
	the claim was checked against.

	REQ-SET-044 reserves gear durability at cycle start, and §5.4 fixes the bar: "A cycle cannot
	start with durability below wear". Exact wear starts; one below refuses INSUFFICIENT_DURABILITY.
	A second claimant is refused GEAR_ALREADY_CLAIMED whether or not it is the same Job, so a
	duplicate claim cannot silently succeed and then be released twice.
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	var code: StringName = _check_job_ref(job_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_ALREADY_CLAIMED)
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _required_start_durability_into(row, out):
		return _refuse(REFUSE_GEAR_NOT_CLAIMABLE)
	if _durability[row] < out.value:
		return _refuse(REFUSE_INSUFFICIENT_DURABILITY)
	_claim_job_slot[row] = job_ref.x
	_claim_job_generation[row] = job_ref.y
	return _ok(lot_ref, out.value)


func _required_start_durability_into(row: int, out: IntMath.IntResult) -> bool:
	"""Durability a cycle must already hold to start on this row; refuse for unclaimable gear.

	Fishing gear must hold its whole per-cycle wear (§5.4). A general tool must hold at least one
	point, because §5.7's "Broken tools block tool-required work" makes 0 the broken state and
	the work's actual wear is not known until it completes. A tier-2 outfit is not claimable at
	all: a claim reserves durability and an outfit has none.
	"""
	if _occupied[row] == 0:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	var model: int = _wear_model_of_row(row)
	if model == WEAR_MODEL_FISHING:
		return out.succeed(_cycle_wear_of_row(row))
	if model == WEAR_MODEL_GENERAL:
		return out.succeed(1)
	return out.refuse(String(REFUSE_GEAR_NOT_CLAIMABLE))


func _check_job_ref(job_ref: Vector2i) -> StringName:
	"""Check a Job reference is usable as a claim key.

	Job liveness belongs to the Job store, which this module deliberately does not depend on --
	the same boundary `reservations.gd` holds. What IS checked is that the slot is in range and
	that the reference is not the null reference, and every later operation compares the FULL
	`(slot, generation)` pair, so a stale handle whose slot has been reused fails.
	"""
	if job_ref.x < 0 or job_ref.x >= JOB_CAPACITY:
		return REFUSE_JOB_OUT_OF_RANGE
	if job_ref.y <= NULL_GENERATION:
		return REFUSE_INVALID_JOB
	return REFUSE_NONE


func cancel_claim(lot_ref: Vector2i, job_ref: Vector2i) -> Inventory.OpResult:
	"""Release a claim before completion, applying no wear. `.value` is 1 on success.

	A second cancellation finds no claim and refuses GEAR_NOT_CLAIMED, so a cancelled cycle
	cannot double-release and free gear a later cycle has already taken.
	"""
	var row: int = _resolve_claimed_row(lot_ref, job_ref)
	if row == NULL_ROW:
		return _refuse(_claim_refusal(lot_ref, job_ref))
	_release_claim(row)
	return _ok(lot_ref, 1)


func complete_cycle(lot_ref: Vector2i, job_ref: Vector2i) -> Inventory.OpResult:
	"""Apply one fishing cycle's wear exactly once and release the claim. `.value` is the wear.

	REQ-SET-045's "apply wear" for §5.4 gear. The wear is re-derived from the row rather than
	taken as an argument, which is what freezes the cycle's contract: the row's item cannot
	change, and nothing may repair or re-own the gear while the claim stands, so completion
	debits exactly the number the claim was checked against. A repeated completion finds no claim
	and refuses GEAR_NOT_CLAIMED rather than debiting twice.
	"""
	var row: int = _resolve_claimed_row(lot_ref, job_ref)
	if row == NULL_ROW:
		return _refuse(_claim_refusal(lot_ref, job_ref))
	if _wear_model_of_row(row) != WEAR_MODEL_FISHING:
		return _refuse(REFUSE_WRONG_WEAR_MODEL)
	var wear: int = _cycle_wear_of_row(row)
	if _durability[row] < wear:
		return _refuse(REFUSE_INSUFFICIENT_DURABILITY)
	_set_durability(row, _durability[row] - wear)
	_release_claim(row)
	return _ok(lot_ref, wear)


func apply_general_wear_into(lot_ref: Vector2i, job_ref: Vector2i, completed_mwu: int,
		remainder_before: int, out: WearOutcome) -> bool:
	"""Apply §5.7 generic wear once and release the claim; write the outcome into `out`.

	"1 equipped tool durability per completed 10 WU; preserve remainder across tasks". The
	remainder lives in `ResidentRuntime.wear_remainder`, already budgeted at length 512, so it is
	passed in and handed back rather than duplicated in a column this store has no budget for.
	`completed_mwu` is milli-WU of finished work. A repeated call finds no claim and refuses.
	"""
	var row: int = _resolve_claimed_row(lot_ref, job_ref)
	if row == NULL_ROW:
		return out.refuse(_claim_refusal(lot_ref, job_ref))
	if _wear_model_of_row(row) != WEAR_MODEL_GENERAL:
		return out.refuse(REFUSE_WRONG_WEAR_MODEL)
	if completed_mwu < 0:
		return out.refuse(REFUSE_INVALID_WORK)
	if remainder_before < 0 or remainder_before >= GENERAL_WEAR_MWU_PER_POINT:
		return out.refuse(REFUSE_INVALID_REMAINDER)
	return _debit_general_wear(row, completed_mwu, remainder_before, out)


func _debit_general_wear(row: int, completed_mwu: int, remainder_before: int,
		out: WearOutcome) -> bool:
	"""Debit the whole points `completed_mwu` earned, floor at 0, and release the claim.

	Demanding more points than remain debits the tool to exactly 0 and reports `broke`: §5.7
	fixes the rate and says broken tools block tool-required work, and refusing would leave
	finished work having cost nothing. The remainder still carries forward.
	"""
	var math: IntMath.IntResult = IntMath.IntResult.new()
	if not IntMath.checked_add_into(remainder_before, completed_mwu, math):
		return out.refuse(REFUSE_INVALID_WORK)
	var total: int = math.value
	var demanded: int = total / GENERAL_WEAR_MWU_PER_POINT
	var remainder_after: int = total % GENERAL_WEAR_MWU_PER_POINT
	var spent: int = mini(demanded, _durability[row])
	_set_durability(row, _durability[row] - spent)
	var after: int = _durability[row]
	_release_claim(row)
	return out.succeed(spent, after, remainder_after, demanded > spent)


func _resolve_claimed_row(lot_ref: Vector2i, job_ref: Vector2i) -> int:
	"""The row this lot names, but only when `job_ref` is exactly the Job holding its claim."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return NULL_ROW
	if _claim_job_slot[row] != job_ref.x or _claim_job_generation[row] != job_ref.y:
		return NULL_ROW
	if _claim_job_slot[row] == NULL_SLOT:
		return NULL_ROW
	return row


func _claim_refusal(lot_ref: Vector2i, job_ref: Vector2i) -> StringName:
	"""The explicit reason `_resolve_claimed_row()` found nothing: no gear, no claim, wrong Job."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return REFUSE_NO_SUCH_GEAR
	if _claim_job_slot[row] == NULL_SLOT:
		return REFUSE_GEAR_NOT_CLAIMED
	return REFUSE_GEAR_CLAIM_MISMATCH


func _release_claim(row: int) -> void:
	"""Clear a row's exclusive claim. The only place either claim column returns to null."""
	_claim_job_slot[row] = NULL_SLOT
	_claim_job_generation[row] = NULL_GENERATION


# --- Repair -----------------------------------------------------------------------------------

func repair(lot_ref: Vector2i, restored_points: int) -> Inventory.OpResult:
	"""Restore durability up to -- and clamped at -- this gear's own cap. `.value` is the result.

	§5.7 restores 200 general-tool points per 30 WU and §5.4 restores 200 fishing points per
	30 WU, from two DIFFERENT material recipes; see the `repair_*_into()` readers. The clamp to
	the cap is the one clamp ruling §4 states, and repair is emphatically not a reset: a tool at
	40 repaired by 200 ends at 240, not at 1000. Refused while the gear is claimed, and refused
	as inapplicable for a tier-2 outfit, whose cap is 0.
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _wear_model_of_row(row) == WEAR_MODEL_NONE:
		return _refuse(REFUSE_REPAIR_INAPPLICABLE)
	if restored_points <= 0:
		return _refuse(REFUSE_INVALID_REPAIR_POINTS)
	_set_durability(row, mini(_durability_cap[row], _durability[row] + restored_points))
	return _ok(lot_ref, _durability[row])


func repair_wood_milli_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write this gear's repair wood cost in milli-units into `out`. Both recipes use wood 1."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	var model: int = _wear_model_of_row(row)
	if model == WEAR_MODEL_NONE:
		return out.refuse(String(REFUSE_REPAIR_INAPPLICABLE))
	if model == WEAR_MODEL_FISHING:
		return out.succeed(REPAIR_FISHING_WOOD_MILLI)
	return out.succeed(REPAIR_GENERAL_WOOD_MILLI)


func repair_secondary_item_into(definitions: ItemDefinitions, lot_ref: Vector2i,
		out: IntMath.IntResult) -> bool:
	"""Write the compiled item id of this gear's second repair material into `out`.

	The two recipes genuinely differ and must not be merged: a general tool takes STONE (§5.7),
	fishing gear takes ROPE (§5.4).
	"""
	if definitions == null or not definitions.is_loaded():
		return out.refuse(String(REFUSE_DEFINITIONS_NOT_LOADED))
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	var model: int = _wear_model_of_row(row)
	if model == WEAR_MODEL_NONE:
		return out.refuse(String(REFUSE_REPAIR_INAPPLICABLE))
	if model == WEAR_MODEL_FISHING:
		return out.succeed(definitions.compiled_id(REPAIR_FISHING_SECONDARY_KEY))
	return out.succeed(definitions.compiled_id(REPAIR_GENERAL_SECONDARY_KEY))


func repair_secondary_milli_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write this gear's second repair material quantity in milli-units into `out`.

	General tools take stone 0.5; fishing gear takes rope 0.25. Different numbers, kept apart.
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	var model: int = _wear_model_of_row(row)
	if model == WEAR_MODEL_NONE:
		return out.refuse(String(REFUSE_REPAIR_INAPPLICABLE))
	if model == WEAR_MODEL_FISHING:
		return out.succeed(REPAIR_FISHING_SECONDARY_MILLI)
	return out.succeed(REPAIR_GENERAL_SECONDARY_MILLI)


# --- Row readers, all keyed on the lot reference ----------------------------------------------

func has_gear(lot_ref: Vector2i) -> bool:
	"""True when a live gear instance carries exactly this lot reference."""
	return _resolve_row(lot_ref) != NULL_ROW


func durability_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write current durability into `out`; refuse when there is no such gear.

	`_into` form because 0 is a legal stored durability -- a broken tool -- so no returned integer
	could tell "broken" from "no such gear" without becoming a sentinel.
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	return out.succeed(_durability[row])


func durability_cap_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write the durability cap into `out`; refuse when there is no such gear. 0 for an outfit."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	return out.succeed(_durability_cap[row])


func item_id_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write the compiled catalog item id into `out`; refuse when there is no such gear."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	return out.succeed(_item_id[row])


func manufacture_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write the manufacture method into `out`; refuse when there is no such gear.

	MANUFACTURE_BASIC is 0, so this is an `_into` reader rather than a returned integer.
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	return out.succeed(_manufacture_recipe[row])


func wear_model_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write the wear model of a live gear row into `out`; refuse when there is no such gear."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	return out.succeed(_wear_model_of_row(row))


func cycle_wear_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write the §5.4 per-cycle wear into `out`; refuse for any non-fishing gear."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return out.refuse(String(REFUSE_NO_SUCH_GEAR))
	if _wear_model_of_row(row) != WEAR_MODEL_FISHING:
		return out.refuse(String(REFUSE_WRONG_WEAR_MODEL))
	return out.succeed(_cycle_wear_of_row(row))


func is_claimed(lot_ref: Vector2i) -> bool:
	"""True when a Job currently holds this gear exclusively."""
	var row: int = _resolve_row(lot_ref)
	return row != NULL_ROW and _claim_job_slot[row] != NULL_SLOT


func claim_job_of(lot_ref: Vector2i) -> Vector2i:
	"""The Job holding this gear, or NULL_REF when it is unclaimed or unknown.

	NULL_REF is the GDD's null reference, not a refusal: pair it with `has_gear()` when the
	distinction between "no gear" and "unclaimed gear" matters.
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return NULL_REF
	return Vector2i(_claim_job_slot[row], _claim_job_generation[row])


func is_equipped(lot_ref: Vector2i) -> bool:
	"""The ledger's `equipped` byte: true while a resident is wearing or carrying this gear.

	This is the raw byte. `is_equipped_record()` is the stronger question `inventory.gd` asks,
	because it also requires the recorded owner to still be alive.
	"""
	var row: int = _resolve_row(lot_ref)
	return row != NULL_ROW and _equipped[row] == 1


func _wear_model_of_row(row: int) -> int:
	"""Wear model of a live row, keyed on its stored compiled item id.

	Read from the bound catalog ids rather than inferred from the stored cap, so an authored cap
	change can never silently move a piece of gear from one wear model to the other. An unbound or
	unrecognised id yields WEAR_MODEL_NONE, which makes the row unclaimable and unrepairable
	rather than quietly wearable under the wrong rule.
	"""
	var compiled_item_id: int = _item_id[row]
	if compiled_item_id < 0:
		return WEAR_MODEL_NONE
	if compiled_item_id == _id_tool:
		return WEAR_MODEL_GENERAL
	if compiled_item_id == _id_net or compiled_item_id == _id_trap:
		return WEAR_MODEL_FISHING
	if compiled_item_id == _id_ice_kit:
		return WEAR_MODEL_FISHING
	return WEAR_MODEL_NONE


func _cycle_wear_of_row(row: int) -> int:
	"""The row's GDD §5.4 per-cycle wear, or 0 when it is not fishing gear.

	Net 20, trap 10, ice kit 20, straight off the gear table. Weir 5 and boat 15 are installed
	gear with no row here at all.
	"""
	var compiled_item_id: int = _item_id[row]
	if compiled_item_id < 0:
		return 0
	if compiled_item_id == _id_net:
		return WEAR_PER_CYCLE_NET
	if compiled_item_id == _id_trap:
		return WEAR_PER_CYCLE_TRAP
	if compiled_item_id == _id_ice_kit:
		return WEAR_PER_CYCLE_ICE_KIT
	return 0


# --- Row resolution ---------------------------------------------------------------------------

func _resolve_row(lot_ref: Vector2i) -> int:
	"""The live row whose RECORDED identity is exactly `lot_ref`, or NULL_ROW.

	Both halves of the reference are compared, so a stale lot handle -- right slot, superseded
	generation -- resolves to nothing and every operation keyed on it refuses. Bounded ascending
	scan: see the header on why no reverse index is allocated here.
	"""
	if lot_ref.x < 0 or lot_ref.x >= LOT_CAPACITY or lot_ref.y <= NULL_GENERATION:
		return NULL_ROW
	var seen: int = 0
	for row: int in range(_row_capacity):
		if _occupied[row] == 0:
			continue
		seen += 1
		if _lot_slot[row] == lot_ref.x and _lot_generation[row] == lot_ref.y:
			return row
		if seen >= _active_count:
			return NULL_ROW
	return NULL_ROW


func _resolve_row_by_lot_slot(lot_slot: int) -> int:
	"""The live row recorded against `lot_slot` at ANY generation, or NULL_ROW.

	Used only to keep one lot slot from carrying two gear records; every public path compares
	the full reference.
	"""
	if lot_slot < 0 or lot_slot >= LOT_CAPACITY:
		return NULL_ROW
	var seen: int = 0
	for row: int in range(_row_capacity):
		if _occupied[row] == 0:
			continue
		seen += 1
		if _lot_slot[row] == lot_slot:
			return row
		if seen >= _active_count:
			return NULL_ROW
	return NULL_ROW


func recorded_lot_ref_at_lot_slot(lot_slot: int) -> Vector2i:
	"""The full lot reference a gear row records against `lot_slot`, or NULL_REF when none does.

	The way to recover a stale record's reference so `destroy_gear()` can clean it up, without
	ever exposing the gear row index itself.
	"""
	var row: int = _resolve_row_by_lot_slot(lot_slot)
	if row == NULL_ROW:
		return NULL_REF
	return Vector2i(_lot_slot[row], _lot_generation[row])


# --- Row allocation ---------------------------------------------------------------------------

func _allocate_row() -> int:
	"""Take the LOWEST free row index. Callers preflight capacity, so this cannot be called empty.

	Occupancy is NOT set here: `_write_new_row()` fills every field first and `_publish_row()`
	sets occupancy last, so no partially initialised row is ever visible.
	"""
	assert(_free_count > 0, "the preflight guarantees a free row here")
	var row: int = _pop_min()
	_free_count -= 1
	return row


func _free_row(row: int) -> void:
	"""Blank a live row completely, then return it to the free heap. Blank first, always."""
	_blank_row(row)
	_occupied[row] = 0
	_active_count -= 1
	_push_free(row)
	_free_count += 1


func _blank_row(row: int) -> void:
	"""Reset every payload and claim column of one row to its empty value."""
	_lot_slot[row] = NULL_SLOT
	_lot_generation[row] = NULL_GENERATION
	_item_id[row] = -1
	_durability[row] = 0
	_durability_cap[row] = 0
	_owner_slot[row] = NULL_SLOT
	_owner_generation[row] = NULL_GENERATION
	_manufacture_recipe[row] = MANUFACTURE_BASIC
	_equipped[row] = 0
	_claim_job_slot[row] = NULL_SLOT
	_claim_job_generation[row] = NULL_GENERATION


func _pop_min() -> int:
	"""Remove and return the smallest entry of the free-row min-heap.

	Sift-down in the shape `reservations.gd` and `entity_directory.gd` already use; this store
	owns a single window so it needs no base offset.
	"""
	var smallest: int = _free_heap[0]
	var last: int = _free_count - 1
	if last == 0:
		return smallest
	_free_heap[0] = _free_heap[last]
	var index: int = 0
	while index * 2 + 1 < last:
		var child: int = index * 2 + 1
		if child + 1 < last and _free_heap[child + 1] < _free_heap[child]:
			child += 1
		if _free_heap[index] <= _free_heap[child]:
			break
		var carried: int = _free_heap[index]
		_free_heap[index] = _free_heap[child]
		_free_heap[child] = carried
		index = child
	return smallest


func _push_free(row: int) -> void:
	"""Insert a freed row into the min-heap so the next allocation still finds the lowest index."""
	var index: int = _free_count
	while index > 0:
		var parent: int = (index - 1) / 2
		if _free_heap[parent] <= row:
			break
		_free_heap[index] = _free_heap[parent]
		index = parent
	_free_heap[index] = row


# --- Catalog ids bound for row-local reads ----------------------------------------------------

func capture_item_ids(definitions: ItemDefinitions) -> Inventory.OpResult:
	"""Re-read the five instance-required compiled ids from the loaded catalog.

	`.value` is the number of the five keys the catalog actually defines, which is 5 for the
	shipping catalog. `create_gear()` and `begin_restore()` call this themselves, so an ordinary
	caller never has to; it is public so a load path can bind the ids before restoring a row.
	"""
	if definitions == null:
		return _refuse(REFUSE_NO_DEFINITIONS)
	if not definitions.is_loaded():
		return _refuse(REFUSE_DEFINITIONS_NOT_LOADED)
	_id_tool = definitions.compiled_id(KEY_TOOL)
	_id_net = definitions.compiled_id(KEY_NET)
	_id_trap = definitions.compiled_id(KEY_TRAP)
	_id_ice_kit = definitions.compiled_id(KEY_ICE_KIT)
	_id_outfit_tier2 = definitions.compiled_id(KEY_OUTFIT_TIER2)
	return _ok(NULL_REF, _bound_id_count())


func _bound_id_count() -> int:
	"""How many of the five instance-required keys currently resolve to a compiled id."""
	var bound: int = 0
	for compiled_id: int in [_id_tool, _id_net, _id_trap, _id_ice_kit, _id_outfit_tier2]:
		if compiled_id >= 0:
			bound += 1
	return bound


# --- Restore path for a save format that does not exist yet -----------------------------------

func begin_restore(definitions: ItemDefinitions) -> Inventory.OpResult:
	"""Empty the store and open the restore window. `.value` is the row capacity.

	While the window is open the free heap is not derived and no gear may be created or claimed;
	`finish_restore()` closes it and rebuilds the heap ascending.
	"""
	var captured: Inventory.OpResult = capture_item_ids(definitions)
	if not captured.ok:
		return captured
	clear()
	_restoring = true
	return _ok(NULL_REF, _row_capacity)


func restore_row(row: int, lot_ref: Vector2i, compiled_item_id: int, durability: int,
		durability_cap: int, owner_ref: Vector2i, manufacture: int,
		claim_job_ref: Vector2i) -> Inventory.OpResult:
	"""Write one saved gear row back at its saved index. `.value` is the restored durability.

	Occupancy and the authoritative fields are what a save carries; the heap is derived and is
	rebuilt by `finish_restore()`. Row indices are meaningful ONLY inside this window, which is
	why this is the one entry point that names one.
	"""
	var code: StringName = _check_restore(row, lot_ref, durability, durability_cap, manufacture)
	if code != REFUSE_NONE:
		return _refuse(code)
	_write_new_row(row, lot_ref, compiled_item_id, durability_cap, manufacture)
	_durability[row] = durability
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	_claim_job_slot[row] = claim_job_ref.x
	_claim_job_generation[row] = claim_job_ref.y
	if not _publish_row(row):
		_blank_row(row)
		return _refuse(REFUSE_ROW_NOT_INITIALISED)
	return _ok(lot_ref, durability)


func _check_restore(row: int, lot_ref: Vector2i, durability: int, durability_cap: int,
		manufacture: int) -> StringName:
	"""Validate one restore_row() call. A save that fails this is a load failure, not a repair."""
	if not _restoring:
		return REFUSE_RESTORE_NOT_OPEN
	if row < 0 or row >= _row_capacity:
		return REFUSE_ROW_OUT_OF_RANGE
	if _occupied[row] == 1:
		return REFUSE_ROW_OCCUPIED
	if lot_ref.x < 0 or lot_ref.x >= LOT_CAPACITY or lot_ref.y <= NULL_GENERATION:
		return REFUSE_LOT_OUT_OF_RANGE
	if _resolve_row_by_lot_slot(lot_ref.x) != NULL_ROW:
		return REFUSE_GEAR_ALREADY_EXISTS
	if durability_cap < 0 or durability < 0 or durability > durability_cap:
		return REFUSE_INVALID_DURABILITY
	if manufacture != MANUFACTURE_BASIC and manufacture != MANUFACTURE_IRON:
		return REFUSE_INVALID_MANUFACTURE
	return REFUSE_NONE


func finish_restore() -> Inventory.OpResult:
	"""Close the restore window and rebuild the free heap ASCENDING. `.value` is the free count.

	Rebuilding ascending is what makes a loaded world allocate the same rows in the same order as
	the world that saved it, which a saved heap image could not guarantee.
	"""
	if not _restoring:
		return _refuse(REFUSE_RESTORE_NOT_OPEN)
	_refill_heap_ascending()
	_restoring = false
	return _ok(NULL_REF, _free_count)


func is_restoring() -> bool:
	"""True while a restore window is open and the free heap is not yet derived."""
	return _restoring


# --- Audit ------------------------------------------------------------------------------------

func audit() -> Inventory.OpResult:
	"""Re-derive every structural invariant this store claims to hold. `.value` is the live count.

	Diagnostic, not a tick call: it allocates one occupancy scratch buffer. Checks occupancy
	against the free heap and the live count, the durability range against each row's own cap,
	one gear record per lot slot, and the two claim columns for a matched null/non-null pair.
	"""
	var code: StringName = _audit_occupancy()
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _audit_rows()
	if code != REFUSE_NONE:
		return _refuse(code)
	return _ok(NULL_REF, _active_count)


func _audit_occupancy() -> StringName:
	"""Occupancy, live count and free heap must all describe the same set of rows."""
	var occupied: int = 0
	var equipped: int = 0
	for row: int in range(_row_capacity):
		if _occupied[row] == 1:
			occupied += 1
			equipped += _equipped[row]
	if occupied != _active_count or occupied + _free_count != _row_capacity:
		return REFUSE_AUDIT_OCCUPANCY
	if equipped != _equipped_count:
		return REFUSE_AUDIT_OCCUPANCY
	for index: int in range(_free_count):
		var row: int = _free_heap[index]
		if row < 0 or row >= _row_capacity or _occupied[row] == 1:
			return REFUSE_AUDIT_HEAP
	return REFUSE_NONE


func _audit_rows() -> StringName:
	"""Every live row: unique lot slot, durability inside its cap, well-formed claim columns."""
	var seen_lot: PackedByteArray = PackedByteArray()
	seen_lot.resize(LOT_CAPACITY)
	seen_lot.fill(0)
	for row: int in range(_row_capacity):
		if _occupied[row] == 0:
			continue
		var lot_slot: int = _lot_slot[row]
		if lot_slot < 0 or lot_slot >= LOT_CAPACITY or seen_lot[lot_slot] == 1:
			return REFUSE_AUDIT_DUPLICATE_LOT
		seen_lot[lot_slot] = 1
		if _durability[row] < 0 or _durability[row] > _durability_cap[row]:
			return REFUSE_AUDIT_DURABILITY
		var claim_null: bool = _claim_job_slot[row] == NULL_SLOT
		var generation_null: bool = _claim_job_generation[row] == NULL_GENERATION
		if claim_null != generation_null:
			return REFUSE_AUDIT_CLAIM
	return REFUSE_NONE


# --- Serialization ----------------------------------------------------------------------------

func state_bytes() -> PackedByteArray:
	"""Canonical image of every live gear record, comparable across two identical worlds.

	NOT A PRODUCTION CALL: it allocates. Deliberately EXCLUDES the row index and the free heap,
	because those depend on allocation history -- two worlds holding the same gear must produce
	the same image whichever rows they happen to occupy. Records are emitted in ascending lot
	slot, which is unique per record.

	The save FORMAT does not exist yet: nothing in the architecture defines this store's header,
	chunk layout or version field. This is the deterministic serialization half of that work;
	reading an image back is DEFERRED until the format is specified.
	"""
	var keys: PackedInt64Array = PackedInt64Array()
	keys.resize(_active_count)
	var cursor: int = 0
	for row: int in range(_row_capacity):
		if _occupied[row] == 0:
			continue
		keys[cursor] = _lot_slot[row] * ROW_CAPACITY + row
		cursor += 1
	keys.sort()
	return var_to_bytes(_image_of_sorted(keys))


func _image_of_sorted(keys: PackedInt64Array) -> PackedInt64Array:
	"""Build the canonical field image from lot-slot-sorted `(lot_slot, row)` composite keys."""
	var image: PackedInt64Array = PackedInt64Array()
	image.resize(1 + keys.size() * 9)
	image[0] = _active_count
	var cursor: int = 1
	for key: int in keys:
		var row: int = key % ROW_CAPACITY
		image[cursor] = _lot_slot[row]
		image[cursor + 1] = _lot_generation[row]
		image[cursor + 2] = _item_id[row]
		image[cursor + 3] = _durability[row]
		image[cursor + 4] = _durability_cap[row]
		image[cursor + 5] = _owner_slot[row]
		image[cursor + 6] = _owner_generation[row]
		image[cursor + 7] = _manufacture_recipe[row]
		image[cursor + 8] = _equipped[row]
		cursor += 9
	return image


# --- Results ----------------------------------------------------------------------------------

func _ok(ref: Vector2i, value: int) -> Inventory.OpResult:
	"""Build a successful result, sharing `inventory.gd`'s result shape rather than cloning it."""
	return Inventory.OpResult.new(true, REFUSE_NONE, ref, value)


func _refuse(code: StringName) -> Inventory.OpResult:
	"""Build an explicit refusal carrying no partially applied effect and no usable ref."""
	return Inventory.OpResult.new(false, code, NULL_REF, 0)
