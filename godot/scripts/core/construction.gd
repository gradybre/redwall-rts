extends RefCounted
## The packed Construction store: GDD §4.2's project row and REQ-SET-124-128/137's lifecycle.
##
## GDD §4.2 states the row exactly:
##   Construction | material_container: EntityRef, remaining_mwu: int64, assigned_count: int32,
##                  max_workers: int32, paused: bool, refund_policy: enum
##                | "At most 1 project/building/furniture/road segment"
## `systems_architecture.md` §2.2 repeats it at length 82944, and `entity_directory.gd` reserves
## KIND_CONSTRUCTION at exactly that count (1024 exterior structures + 81920 furniture, ARCH-MEM-002).
## `_init()` asserts the agreement rather than trusting it.
##
## THIS IS NOT A SECOND BUILDING STORE. `buildings.gd` (decision 0088) owns the Building, Room and
## Furniture rows, the presence mask, the unlock gate and the tile maps. This module owns the
## PROJECT behind a `Building.construction` reference and nothing else: what a project costs, what
## has been delivered to it, whether its materials have been consumed, how much work is left, and
## what a cancellation or a demolition hands back. It borrows `buildings.gd` rather than
## duplicating a column of it, and every reference it stores is validated through the one shared
## `entity_directory.gd`.
##
## THE FIVE ECONOMIC RULES, AND WHERE EACH ONE LIVES:
##   * REQ-SET-124 -- DELIVERY BEFORE WORK. `open_build()` publishes a project whose delivered
##     ledger is all zeros and deducts nothing from any physical store. Delivery is recorded by
##     `deliver_material()`, which the hauling owner calls AFTER it has physically moved goods
##     into the project's `material_container`. This store never reaches into `inventory.gd`.
##   * REQ-SET-125 -- CONSUMPTION WHEN WORK BEGINS. `begin_work()` is the single transition that
##     turns a fully delivered project into a working one, and it is the point at which the
##     delivered materials become project WIP. `add_work_mwu()` REFUSES in every phase but
##     PHASE_WORKING, so no milli-WU can be earned against undelivered materials.
##   * REQ-SET-126 -- 100% BEFORE WORK, 80% AFTER, floored to milli-U.
##     `cancellation_refund_milli_into()` is the only place the fraction is applied.
##   * REQ-SET-127 -- DEMOLITION. `open_demolition()` prices the work at the declared construction
##     WU x 0.25 and `demolition_return_milli_into()` hands back 50% of the ORIGINAL material
##     costs -- the definition's own bill, never the delivered ledger, which is empty for a
##     demolition. Every piece of furniture in the building adds 50% of its own §4.3 bill, floored
##     per piece, and a quarter of its WU (Brendan's rulings on decision 0535, recorded in 0536);
##     `open_furniture_removal()` takes ONE piece out of a standing building on the same terms.
##   * REQ-SET-137 -- PAUSE. `set_paused()` retains the delivered ledger and `remaining_mwu`
##     untouched and drops `assigned_count` to 0, which is "release workers" in this store's terms.
##
## TWO REFUND PATHS, DELIBERATELY NOT SHARED. ARCH-JOB-004 says in terms that construction's
## "100%/80% cancellation and 50% demolition rules ... must not share an undifferentiated 'refund
## all' helper". They do not: `cancellation_refund_milli_into()` REFUSES a demolition project and
## `demolition_return_milli_into()` REFUSES everything else. The two read different bases -- one
## the per-project delivered ledger, the other the immutable §4.1 bill -- and neither can be
## reached through the other.
##
## ALLOCATE BEFORE CONSUME (decision 0059). Every mutator validates completely before it writes a
## byte, and allocates its directory row only once no refusal is possible. A refused placement,
## delivery, work point or cancellation leaves this store, `buildings.gd` and the shared directory
## BYTE-IDENTICAL; `state_bytes()` exists so that is asserted rather than eyeballed. The worst
## failure this store can have is a half-committed project that consumed materials and produced
## nothing, so the consumption point is one function with one precondition.
##
## CANCELLATION IS TWO-PHASE, AND ON PURPOSE. `begin_refund()` freezes the project in
## PHASE_REFUNDING -- no further delivery, no further work -- and frees nothing.
## `cancellation_refund_milli_into()` then reads a manifest that cannot move under the caller,
## and `close_refund()` retires the row once the caller has physically placed those lots. If the
## placement fails the caller simply does not call `close_refund()`, the project stays exactly
## where it is, and the retry spends nothing: this is SET-MOVE-ECON-001 ECON-003's "explicit
## work-ready/commit-pending condition and an idempotent settlement retry", applied to the
## cancellation path as well as the completion path, because both can fail at an output.
##
## PHASES ARE PROJECT PHASES, NOT SITE PHASES. SET-MOVE-ECON-001 ECON-003 requires nine
## EXCAVATION phases -- SOLID, BRACING, BRACED, CUTTING, OPEN_UNFINISHED, FINISHING,
## SUPPORTED_VOID, CLOSING, BACKFILLED -- and says they are "a separate typed project/physical-site
## domain". They are a property of a piece of ground, not of a project, and each of them is
## reached by running one project through THIS lifecycle: an excavation site in SOLID with a
## funded BRACING project moves to BRACED when that project's own PHASE_WORK_DONE commits.
## ECON-003's "consume material inputs once at WORK start, into project WIP" is
## `begin_work()` verbatim, and its "retain earned work/WIP and phase but do not publish any part
## of the batch" on an output failure is PHASE_WORK_DONE. The site column, its phase domain and
## its compiled ASCII ids belong to the excavation owner and to `catalog.gd`, neither of which is
## this module; nothing here is renamed or widened to pre-empt them.
##
## WHAT THIS STORE DOES NOT DECIDE -- named, not invented:
##   * REQ-SET-128's STRANDED-GOODS HALF IS STILL NOT ENFORCED HERE, AND CANNOT BE. The resident
##     half is: `open_demolition()` refuses a building whose rooms report occupants or whose
##     furniture has a live user, and it reports the exact count. The goods half needs Inventory,
##     and this store holds no reference to it -- by design, since a store that reached into
##     Inventory would be the cross-store commit ARCH-JOB-004 keeps out of here. `inventory.gd`
##     now publishes `containers_by_owner_into()` (INV-GOODS-R01), but a container owner scan
##     alone does not prove physical containment, so the composed gate lives where all three
##     stores meet: `settlement_system.gd::request_demolition()`. Refusing on a caller-supplied
##     "goods are clear" boolean would be exactly the unbounded attestation MOVE-DEP-R05 rejects,
##     and that is still not done.
##
##     SO `open_demolition()` IS A STORE-LEVEL TRANSITION, NOT THE PLAYER-FACING GATE. It is
##     correct for what it checks and blind to what it does not check, and a caller that wants
##     REQ-SET-128 in full must go through the coordinator. `occupant_count_of_building()` and
##     `furniture_user_count_of_building()` are public so that coordinator rechecks THESE counts
##     immediately before any state change, rather than keeping a second copy of the rule.
##     A demolition or furniture removal COMPLETES AND IS CANCELLED ONLY THROUGH THE COORDINATOR
##     (decision 0536, Brendan's P3): `commit_completion()` and `close_refund()` refuse such a row
##     COORDINATOR_ONLY, because finishing it here would skip its Inventory claim and orphan its
##     stores. The coordinator calls `remove_demolished_subject()`, places the 50% return, then
##     `retire_demolition()`; a cancellation ends in `close_demolition_refund()`.
##   * A TIER-2 BUILDING'S DEMOLITION BASIS IS BUILD-C4-R01's (decision 0534). Every row records
##     its paid package KEYS in the ConstructionPaidLedger columns `_paid_base_type` and
##     `_paid_upgrade_mask`; `open_demolition()` snapshots the building's base package and, at
##     tier 2, its one completed upgrade. The return totals each item over both packages and
##     floors the 50% once per item; the work is a quarter of the same completed WU sum. Tier 1
##     is the inherited formula unchanged. A piece of furniture's package is DERIVED from its type
##     (0536, ruling R4's reading applied to furniture): no store records a completed piece's.
##     ADR 0186's frozen local Columns validation still declares a DEMOLISH row's W as the BASE
##     WU x 0.25 and pins purposes 0..3, so a tier-2 or furnished demolition's W and every
##     furniture-removal row fail it closed; CONSTRUCTION-SAVED-BINDINGS must revisit that
##     contract before any open removal is saved (decision 0536).
##   * NO CONTAINER IS CREATED OR READ. `material_container` is stored as the §4.2 column it is,
##     in the INVENTORY CONTAINER generation namespace -- not the directory's -- and this store
##     holds no `inventory.gd` reference with which to attest it, so `set_material_container()`
##     range-validates the pair and nothing more. Four distinct generation namespaces exist
##     (directory, inventory container, inventory lot, navigation route); every OTHER reference on
##     this row is a DIRECTORY reference validated through `EntityDirectory.is_valid_of_kind()`.
##   * NO JOB IS CREATED. REQ-SET-124's "material-delivery and construction work" become Job rows
##     in `jobs.gd`, and `work.gd` owns the productive tick that would call `add_work_mwu()`.
##     Neither file is touched here and neither calls this store yet.
##   * NO COMMAND IS DISPATCHED. PLACE_BLUEPRINT / PLACE_FURNITURE / DESIGNATE_ROOM / UPGRADE /
##     DEMOLISH / SET_DOOR_OPEN integration is the rest of task 06.1 and is not done.
##   * ROAD SEGMENTS ARE BUILDINGS HERE. §4.2's "road segment" is `dirt_path` / `paved_path`,
##     which are BuildingDefinition rows with a 1x1 footprint, so they need no fourth purpose.
##     `dirt_path`'s bill is §4.1's literal `[]`, which is why an empty bill opens straight into
##     PHASE_READY instead of waiting forever for a delivery that can never come.

const Catalog := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ExcavationContract := preload("res://scripts/core/excavation_contract.gd")
const ModularContract := preload("res://scripts/core/modular_project_contract.gd")
const ColumnProofs := preload("res://scripts/core/column_proofs.gd")

## systems_architecture.md §2.2 and entity_directory.gd's KIND_CAPACITY, which must agree.
const CONSTRUCTION_CAPACITY: int = 82944

## The per-project stride of the delivered ledger. The largest authored bill is THREE typed pairs
## (§4.1 hall/kitchen/workshop/weir/boathouse/brewery/preserver, §4.2 hall/residence, §4.3
## kitchen_bench); the fourth slot is spare so that ECON-003's added brace input cannot force a
## column reallocation. `_assert_bills()` refuses construction if any authored row exceeds it.
const MATERIAL_SLOTS_PER_PROJECT: int = 4

## The flattened lengths of the owner-major ledger and of the three immutable bill tables,
## named so that `resize()` takes a constant expression and the memory ledger can quote it:
## 82944 x 4 = 331776 delivered cells, 30 x 4 = 120 building bill cells, 9 x 4 = 36 furniture.
const BUILDING_KINDS: int = BuildingDefinitions.BUILDING_DEFINITION_COUNT
const FURNITURE_KINDS: int = BuildingDefinitions.FURNITURE_DEFINITION_COUNT
const DELIVERED_CELLS: int = CONSTRUCTION_CAPACITY * MATERIAL_SLOTS_PER_PROJECT
const BUILDING_BILL_CELLS: int = BUILDING_KINDS * MATERIAL_SLOTS_PER_PROJECT
const FURNITURE_BILL_CELLS: int = FURNITURE_KINDS * MATERIAL_SLOTS_PER_PROJECT

## The distinct material keys §4.1, §4.2 and §4.3 name. A bill column stores an INDEX into this
## array, not a compiled ItemDefinition id: ids are compiled at runtime from `item_definitions.gd`
## and ARCH-CAT-004 forbids compiling one in. A caller resolves the key it reads here.
const MATERIAL_KEYS: Array[StringName] = [
	&"wood", &"stone", &"cloth", &"iron", &"rope", &"wax",
]
const MATERIAL_KEY_COUNT: int = 6

## §4.1's `materials_milli` column, verbatim, as flat `key, milli` pairs. Decision 0088 left this
## table to "the store that needs it" rather than transcribing a typed pair list into an int32
## column in `building_definitions.gd`; this is that store, and this is the representation it
## chose. `dirt_path`'s `[]` is §4.1's own empty bill and is not an omission.
const BUILD_MATERIALS: Dictionary = {
	"apiary": ["wood", 12000, "rope", 2000],
	"boathouse": ["wood", 40000, "stone", 16000, "rope", 4000],
	"brewery": ["wood", 24000, "stone", 12000, "iron", 2000],
	"cellar": ["wood", 20000, "stone", 60000],
	"composter": ["wood", 10000],
	"covered_store": ["wood", 35000, "stone", 10000],
	"dirt_path": [],
	"dryer": ["wood", 16000, "rope", 4000],
	"fence": ["wood", 1000],
	"fisher_shelter": ["wood", 18000, "rope", 2000],
	"forester_lodge": ["wood", 20000, "stone", 8000],
	"gate": ["wood", 6000, "iron", 1000],
	"hall": ["wood", 100000, "stone", 60000, "cloth", 12000],
	"infirmary": ["wood", 40000, "stone", 30000, "cloth", 12000],
	"kitchen": ["wood", 30000, "stone", 20000, "iron", 2000],
	"lookout": ["wood", 12000, "stone", 4000],
	"memorial_garden": ["wood", 8000, "stone", 12000],
	"mill": ["wood", 25000, "stone", 30000],
	"nursery": ["wood", 16000, "stone", 8000],
	"open_stockpile": ["wood", 4000],
	"paved_path": ["stone", 1000],
	"preserver": ["wood", 20000, "stone", 24000, "iron", 2000],
	"quarry_shed": ["wood", 16000, "stone", 8000],
	"residence": ["wood", 60000, "stone", 24000, "cloth", 8000],
	"saltpan": ["wood", 8000, "stone", 16000],
	"stone_wall": ["stone", 3000],
	"weir": ["wood", 30000, "stone", 12000, "rope", 6000],
	"well": ["wood", 10000, "stone", 20000],
	"workbench": ["wood", 12000, "stone", 4000],
	"workshop": ["wood", 35000, "stone", 20000, "iron", 4000],
}

## §4.2's tier-1 to tier-2 upgrade packages: materials then `work_mwu`. BAL-CAT-006 restricts the
## packages to these four keys and `building_definitions.accepts_tier()` already enforces it, so a
## fifth row here would be refused by `_assert_bills()` rather than silently unlocking a mill.
const UPGRADE_MATERIALS: Dictionary = {
	"covered_store": ["wood", 25000, "stone", 20000],
	"hall": ["wood", 20000, "stone", 40000, "cloth", 8000],
	"residence": ["wood", 20000, "stone", 40000, "cloth", 8000],
	"workshop": ["wood", 20000, "iron", 8000],
}
const UPGRADE_WORK_MWU: Dictionary = {
	"covered_store": 600000, "hall": 1200000, "residence": 1200000, "workshop": 720000,
}

## §4.3's `materials_milli` column, verbatim.
const FURNITURE_MATERIALS: Dictionary = {
	"bed": ["wood", 2000, "cloth", 1000],
	"decoration": ["wood", 1000, "wax", 250],
	"hearth": ["stone", 6000],
	"interior_door": ["wood", 2000],
	"interior_partition": ["wood", 1000],
	"kitchen_bench": ["wood", 4000, "stone", 4000, "iron", 1000],
	"patient_bed": ["wood", 2000, "cloth", 2000],
	"seat": ["wood", 1000],
	"shelf": ["wood", 2000],
}

## What a project is FOR. Not a catalog domain: no document numbers these and `catalog.gd` is not
## this module's to extend, so they are module ordinals and a save codec must pin them itself.
const PURPOSE_BUILD: int = 0
const PURPOSE_UPGRADE: int = 1
const PURPOSE_FURNITURE: int = 2
const PURPOSE_DEMOLISH: int = 3
const PURPOSE_COUNT: int = 4
## Decision 0536 (Brendan's P2 ruling on decision 0535): ONE piece of furniture taken out of a
## standing building -- removal work a quarter of the piece's §4.3 WU, return 50% of its bill.
## DELIBERATELY OUTSIDE PURPOSE_COUNT. ADR 0186's frozen local Columns validation pins purposes
## 0..3 (`SOURCE_PURPOSE_COUNT`), so it refuses a removal row COLUMN_ENUM -- fail closed -- until
## CONSTRUCTION-SAVED-BINDINGS revisits that contract. LIVE_PURPOSE_COUNT is the domain this
## store's own doors accept.
const PURPOSE_REMOVE_FURNITURE: int = 4
## Site operations append a live-only purpose. Legacy column/save domains remain frozen and
## explicitly reject these rows until a versioned excavation codec is integrated (decision 1056).
const PURPOSE_EXCAVATION: int = 5
## Decision 1069: actual spatial Furniture and World-qualified local tip subjects.
## The frozen PURPOSE_COUNT / Columns codec deliberately remains 4.
const PURPOSE_SPATIAL_FURNITURE: int = 6
const PURPOSE_SPOIL_TIP: int = 7
const PURPOSE_CONNECTOR_INSTALL: int = 8
const LIVE_PURPOSE_COUNT: int = 9

## Where a project is in REQ-SET-124-127's sequence. See the header on ECON-003's separate
## excavation-site phases, which these are NOT.
const PHASE_AWAITING_MATERIALS: int = 0
const PHASE_READY: int = 1
const PHASE_WORKING: int = 2
const PHASE_WORK_DONE: int = 3
const PHASE_REFUNDING: int = 4
const PHASE_COUNT: int = 5

## §4.2's `refund_policy: enum`, whose three values are REQ-SET-126's two fractions and
## REQ-SET-127's one. It is a LATCH recomputed from `purpose` and `work_begun` on every
## transition, never incrementally edited, so `verify_refund_policies()` can recompute and compare
## the whole column the way `buildings.verify_room_masks()` does for the furniture mask.
const REFUND_FULL: int = 0
const REFUND_PARTIAL: int = 1
const REFUND_DEMOLITION: int = 2
const REFUND_POLICY_COUNT: int = 3

## REQ-SET-126: "100% of delivered materials ... after work begins it shall return 80% ... rounded
## down to milli-U". 80% is 4/5 and the division floors; quantities are already milli-U.
const REFUND_FULL_NUM: int = 1
const REFUND_FULL_DEN: int = 1
const REFUND_PARTIAL_NUM: int = 4
const REFUND_PARTIAL_DEN: int = 5

## REQ-SET-127: "return 50% original material costs after the declared construction WU x 0.25".
const REFUND_DEMOLITION_NUM: int = 1
const REFUND_DEMOLITION_DEN: int = 2
const DEMOLITION_WORK_NUM: int = 1
const DEMOLITION_WORK_DEN: int = 4

const STATE_BLUEPRINT: int = Catalog.BUILDING_STATE["BLUEPRINT"]
const STATE_BUILDING: int = Catalog.BUILDING_STATE["BUILDING"]
const STATE_ACTIVE: int = Catalog.BUILDING_STATE["ACTIVE"]
const STATE_DEMOLISHING: int = Catalog.BUILDING_STATE["DEMOLISHING"]

## GDD §5.9: "Maximum 4 builders/project unless listed". Every §4.1 row lists exactly 4 and
## `_assert_bills()` refuses construction otherwise, so a furniture project -- which §4.3 gives no
## `max_builders` column at all -- inherits the STATED cap rather than an invented one.
const MAX_BUILDERS: int = 4

const NULL_REF: Vector2i = EntityDirectory.NULL_REF
const NO_ROW: int = EntityDirectory.NULL_SLOT
const INT32_MAX: int = 2147483647

const REFUSE_NONE: StringName = &""
const REFUSE_STALE_PROJECT_REF: StringName = &"STALE_PROJECT_REF"
const REFUSE_STALE_BUILDING_REF: StringName = &"STALE_BUILDING_REF"
const REFUSE_STALE_FURNITURE_REF: StringName = &"STALE_FURNITURE_REF"
const REFUSE_SUBJECT_LOST: StringName = &"SUBJECT_LOST"
const REFUSE_ALREADY_UNDER_CONSTRUCTION: StringName = &"ALREADY_UNDER_CONSTRUCTION"
const REFUSE_NOT_A_BLUEPRINT: StringName = &"NOT_A_BLUEPRINT"
const REFUSE_NOT_ACTIVE: StringName = &"BUILDING_NOT_ACTIVE"
const REFUSE_NO_UPGRADE_PACKAGE: StringName = &"NO_UPGRADE_PACKAGE"
const REFUSE_ALREADY_TIER_TWO: StringName = &"ALREADY_TIER_TWO"
const REFUSE_UNKNOWN_PURPOSE: StringName = &"UNKNOWN_PURPOSE"
const REFUSE_UNKNOWN_BUILDING_TYPE: StringName = &"UNKNOWN_BUILDING_TYPE"
const REFUSE_UNKNOWN_FURNITURE_TYPE: StringName = &"UNKNOWN_FURNITURE_TYPE"
const REFUSE_MATERIAL_INDEX: StringName = &"MATERIAL_INDEX_OUT_OF_BILL"
const REFUSE_UNKNOWN_MATERIAL_KEY: StringName = &"UNKNOWN_MATERIAL_KEY"
const REFUSE_NOT_IN_BILL: StringName = &"MATERIAL_NOT_IN_BILL"
const REFUSE_QUANTITY: StringName = &"INVALID_QUANTITY"
const REFUSE_OVER_DELIVERY: StringName = &"OVER_DELIVERY"
const REFUSE_MATERIALS_INCOMPLETE: StringName = &"MATERIALS_INCOMPLETE"
const REFUSE_WRONG_PHASE: StringName = &"WRONG_PHASE"
const REFUSE_PAUSED: StringName = &"PROJECT_PAUSED"
const REFUSE_INVALID_WORK: StringName = &"INVALID_WORK_MWU"
const REFUSE_INVALID_WORKERS: StringName = &"INVALID_ASSIGNED_COUNT"
const REFUSE_INVALID_CONTAINER_REF: StringName = &"INVALID_CONTAINER_REF"
const REFUSE_NOT_A_DEMOLITION: StringName = &"NOT_A_DEMOLITION"
const REFUSE_IS_A_DEMOLITION: StringName = &"IS_A_DEMOLITION"
const REFUSE_OCCUPANTS_PRESENT: StringName = &"DEMOLITION_BLOCKED_OCCUPANTS"
const REFUSE_FURNITURE_IN_USE: StringName = &"DEMOLITION_BLOCKED_FURNITURE_USER"
const REFUSE_OVERFLOW: StringName = &"INT64_OVERFLOW"
const REFUSE_POLICY_MISMATCH: StringName = &"REFUND_POLICY_MISMATCH"
const REFUSE_MANIFEST_BUFFER: StringName = &"DEMOLITION_MANIFEST_BUFFER_TOO_SMALL"
## `retire_demolition()` (decision 0535): the building a finished demolition acts on still stands,
## so retiring the project would leave a DEMOLISHING building with no project behind it.
const REFUSE_SUBJECT_STANDING: StringName = &"DEMOLITION_SUBJECT_STILL_STANDING"
## Decision 0536 (Brendan's P3 ruling): a demolition or a furniture removal completes and is
## cancelled ONLY through the coordinator, which releases its Inventory claim and destroys its
## stores first. `commit_completion()` and `close_refund()` refuse such a row by this name.
const REFUSE_COORDINATOR_ONLY: StringName = &"DEMOLITION_COMPLETES_THROUGH_COORDINATOR"

## A demolition's combined return names at most every material key once: the building's base +
## upgrade lines and each piece of furniture's (decision 0536), so a caller's buffers hold six.
const RETURN_LINE_CAPACITY: int = MATERIAL_KEY_COUNT

## BUILD-C4-R01's ConstructionPaidLedger (ARCH §3: `base_type, upgrade_mask`, I32 x 82944): the
## exact paid package KEYS each project row was admitted with. Costs are never stored; they are
## read back from the compiled §4.1/§4.2 bills, which the save header's rules hash pins.
## NO_PAID_PACKAGE is "this row paid no base package" -- an UPGRADE project pays only its upgrade.
const NO_PAID_PACKAGE: int = -1
## Bit 0 of `upgrade_mask`: §4.2's one tier-1 -> tier-2 package ("tier 3 is absent").
const UPGRADE_TIER_TWO_BIT: int = 1


class OpResult:
	"""Outcome of one construction operation: flag, refusal code, value, reference.

	`.ok` MUST be inspected before `.value` or `.ref`. A refusal carries value 0 and the null
	reference `(-1, 0)` and NEVER a partially applied effect: every mutator validates completely
	before it writes a byte (decision 0059, allocate before consume).
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


# --- collaborators ------------------------------------------------------------------------------

var _excavation_authority: WeakRef = null
var _modular_authority: WeakRef = null
var _modular_quote: ModularContract.Quote = ModularContract.Quote.new()
var _buildings: Buildings = null
var _owns_buildings: bool = false
var _directory: EntityDirectory = null
var _definitions: BuildingDefinitions = null

# --- immutable bill columns (gameplay_balance.md §4.1, §4.2, §4.3) -------------------------------

var _build_key: PackedInt32Array = PackedInt32Array()
var _build_milli: PackedInt64Array = PackedInt64Array()
var _build_count: PackedInt32Array = PackedInt32Array()
var _upgrade_key: PackedInt32Array = PackedInt32Array()
var _upgrade_milli: PackedInt64Array = PackedInt64Array()
var _upgrade_count: PackedInt32Array = PackedInt32Array()
var _upgrade_work: PackedInt64Array = PackedInt64Array()
var _furniture_key: PackedInt32Array = PackedInt32Array()
var _furniture_milli: PackedInt64Array = PackedInt64Array()
var _furniture_count: PackedInt32Array = PackedInt32Array()

# --- Construction columns (GDD §4.2, architecture §2.2) -----------------------------------------

var _material_container_slot: PackedInt32Array = PackedInt32Array()
var _material_container_generation: PackedInt32Array = PackedInt32Array()
var _assigned_count: PackedInt32Array = PackedInt32Array()
var _max_workers: PackedInt32Array = PackedInt32Array()
var _refund_policy: PackedInt32Array = PackedInt32Array()
var _remaining_mwu: PackedInt64Array = PackedInt64Array()
var _paused: PackedByteArray = PackedByteArray()

# --- index columns (new; reported for the §3 ledger) ---------------------------------------------

var _present: PackedByteArray = PackedByteArray()
var _work_begun: PackedByteArray = PackedByteArray()
var _ref_slot: PackedInt32Array = PackedInt32Array()
var _ref_generation: PackedInt32Array = PackedInt32Array()
var _subject_slot: PackedInt32Array = PackedInt32Array()
var _subject_generation: PackedInt32Array = PackedInt32Array()
var _purpose: PackedInt32Array = PackedInt32Array()
var _type_id: PackedInt32Array = PackedInt32Array()
var _phase: PackedInt32Array = PackedInt32Array()

## The per-project delivered ledger, owner-major at stride MATERIAL_SLOTS_PER_PROJECT.
var _delivered_milli: PackedInt64Array = PackedInt64Array()

# --- ConstructionPaidLedger (BUILD-C4-R01; ARCH §3, already budgeted at 663552 B) ----------------

## The base package key a row was admitted with, or NO_PAID_PACKAGE; and its completed-upgrade
## bits. A DEMOLITION row's pair is the SNAPSHOT of its building's paid packages at admission; a
## REMOVE_FURNITURE row's base key is the piece's own furniture type (decision 0536). The key is
## a building id or a furniture id according to `_purpose`, exactly as `_type_id` is.
var _paid_base_type: PackedInt32Array = PackedInt32Array()
var _paid_upgrade_mask: PackedInt32Array = PackedInt32Array()
## Cold scratch for one return manifest: material key index and total milli per line.
var _manifest_key: PackedInt32Array = PackedInt32Array()
var _manifest_milli: PackedInt64Array = PackedInt64Array()
## Cold scratch for one HALVED return (decision 0536): the building's lines plus each piece's.
var _return_key: PackedInt32Array = PackedInt32Array()
var _return_milli: PackedInt64Array = PackedInt64Array()

var _live_count: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_buildings: Buildings = null) -> void:
	"""Adopt or build the Building store, compile the three bills, and size every column once."""
	@warning_ignore("assert_always_true") assert(CONSTRUCTION_CAPACITY
			== EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_CONSTRUCTION],
		"Construction columns must match the directory's CONSTRUCTION row capacity")
	_owns_buildings = p_buildings == null
	_buildings = p_buildings if p_buildings != null else Buildings.new()
	_directory = _buildings.directory()
	_definitions = _buildings.definitions()
	_allocate_columns()
	_compile_bills()
	_assert_bills()
	clear()


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once, never per tick)."""
	_material_container_slot.resize(CONSTRUCTION_CAPACITY)
	_material_container_generation.resize(CONSTRUCTION_CAPACITY)
	_assigned_count.resize(CONSTRUCTION_CAPACITY)
	_max_workers.resize(CONSTRUCTION_CAPACITY)
	_refund_policy.resize(CONSTRUCTION_CAPACITY)
	_remaining_mwu.resize(CONSTRUCTION_CAPACITY)
	_paused.resize(CONSTRUCTION_CAPACITY)
	_present.resize(CONSTRUCTION_CAPACITY)
	_work_begun.resize(CONSTRUCTION_CAPACITY)
	_ref_slot.resize(CONSTRUCTION_CAPACITY)
	_ref_generation.resize(CONSTRUCTION_CAPACITY)
	_subject_slot.resize(CONSTRUCTION_CAPACITY)
	_subject_generation.resize(CONSTRUCTION_CAPACITY)
	_purpose.resize(CONSTRUCTION_CAPACITY)
	_type_id.resize(CONSTRUCTION_CAPACITY)
	_phase.resize(CONSTRUCTION_CAPACITY)
	_delivered_milli.resize(DELIVERED_CELLS)
	_paid_base_type.resize(CONSTRUCTION_CAPACITY)
	_paid_upgrade_mask.resize(CONSTRUCTION_CAPACITY)
	_manifest_key.resize(MATERIAL_SLOTS_PER_PROJECT)
	_manifest_milli.resize(MATERIAL_SLOTS_PER_PROJECT)
	_return_key.resize(RETURN_LINE_CAPACITY)
	_return_milli.resize(RETURN_LINE_CAPACITY)
	_allocate_bill_columns()


func _allocate_bill_columns() -> void:
	"""Size the three immutable bill tables. Catalog data, inside §2.3's read-only arena."""
	_build_key.resize(BUILDING_BILL_CELLS)
	_build_milli.resize(BUILDING_BILL_CELLS)
	_build_count.resize(BUILDING_KINDS)
	_upgrade_key.resize(BUILDING_BILL_CELLS)
	_upgrade_milli.resize(BUILDING_BILL_CELLS)
	_upgrade_count.resize(BUILDING_KINDS)
	_upgrade_work.resize(BUILDING_KINDS)
	_furniture_key.resize(FURNITURE_BILL_CELLS)
	_furniture_milli.resize(FURNITURE_BILL_CELLS)
	_furniture_count.resize(FURNITURE_KINDS)


func _compile_bills() -> void:
	"""Place every authored bill at the id its catalog assigns to its key, never by table order."""
	_build_key.fill(-1)
	_upgrade_key.fill(-1)
	_furniture_key.fill(-1)
	for key: String in BUILD_MATERIALS.keys():
		var id: int = int(Catalog.BUILDING_DEFINITION[key])
		_build_count[id] = _write_bill(BUILD_MATERIALS[key], id, _build_key, _build_milli)
	for key: String in UPGRADE_MATERIALS.keys():
		var id: int = int(Catalog.BUILDING_DEFINITION[key])
		_upgrade_count[id] = _write_bill(UPGRADE_MATERIALS[key], id, _upgrade_key, _upgrade_milli)
		_upgrade_work[id] = int(UPGRADE_WORK_MWU[key])
	for key: String in FURNITURE_MATERIALS.keys():
		var id: int = int(Catalog.FURNITURE_DEFINITION[key])
		_furniture_count[id] = _write_bill(
			FURNITURE_MATERIALS[key], id, _furniture_key, _furniture_milli)


func _write_bill(pairs: Array, id: int, keys: PackedInt32Array,
		milli: PackedInt64Array) -> int:
	"""Expand one flat `key, milli` list into the owner-major columns; return its pair count."""
	@warning_ignore("integer_division") var count: int = pairs.size() / 2
	assert(pairs.size() % 2 == 0, "a materials_milli row must be whole key/quantity pairs")
	assert(count <= MATERIAL_SLOTS_PER_PROJECT, "a bill exceeds MATERIAL_SLOTS_PER_PROJECT")
	for index: int in count:
		var key_index: int = MATERIAL_KEYS.find(StringName(pairs[index * 2]))
		assert(key_index >= 0, "'%s' is not a known material key" % pairs[index * 2])
		var quantity: int = int(pairs[index * 2 + 1])
		assert(quantity > 0, "an authored material quantity must be positive")
		keys[id * MATERIAL_SLOTS_PER_PROJECT + index] = key_index
		milli[id * MATERIAL_SLOTS_PER_PROJECT + index] = quantity
	return count


func _assert_bills() -> void:
	"""Refuse to construct on a bill the catalogs cannot account for, or an inexact demolition."""
	assert(BUILD_MATERIALS.size() == BuildingDefinitions.BUILDING_DEFINITION_COUNT,
		"BUILD_MATERIALS must carry exactly one §4.1 row per BuildingDefinition key")
	assert(FURNITURE_MATERIALS.size() == BuildingDefinitions.FURNITURE_DEFINITION_COUNT,
		"FURNITURE_MATERIALS must carry exactly one §4.3 row per FurnitureDefinition key")
	assert(UPGRADE_MATERIALS.size() == BuildingDefinitions.TIER_TWO_KEYS.size()
			and UPGRADE_WORK_MWU.size() == UPGRADE_MATERIALS.size(),
		"UPGRADE_MATERIALS must carry exactly BAL-CAT-006's four tier-2 packages")
	for key: String in UPGRADE_MATERIALS.keys():
		assert(BuildingDefinitions.TIER_TWO_KEYS.has(key),
			"'%s' has an upgrade package but does not accept tier 2" % key)
	for type_id: int in BuildingDefinitions.BUILDING_DEFINITION_COUNT:
		assert(_definitions.work_mwu_of(type_id) % DEMOLITION_WORK_DEN == 0,
			"every §4.1 work_mwu must divide exactly by 4 for REQ-SET-127's x0.25")
		assert(_definitions.max_builders_of(type_id) == MAX_BUILDERS,
			"§5.9's four-builder cap must be what §4.1 lists, or MAX_BUILDERS is a fiction")
	for type_id: int in BuildingDefinitions.FURNITURE_DEFINITION_COUNT:
		assert(_definitions.furniture_work_mwu_of(type_id) % DEMOLITION_WORK_DEN == 0,
			"every §4.3 work_mwu must divide exactly by 4 for REQ-SET-127's x0.25")
	for key: String in UPGRADE_MATERIALS.keys():
		assert(_distinct_package_keys(int(Catalog.BUILDING_DEFINITION[key]))
				<= MATERIAL_SLOTS_PER_PROJECT,
			"BUILD-C4-R01's base + upgrade manifest of '%s' must fit one project's lines" % key)


func _distinct_package_keys(type_id: int) -> int:
	"""How many distinct material keys a definition's base and upgrade packages name together."""
	var seen: int = 0
	var count: int = 0
	var base: int = type_id * MATERIAL_SLOTS_PER_PROJECT
	for index: int in _build_count[type_id]:
		seen |= 1 << _build_key[base + index]
	for index: int in _upgrade_count[type_id]:
		seen |= 1 << _upgrade_key[base + index]
	for bit: int in MATERIAL_KEY_COUNT:
		count += (seen >> bit) & 1
	return count


func clear() -> void:
	"""Return every project column to its empty state without reallocating one of them."""
	_release_live_rows()
	_material_container_slot.fill(EntityDirectory.NULL_SLOT)
	_material_container_generation.fill(EntityDirectory.NULL_GENERATION)
	_assigned_count.fill(0)
	_max_workers.fill(0)
	_refund_policy.fill(REFUND_FULL)
	_remaining_mwu.fill(0)
	_paused.fill(0)
	_present.fill(0)
	_work_begun.fill(0)
	_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_subject_slot.fill(EntityDirectory.NULL_SLOT)
	_subject_generation.fill(EntityDirectory.NULL_GENERATION)
	_purpose.fill(PURPOSE_BUILD)
	_type_id.fill(-1)
	_phase.fill(PHASE_AWAITING_MATERIALS)
	_delivered_milli.fill(0)
	_paid_base_type.fill(NO_PAID_PACKAGE)
	_paid_upgrade_mask.fill(0)
	_live_count = 0
	if _owns_buildings:
		_buildings.clear()


func _release_live_rows() -> void:
	"""Hand this store's own directory slots back before the columns forget which they were.

	A SHARED Building store's directory may already have been cleared by the owning system, in
	which case every reference is stale and `destroy()` returns false; that is the same
	order-independent release `buildings.gd` and `resource_nodes.gd` perform.
	"""
	for row: int in CONSTRUCTION_CAPACITY:
		if _present[row] != 1:
			continue
		_directory.destroy(Vector2i(_ref_slot[row], _ref_generation[row]))


func buildings() -> Buildings:
	"""The Building/Room/Furniture store every subject reference on this row is validated against."""
	return _buildings


func directory() -> EntityDirectory:
	"""The one allocator behind every DIRECTORY reference this store stores."""
	return _directory


func definitions() -> BuildingDefinitions:
	"""The immutable §4.1/§4.2/§4.3 facts this store prices work against."""
	return _definitions


# --- the bill of materials -----------------------------------------------------------------------

func _bill_stride_row(purpose: int, type_id: int) -> int:
	"""The owner-major base index of one bill, or NO_ROW when the purpose/type pair is unknown."""
	if purpose == PURPOSE_EXCAVATION:
		return 0 if ExcavationContract.valid_operation(type_id) else NO_ROW
	if purpose == PURPOSE_SPOIL_TIP or purpose == PURPOSE_CONNECTOR_INSTALL:
		return NO_ROW
	if is_furniture_subject(purpose):
		if not _definitions.is_furniture_id(type_id):
			return NO_ROW
		return type_id * MATERIAL_SLOTS_PER_PROJECT
	if not _definitions.is_building_id(type_id):
		return NO_ROW
	return type_id * MATERIAL_SLOTS_PER_PROJECT


func _bill_count_of(purpose: int, type_id: int) -> int:
	"""How many typed pairs a DELIVERY bill has; 0 for a demolition, which delivers nothing."""
	if _bill_stride_row(purpose, type_id) == NO_ROW:
		return 0
	if purpose == PURPOSE_EXCAVATION:
		return ExcavationContract.input_count(type_id)
	match purpose:
		PURPOSE_BUILD:
			return _build_count[type_id]
		PURPOSE_UPGRADE:
			return _upgrade_count[type_id]
		PURPOSE_FURNITURE, PURPOSE_SPATIAL_FURNITURE:
			return _furniture_count[type_id]
	return 0


func bill_size_into(purpose: int, type_id: int, out: IntMath.IntResult) -> bool:
	"""Write the DELIVERY bill's pair count into `out`; refuse an unknown purpose or type."""
	if purpose < 0 or purpose >= LIVE_PURPOSE_COUNT:
		return out.refuse(REFUSE_UNKNOWN_PURPOSE)
	if purpose == PURPOSE_SPOIL_TIP or purpose == PURPOSE_CONNECTOR_INSTALL:
		return out.refuse(ModularContract.REFUSE_PROJECT_CONTEXT)
	if _bill_stride_row(purpose, type_id) == NO_ROW:
		return out.refuse(REFUSE_UNKNOWN_FURNITURE_TYPE if is_furniture_subject(purpose)
			else REFUSE_UNKNOWN_BUILDING_TYPE)
	return out.succeed(_bill_count_of(purpose, type_id))


func _bill_key_column(purpose: int) -> PackedInt32Array:
	"""The key column a delivery purpose reads. A removal has no delivery bill (count 0)."""
	if purpose == PURPOSE_UPGRADE:
		return _upgrade_key
	if is_furniture_subject(purpose):
		return _furniture_key
	return _build_key


func _bill_milli_column(purpose: int) -> PackedInt64Array:
	"""The quantity column a delivery purpose reads. A removal has no delivery bill (count 0)."""
	if purpose == PURPOSE_UPGRADE:
		return _upgrade_milli
	if is_furniture_subject(purpose):
		return _furniture_milli
	return _build_milli


func material_key_index_into(purpose: int, type_id: int, index: int,
		out: IntMath.IntResult) -> bool:
	"""Write the MATERIAL_KEYS index of one bill entry into `out`; refuse outside the bill."""
	if not bill_size_into(purpose, type_id, out):
		return false
	if index < 0 or index >= out.value:
		return out.refuse(REFUSE_MATERIAL_INDEX)
	if purpose == PURPOSE_EXCAVATION:
		var key_index: int = MATERIAL_KEYS.find(ExcavationContract.input_key(type_id, index))
		return out.succeed(key_index) if key_index >= 0 else out.refuse(REFUSE_UNKNOWN_MATERIAL_KEY)
	var base: int = _bill_stride_row(purpose, type_id)
	return out.succeed(_bill_key_column(purpose)[base + index])


func required_milli_into(purpose: int, type_id: int, index: int,
		out: IntMath.IntResult) -> bool:
	"""Write one bill entry's required quantity_milli into `out`; refuse outside the bill."""
	if not bill_size_into(purpose, type_id, out):
		return false
	if index < 0 or index >= out.value:
		return out.refuse(REFUSE_MATERIAL_INDEX)
	return out.succeed(_required_milli_at(purpose, type_id, index))


func material_index_of_key_into(purpose: int, type_id: int, key: StringName,
		out: IntMath.IntResult) -> bool:
	"""Write the bill index carrying `key` into `out`. REFUSES rather than returning a sentinel.

	A caller that has resolved a compiled item id back to its key uses this to name the slot it
	is delivering into, so a load of wood can never be credited against the stone line.
	"""
	if purpose == PURPOSE_EXCAVATION:
		return _excavation_material_index_into(type_id, key, out)
	var key_index: int = MATERIAL_KEYS.find(key)
	if key_index < 0:
		return out.refuse(REFUSE_UNKNOWN_MATERIAL_KEY)
	if not bill_size_into(purpose, type_id, out):
		return false
	var count: int = out.value
	var base: int = _bill_stride_row(purpose, type_id)
	var column: PackedInt32Array = _bill_key_column(purpose)
	for index: int in count:
		if column[base + index] == key_index:
			return out.succeed(index)
	return out.refuse(REFUSE_NOT_IN_BILL)


func declared_work_mwu_into(purpose: int, type_id: int, out: IntMath.IntResult) -> bool:
	"""Write the total milli-WU a project of this purpose and type declares.

	For PURPOSE_DEMOLISH this is the TIER-1 price, the BASE §4.1 row x 0.25. A real demolition
	is priced by `open_demolition()` from its admission snapshot instead, which adds a completed
	upgrade's own work (BUILD-C4-R01: "one quarter of that same completed construction WU sum").
	"""
	if not bill_size_into(purpose, type_id, out):
		return false
	match purpose:
		PURPOSE_EXCAVATION:
			return out.succeed(ExcavationContract.work_mwu(type_id))
		PURPOSE_BUILD:
			return out.succeed(_definitions.work_mwu_of(type_id))
		PURPOSE_FURNITURE, PURPOSE_SPATIAL_FURNITURE:
			return out.succeed(_definitions.furniture_work_mwu_of(type_id))
		PURPOSE_UPGRADE:
			if _upgrade_count[type_id] == 0:
				return out.refuse(REFUSE_NO_UPGRADE_PACKAGE)
			return out.succeed(_upgrade_work[type_id])
		PURPOSE_REMOVE_FURNITURE:
			return IntMath.floor_div_into(_definitions.furniture_work_mwu_of(type_id)
				* DEMOLITION_WORK_NUM, DEMOLITION_WORK_DEN, out)
	return IntMath.floor_div_into(_definitions.work_mwu_of(type_id) * DEMOLITION_WORK_NUM,
		DEMOLITION_WORK_DEN, out)


# --- project lifecycle ---------------------------------------------------------------------------

func modular_binding_refusal(authority: ModularContract) -> StringName:
	"""Read-only composition preflight; a dead router binding cannot be silently replaced."""
	if authority == null or _modular_authority != null or authority.construction_owner() != self:
		return ModularContract.REFUSE_AUTHORITY
	return REFUSE_NONE if _directory.is_valid_of_kind(authority.world_ref(), EntityDirectory.KIND_WORLD) \
		else ModularContract.REFUSE_AUTHORITY


func bind_modular_authority(authority: ModularContract) -> OpResult:
	"""Bind the exact World-qualified router weakly after the paired Work preflight."""
	var code: StringName = modular_binding_refusal(authority)
	if code != REFUSE_NONE:
		return _refuse(code)
	_modular_authority = weakref(authority)
	return OpResult.new(true, REFUSE_NONE, 0, NULL_REF)


func has_modular_binding() -> bool:
	"""Distinguish a never-bound world from expired ownership that must not erase retained stock."""
	return _modular_authority != null


func modular_authority() -> ModularContract:
	"""Return only the still-live exact owner composition, not merely a typed weak target."""
	var authority: ModularContract = _modular_authority.get_ref() as ModularContract \
		if _modular_authority != null else null
	if authority == null or authority.construction_owner() != self \
			or not _directory.is_valid_of_kind(authority.world_ref(), EntityDirectory.KIND_WORLD):
		return null
	return authority


func spatial_furniture_batch_refusal(room: Vector2i, batch: EntityDirectory.CreateBatch,
		entries: PackedInt32Array) -> StringName:
	"""Preflight paired actual project rows and adopted catalog work before any identity publication."""
	var authority: ModularContract = modular_authority()
	if authority == null or authority.furniture_batch_preparation_refusal(room, batch) != &"":
		return ModularContract.REFUSE_AUTHORITY
	var code: StringName = _furniture_batch_shape_refusal(batch, entries)
	if code != REFUSE_NONE:
		return code
	# Every future Furniture generation is currently unallocated: no valid live project can
	# already name it. Rechecking the actual allocator avoids an N*82944 subject-table scan.
	return _directory.batch_candidate_refusal(batch)


func _furniture_batch_shape_refusal(batch: EntityDirectory.CreateBatch,
		entries: PackedInt32Array) -> StringName:
	"""Exact alternating namespaces and whole adopted recipes prevent caller-priced future subjects."""
	if batch == null or batch.directory_owner() != _directory or batch.storage_refusal() != &"" \
			or batch.count < 2 or batch.count > batch.capacity() or batch.count % 2 != 0 \
			or entries.size() != batch.count * 2:
		return ModularContract.REFUSE_QUOTE
	for index: int in range(0, batch.count, 2):
		var row: int = batch.typed_rows[index + 1]
		if batch.kinds[index] != EntityDirectory.KIND_FURNITURE \
				or batch.kinds[index + 1] != EntityDirectory.KIND_CONSTRUCTION \
				or row < 0 or row >= CONSTRUCTION_CAPACITY or _present[row] != 0:
			return ModularContract.REFUSE_QUOTE
		var type_id: int = entries[index * 2]
		if not _definitions.is_furniture_id(type_id) or _definitions.is_edge_furniture(type_id) \
				or _definitions.furniture_work_mwu_of(type_id) <= 0 \
				or _furniture_count[type_id] < 0 or _furniture_count[type_id] > MATERIAL_SLOTS_PER_PROJECT:
			return ModularContract.REFUSE_QUOTE
		for line: int in _furniture_count[type_id]:
			if material_key_at(PURPOSE_FURNITURE, type_id, line) == &"" \
					or _required_milli_at(PURPOSE_FURNITURE, type_id, line) <= 0:
				return ModularContract.REFUSE_QUOTE
	return REFUSE_NONE


func publish_spatial_furniture_batch(room: Vector2i, batch: EntityDirectory.CreateBatch,
		entries: PackedInt32Array) -> StringName:
	"""Initialize only preallocated actual project rows inside the Router's exact batch window."""
	var authority: ModularContract = modular_authority()
	if authority == null or authority.furniture_batch_publication_refusal(room, batch) != &"":
		return ModularContract.REFUSE_AUTHORITY
	var code: StringName = _furniture_batch_shape_refusal(batch, entries)
	if code != REFUSE_NONE:
		return code
	for index: int in batch.count:
		var ref: Vector2i = batch.ref_at(index)
		if not _directory.is_valid_of_kind(ref, batch.kinds[index]) \
				or _directory.get_typed_row(ref) != batch.typed_rows[index] \
				or _directory.get_persistent_id(ref) != batch.persistent_ids[index]:
			return ModularContract.REFUSE_AUTHORITY
	for index: int in range(0, batch.count, 2):
		var row: int = batch.typed_rows[index + 1]
		var type_id: int = entries[index * 2]
		_write_row(row, batch.ref_at(index + 1), PURPOSE_SPATIAL_FURNITURE, batch.ref_at(index),
			type_id, _definitions.furniture_work_mwu_of(type_id), MAX_BUILDERS, _furniture_count[type_id])
		_paid_base_type[row] = NO_PAID_PACKAGE
		_paid_upgrade_mask[row] = 0
		_live_count += 1
	return REFUSE_NONE


func open_modular_phase(purpose: int, subject: Vector2i, operation: int) -> OpResult:
	"""Allocate a real project only from the router's prepared immutable purpose-specific order."""
	if not is_modular(purpose):
		return _refuse(REFUSE_UNKNOWN_PURPOSE)
	var authority: ModularContract = modular_authority()
	if authority == null:
		return _refuse(ModularContract.REFUSE_AUTHORITY)
	_modular_quote.reset()
	var code: StringName = authority.project_open_into(purpose, subject, operation, _modular_quote)
	if code != REFUSE_NONE:
		return _refuse(code)
	code = _modular_quote_refusal(purpose, subject, operation)
	if code != REFUSE_NONE:
		return _refuse(code)
	if project_of_modular_subject(purpose, subject) != NULL_REF \
			or purpose == PURPOSE_SPATIAL_FURNITURE and _project_of_subject(subject) != NO_ROW:
		return _refuse(REFUSE_ALREADY_UNDER_CONSTRUCTION)
	var opened: OpResult = _open_row(purpose, subject, operation, _modular_quote.remaining_mwu,
		NO_PAID_PACKAGE, 0, _modular_quote.max_workers, _modular_quote.input_count)
	if opened.ok:
		authority.attach_project(purpose, subject, operation, opened.ref)
	return opened


func retire_modular_phase(project: Vector2i, authority: ModularContract) -> OpResult:
	"""Retire only inside the router's post-output/refund window; owner identity alone is insufficient."""
	if authority == null or authority != modular_authority():
		return _refuse(REFUSE_COORDINATOR_ONLY)
	var row: int = _row_of(project)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if not is_modular(_purpose[row]):
		return _refuse(REFUSE_UNKNOWN_PURPOSE)
	var code: StringName = authority.mutation_refusal(project, ModularContract.ACTION_RETIRE)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _phase[row] != PHASE_WORK_DONE and _phase[row] != PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	_retire(row, project, Vector2i(_subject_slot[row], _subject_generation[row]))
	_clear_retired_extension_row(row)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func _clear_retired_extension_row(row: int) -> void:
	"""A retired excavation or modular row returns to the exact never-used clear row (ADR 1228: the
	worker capacity too, which the frozen section 4 predicate requires of a typeless row)."""
	_purpose[row] = PURPOSE_BUILD
	_type_id[row] = -1
	_phase[row] = PHASE_AWAITING_MATERIALS
	_refund_policy[row] = REFUND_FULL
	_max_workers[row] = 0


func project_of_modular_subject(purpose: int, subject: Vector2i) -> Vector2i:
	"""Cold namespace-qualified lookup; local tip numbers never alias Directory subjects."""
	if not is_modular(purpose):
		return NULL_REF
	for row: int in CONSTRUCTION_CAPACITY:
		if _present[row] == 1 and _purpose[row] == purpose and _subject_slot[row] == subject.x \
				and _subject_generation[row] == subject.y:
			return _ref_of_row(row)
	return NULL_REF


func _modular_quote_refusal(purpose: int, subject: Vector2i, operation: int) -> StringName:
	"""Validate the finite quote and, for actual furniture, its exact protected catalog recipe."""
	var code: StringName = _modular_quote.refusal()
	if code != REFUSE_NONE or _modular_quote.subject != subject or _modular_quote.operation != operation:
		return ModularContract.REFUSE_QUOTE
	if purpose != PURPOSE_SPATIAL_FURNITURE:
		return REFUSE_NONE
	if not _is_spatial_furniture(subject) or _buildings.is_furniture_installed(subject):
		return REFUSE_STALE_FURNITURE_REF
	var type_id: int = _buildings.type_id_of_furniture(subject).value
	if type_id != operation or _modular_quote.quantity_milli != 0 \
			or _modular_quote.total_mwu != _definitions.furniture_work_mwu_of(type_id) \
			or _modular_quote.input_count != _furniture_count[type_id] \
			or _modular_quote.output_count != 0 or _modular_quote.max_workers != MAX_BUILDERS:
		return ModularContract.REFUSE_QUOTE
	for index: int in _modular_quote.input_count:
		if _modular_quote.input_keys[index] != material_key_at(PURPOSE_FURNITURE, type_id, index) \
				or _modular_quote.input_milli[index] != _required_milli_at(PURPOSE_FURNITURE, type_id, index):
			return ModularContract.REFUSE_QUOTE
	return REFUSE_NONE


func _is_spatial_furniture(furniture: Vector2i) -> bool:
	"""Actual Room ownership distinguishes underground pieces; a NO_LINK origin is not proof."""
	if not _buildings.is_live_furniture(furniture):
		return false
	var result: Buildings.OpResult = _buildings.spatial_kind_of_room(_buildings.room_ref_of_furniture(furniture))
	return result.ok and result.value == Buildings.ROOM_SPACE_UNDERGROUND


func _read_modular_facts(row: int) -> StringName:
	"""Read one exact project's owner facts into bounded reusable cold scratch."""
	var authority: ModularContract = modular_authority()
	if authority == null:
		return ModularContract.REFUSE_AUTHORITY
	_modular_quote.reset()
	var code: StringName = authority.project_facts_into(_ref_of_row(row), _modular_quote)
	if code != REFUSE_NONE:
		return code
	return _modular_quote_refusal(_purpose[row], Vector2i(_subject_slot[row], _subject_generation[row]), _type_id[row])


func _project_bill_count(row: int) -> int:
	"""Project-aware bill count; missing modular ownership returns -1, never a free bill."""
	if not is_modular(_purpose[row]):
		return _bill_count_of(_purpose[row], _type_id[row])
	return _modular_quote.input_count if _read_modular_facts(row) == REFUSE_NONE else -1


func _project_required_milli(row: int, index: int) -> int:
	"""Read an already-indexed project's immutable current operation price."""
	if not is_modular(_purpose[row]):
		return _required_milli_at(_purpose[row], _type_id[row], index)
	return _modular_quote.input_milli[index] if _read_modular_facts(row) == REFUSE_NONE else -1


func project_bill_size_into(project: Vector2i, out: IntMath.IntResult) -> bool:
	"""Use actual project context for quantity-dependent tip prices and ordinary recipes alike."""
	var row: int = _row_of(project)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	var count: int = _project_bill_count(row)
	return out.succeed(count) if count >= 0 else out.refuse(ModularContract.REFUSE_QUOTE)


func project_material_key_at(project: Vector2i, index: int) -> StringName:
	"""Resolve an exact project's named input without extending frozen legacy key ordinals."""
	var row: int = _row_of(project)
	if row == NO_ROW or index < 0 or index >= _project_bill_count(row):
		return &""
	return _modular_quote.input_keys[index] if is_modular(_purpose[row]) \
		else material_key_at(_purpose[row], _type_id[row], index)


func project_required_milli_into(project: Vector2i, index: int, out: IntMath.IntResult) -> bool:
	"""Read one exact operation bill line; stale identity or missing ownership refuses."""
	var row: int = _row_of(project)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	if index < 0 or index >= _project_bill_count(row):
		return out.refuse(REFUSE_MATERIAL_INDEX)
	var quantity: int = _project_required_milli(row, index)
	return out.succeed(quantity) if quantity > 0 else out.refuse(ModularContract.REFUSE_QUOTE)


func project_material_index_of_key_into(project: Vector2i, key: StringName,
		out: IntMath.IntResult) -> bool:
	"""Resolve a delivered actual Item key only against this exact project's bill."""
	if not project_bill_size_into(project, out):
		return false
	var count: int = out.value
	for index: int in count:
		if project_material_key_at(project, index) == key:
			return out.succeed(index)
	return out.refuse(REFUSE_NOT_IN_BILL)


static func is_modular(purpose: int) -> bool:
	"""The shared paid owner serves only explicit, independently qualified purpose namespaces."""
	return purpose == PURPOSE_SPATIAL_FURNITURE or purpose == PURPOSE_SPOIL_TIP \
		or purpose == PURPOSE_CONNECTOR_INSTALL


func bind_excavation_authority(authority: ExcavationContract) -> OpResult:
	"""Bind one physical-site owner weakly; one Construction store cannot serve duplicate ledgers."""
	var code: StringName = excavation_binding_refusal(authority)
	if code != REFUSE_NONE:
		return _refuse(code)
	_excavation_authority = weakref(authority)
	return OpResult.new(true, REFUSE_NONE, 0, NULL_REF)


func excavation_binding_refusal(authority: ExcavationContract) -> StringName:
	"""Read-only preflight for atomic composition with Work; expired bindings still refuse reuse."""
	return ExcavationContract.REFUSE_AUTHORITY if authority == null or _excavation_authority != null else REFUSE_NONE


func excavation_authority() -> ExcavationContract:
	"""Read the typed owner without creating a Construction-to-site reference cycle."""
	return _excavation_authority.get_ref() as ExcavationContract if _excavation_authority != null else null


func open_excavation_phase(site: Vector2i, operation: int) -> OpResult:
	"""Open one adopted phase with retained physical work supplied exclusively by its site owner."""
	var authority: ExcavationContract = excavation_authority()
	if authority == null:
		return _refuse(ExcavationContract.REFUSE_AUTHORITY)
	if not ExcavationContract.valid_operation(operation):
		return _refuse(REFUSE_UNKNOWN_PURPOSE)
	var refusal: StringName = authority.project_open_refusal(site, operation)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	if not authority.is_live_site(site):
		return _refuse(REFUSE_SUBJECT_LOST)
	if project_of_excavation_site(site) != NULL_REF:
		return _refuse(REFUSE_ALREADY_UNDER_CONSTRUCTION)
	if not authority.remaining_work_into(site, operation, _math):
		return _refuse(StringName(_math.error))
	if _math.value < 0 or _math.value > ExcavationContract.work_mwu(operation):
		return _refuse(REFUSE_INVALID_WORK)
	var opened: OpResult = _open_row(PURPOSE_EXCAVATION, site, operation, _math.value, NO_PAID_PACKAGE, 0)
	if opened.ok:
		authority.attach_project(site, operation, opened.ref)
	return opened


func retire_excavation_phase(project: Vector2i, authority: ExcavationContract) -> OpResult:
	"""The physical coordinator retires only after its actual output/refund transaction committed."""
	if authority == null or authority != excavation_authority():
		return _refuse(REFUSE_COORDINATOR_ONLY)
	var row: int = _row_of(project)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if _purpose[row] != PURPOSE_EXCAVATION:
		return _refuse(REFUSE_UNKNOWN_PURPOSE)
	var owner_refusal: StringName = authority.mutation_refusal(project, ExcavationContract.ACTION_RETIRE)
	if owner_refusal != REFUSE_NONE:
		return _refuse(owner_refusal)
	if _phase[row] != PHASE_WORK_DONE and _phase[row] != PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	_retire(row, project, Vector2i(_subject_slot[row], _subject_generation[row]))
	_clear_retired_extension_row(row)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func _owned_mutation_refusal(row: int, project: Vector2i, action: int) -> StringName:
	"""A generic accounting call cannot bypass the physical owner's actual transaction."""
	if is_modular(_purpose[row]):
		var modular: ModularContract = modular_authority()
		return modular.mutation_refusal(project, action) if modular != null else ModularContract.REFUSE_AUTHORITY
	if _purpose[row] != PURPOSE_EXCAVATION:
		return REFUSE_NONE
	var authority: ExcavationContract = excavation_authority()
	return authority.mutation_refusal(project, action) if authority != null else ExcavationContract.REFUSE_AUTHORITY


func project_of_excavation_site(site: Vector2i) -> Vector2i:
	"""Look up the site namespace explicitly; identical Building reference numbers are unrelated."""
	for row: int in CONSTRUCTION_CAPACITY:
		if _present[row] == 1 and _purpose[row] == PURPOSE_EXCAVATION:
			if _subject_slot[row] == site.x and _subject_generation[row] == site.y:
				return _ref_of_row(row)
	return NULL_REF


func material_key_at(purpose: int, type_id: int, index: int) -> StringName:
	"""Key-based bill reader covering earth without renumbering the legacy MATERIAL_KEYS domain."""
	if not bill_size_into(purpose, type_id, _math) or index < 0 or index >= _math.value:
		return &""
	if purpose == PURPOSE_EXCAVATION:
		return ExcavationContract.input_key(type_id, index)
	return MATERIAL_KEYS[_bill_key_column(purpose)[_bill_stride_row(purpose, type_id) + index]]


func _required_milli_at(purpose: int, type_id: int, index: int) -> int:
	"""Read already validated bill coordinates from the appropriate immutable owner domain."""
	if purpose == PURPOSE_EXCAVATION:
		return ExcavationContract.input_milli(type_id, index)
	return _bill_milli_column(purpose)[_bill_stride_row(purpose, type_id) + index]


func _excavation_material_index_into(operation: int, key: StringName, out: IntMath.IntResult) -> bool:
	"""Resolve a phase bill key without widening the frozen legacy material index domain."""
	if not ExcavationContract.valid_operation(operation):
		return out.refuse(REFUSE_UNKNOWN_PURPOSE)
	for index: int in ExcavationContract.input_count(operation):
		if ExcavationContract.input_key(operation, index) == key:
			return out.succeed(index)
	return out.refuse(REFUSE_NOT_IN_BILL)


func open_build(building_ref: Vector2i) -> OpResult:
	"""REQ-SET-124: publish the project behind one BLUEPRINT building, deducting nothing.

	The delivered ledger starts at zero on every line, so no physical store is touched and no
	material is reserved. Refuses -- writing nothing -- on a stale building, a building that is
	not a BLUEPRINT, one that already carries a project, or a full directory.
	"""
	var code: StringName = _refuse_open_building(building_ref, STATE_BLUEPRINT)
	if code != REFUSE_NONE:
		return _refuse(code)
	var type_id: int = _buildings.type_id_of_building(building_ref).value
	return _open(PURPOSE_BUILD, building_ref, type_id)


func open_upgrade(building_ref: Vector2i) -> OpResult:
	"""REQ-SET-136: publish the tier-1 to tier-2 upgrade project for one ACTIVE building.

	Refuses a definition §4.2's upgrade table omits, and a building already at tier 2 -- "Only one
	upgrade per building; tier 3 is absent".
	"""
	var code: StringName = _refuse_open_building(building_ref, STATE_ACTIVE)
	if code != REFUSE_NONE:
		return _refuse(code)
	var type_id: int = _buildings.type_id_of_building(building_ref).value
	if _upgrade_count[type_id] == 0:
		return _refuse(REFUSE_NO_UPGRADE_PACKAGE)
	if _buildings.tier_of_building(building_ref).value >= BuildingDefinitions.TIER_TWO:
		return _refuse(REFUSE_ALREADY_TIER_TWO)
	return _open(PURPOSE_UPGRADE, building_ref, type_id)


func open_demolition(building_ref: Vector2i) -> OpResult:
	"""REQ-SET-127/128: publish a demolition project once the building is evacuated.

	Refuses with the exact blocked count while any room reports occupants or any furniture has a
	live user. The stored-goods half of REQ-SET-128 is NOT enforced here and the header says why.
	The project's work is the declared construction WU x 0.25 and it delivers no material at all.

	NOT THE PLAYER-FACING GATE: it sees no container. REQ-SET-128 in full is
	`settlement_system.gd::request_demolition()`. BUILD-C4-R01's SNAPSHOT is taken in the same
	write that publishes the row: the base package and, at tier 2, the completed upgrade.
	"""
	var code: StringName = _refuse_open_building(building_ref, STATE_ACTIVE)
	if code != REFUSE_NONE:
		return _refuse(code)
	var occupants: int = occupant_count_of_building(building_ref)
	if occupants > 0:
		return OpResult.new(false, REFUSE_OCCUPANTS_PRESENT, occupants, NULL_REF)
	var users: int = furniture_user_count_of_building(building_ref)
	if users > 0:
		return OpResult.new(false, REFUSE_FURNITURE_IN_USE, users, NULL_REF)
	var type_id: int = _buildings.type_id_of_building(building_ref).value
	var mask: int = demolition_upgrade_mask_of(building_ref)
	if not _demolition_work_into(building_ref, type_id, mask, _math):
		return _refuse(StringName(_math.error))
	var opened: OpResult = _open_row(PURPOSE_DEMOLISH, building_ref, type_id, _math.value,
		type_id, mask)
	if opened.ok:
		_buildings.set_building_state(building_ref, STATE_DEMOLISHING)
	return opened


func demolition_open_refusal(building_ref: Vector2i) -> StringName:
	"""Every refusal `open_demolition()` can return, decided without writing a byte.

	The coordinator's admit step runs this BEFORE its first write, so the store-level transition
	it then makes cannot refuse: the subject, the resident half, the snapshot's work and a free
	CONSTRUCTION directory row are all proved here.
	"""
	var code: StringName = _refuse_open_building(building_ref, STATE_ACTIVE)
	if code != REFUSE_NONE:
		return code
	if occupant_count_of_building(building_ref) > 0:
		return REFUSE_OCCUPANTS_PRESENT
	if furniture_user_count_of_building(building_ref) > 0:
		return REFUSE_FURNITURE_IN_USE
	var type_id: int = _buildings.type_id_of_building(building_ref).value
	if not _demolition_work_into(building_ref, type_id, demolition_upgrade_mask_of(building_ref),
			_math):
		return StringName(_math.error)
	return _directory.create_refusal(EntityDirectory.KIND_CONSTRUCTION)


func demolition_upgrade_mask_of(building_ref: Vector2i) -> int:
	"""The completed-upgrade bits a demolition of this building would snapshot right now.

	BAL-SAFE-013: tier 2 is set ONCE, by a completed upgrade, so tier 2 is the record that the
	upgrade package was paid and completed. An in-progress upgrade leaves tier 1 and also holds
	the building's construction link, so a demolition cannot even be admitted beside it.
	"""
	var tier: Buildings.OpResult = _buildings.tier_of_building(building_ref)
	if tier.ok and tier.value >= BuildingDefinitions.TIER_TWO:
		return UPGRADE_TIER_TWO_BIT
	return 0


func _demolition_work_into(building_ref: Vector2i, type_id: int, mask: int,
		out: IntMath.IntResult) -> bool:
	"""BUILD-C4-R01's demolition work plus a quarter of every piece of furniture's §4.3 WU.

	A quarter of the base WU plus each completed upgrade's; then, by Brendan's ruling on decision
	0535 (recorded in 0536), a quarter of each piece's WU, for every piece in the building's rooms
	now. `_assert_bills()` proves every §4.3 WU divides by 4, so no piece's quarter is floored.
	"""
	if not _definitions.is_building_id(type_id):
		return out.refuse(REFUSE_UNKNOWN_BUILDING_TYPE)
	var total: int = _definitions.work_mwu_of(type_id)
	if mask & UPGRADE_TIER_TWO_BIT != 0:
		if _upgrade_count[type_id] == 0:
			return out.refuse(REFUSE_NO_UPGRADE_PACKAGE)
		total += _upgrade_work[type_id]
	if not IntMath.checked_mul_into(total, DEMOLITION_WORK_NUM, out):
		return out.refuse(REFUSE_OVERFLOW)
	if not IntMath.floor_div_into(out.value, DEMOLITION_WORK_DEN, out):
		return false
	return out.succeed(out.value + _furniture_removal_work_of(building_ref))


func _furniture_removal_work_of(building_ref: Vector2i) -> int:
	"""A quarter of the §4.3 WU of every piece in a building's rooms, summed. Exact (divisible)."""
	var total: int = 0
	for room_row: int in _buildings.rooms_of_building(building_ref):
		for furniture_row: int in _buildings.furniture_rows_in_room(
				_buildings.room_ref_of_row(room_row)):
			var piece: Vector2i = _buildings.furniture_ref_of_row(furniture_row)
			@warning_ignore("integer_division") total += _definitions.furniture_work_mwu_of(
				_buildings.type_id_of_furniture(piece).value) * DEMOLITION_WORK_NUM / DEMOLITION_WORK_DEN
	return total


func open_furniture(furniture_ref: Vector2i) -> OpResult:
	"""Publish the §4.3 construction project for one placed furniture row.

	`buildings.gd` publishes a furniture row committed -- §4.2 gives Furniture no state column --
	so the row exists before its project completes. Nothing was invented to give it one.
	"""
	if not _buildings.is_live_furniture(furniture_ref):
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	if _is_spatial_furniture(furniture_ref):
		return _refuse(REFUSE_COORDINATOR_ONLY)
	if _project_of_subject(furniture_ref) != NO_ROW:
		return _refuse(REFUSE_ALREADY_UNDER_CONSTRUCTION)
	return _open(PURPOSE_FURNITURE, furniture_ref,
		_buildings.type_id_of_furniture(furniture_ref).value)


func furniture_removal_open_refusal(furniture_ref: Vector2i) -> StringName:
	"""Every refusal `open_furniture_removal()` can return, decided without writing a byte.

	A stale piece; a piece that already carries a project (it is still being built, or already
	being removed: "At most 1 project/... furniture"); a piece a resident is using; a full
	CONSTRUCTION directory kind.
	"""
	if not _buildings.is_live_furniture(furniture_ref):
		return REFUSE_STALE_FURNITURE_REF
	if _is_spatial_furniture(furniture_ref):
		return REFUSE_COORDINATOR_ONLY
	if _project_of_subject(furniture_ref) != NO_ROW:
		return REFUSE_ALREADY_UNDER_CONSTRUCTION
	if _buildings.user_ref_of_furniture(furniture_ref) != NULL_REF:
		return REFUSE_FURNITURE_IN_USE
	return _directory.create_refusal(EntityDirectory.KIND_CONSTRUCTION)


func open_furniture_removal(furniture_ref: Vector2i) -> OpResult:
	"""Decision 0536 (P2): publish the project that takes one piece out of a standing building.

	Its work is a quarter of the piece's §4.3 WU; it delivers nothing; its paid-ledger base key is
	the piece's own type, DERIVED as ruling R4 derives a building's (P1), so its return is 50% of
	that bill. A STORE-LEVEL transition like `open_demolition()`: the coordinator's
	`request_furniture_removal()` is the player-facing gate.
	"""
	var code: StringName = furniture_removal_open_refusal(furniture_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	var type_id: int = _buildings.type_id_of_furniture(furniture_ref).value
	if not declared_work_mwu_into(PURPOSE_REMOVE_FURNITURE, type_id, _math):
		return _refuse(StringName(_math.error))
	return _open_row(PURPOSE_REMOVE_FURNITURE, furniture_ref, type_id, _math.value, type_id, 0)


func _refuse_open_building(building_ref: Vector2i, required_state: int) -> StringName:
	"""The code blocking a building-subject project, or REFUSE_NONE when one may be opened."""
	if not _buildings.is_live_building(building_ref):
		return REFUSE_STALE_BUILDING_REF
	if _buildings.construction_ref_of_building(building_ref) != NULL_REF:
		return REFUSE_ALREADY_UNDER_CONSTRUCTION
	var state: int = _buildings.state_of_building(building_ref).value
	if state != required_state:
		return REFUSE_NOT_A_BLUEPRINT if required_state == STATE_BLUEPRINT else REFUSE_NOT_ACTIVE
	return REFUSE_NONE


func _open(purpose: int, subject_ref: Vector2i, type_id: int) -> OpResult:
	"""Allocate the directory row and write the project, after every refusal has been ruled out."""
	if not declared_work_mwu_into(purpose, type_id, _math):
		return _refuse(StringName(_math.error))
	var base: int = NO_PAID_PACKAGE if purpose == PURPOSE_UPGRADE else type_id
	var mask: int = UPGRADE_TIER_TWO_BIT if purpose == PURPOSE_UPGRADE else 0
	return _open_row(purpose, subject_ref, type_id, _math.value, base, mask)


func _open_row(purpose: int, subject_ref: Vector2i, type_id: int, work: int, paid_base: int,
		paid_mask: int, worker_limit: int = -1, input_count: int = -1) -> OpResult:
	"""Allocate the row, write it with its paid-ledger keys, and link the building subject."""
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_CONSTRUCTION)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var row: int = _directory.get_typed_row(ref)
	_write_row(row, ref, purpose, subject_ref, type_id, work, worker_limit, input_count)
	_paid_base_type[row] = paid_base
	_paid_upgrade_mask[row] = paid_mask
	if not is_furniture_subject(purpose) and purpose != PURPOSE_EXCAVATION and not is_modular(purpose):
		_buildings.set_building_construction(subject_ref, ref)
	_live_count += 1
	return OpResult.new(true, REFUSE_NONE, row, ref)


func _write_row(row: int, ref: Vector2i, purpose: int, subject_ref: Vector2i, type_id: int,
		work: int, worker_limit: int = -1, input_count: int = -1) -> void:
	"""Initialize every Construction column of a freshly allocated row before it is published."""
	_material_container_slot[row] = EntityDirectory.NULL_SLOT
	_material_container_generation[row] = EntityDirectory.NULL_GENERATION
	_assigned_count[row] = 0
	_max_workers[row] = worker_limit if worker_limit > 0 else _max_workers_for(purpose, type_id)
	_remaining_mwu[row] = work
	_paused[row] = 0
	_present[row] = 1
	_work_begun[row] = 0
	_ref_slot[row] = ref.x
	_ref_generation[row] = ref.y
	_subject_slot[row] = subject_ref.x
	_subject_generation[row] = subject_ref.y
	_purpose[row] = purpose
	_type_id[row] = type_id
	for index: int in MATERIAL_SLOTS_PER_PROJECT:
		_delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index] = 0
	var count: int = input_count if input_count >= 0 else _bill_count_of(purpose, type_id)
	_phase[row] = PHASE_AWAITING_MATERIALS if count > 0 else PHASE_READY
	_refund_policy[row] = _policy_for(purpose, 0)


func _max_workers_for(purpose: int, type_id: int) -> int:
	"""GDD §5.9's "Maximum 4 builders/project unless listed", read from the owning definition."""
	if purpose == PURPOSE_EXCAVATION:
		return ExcavationContract.MAX_QUANTUM_WORKERS
	if is_furniture_subject(purpose):
		return MAX_BUILDERS
	return _definitions.max_builders_of(type_id)


static func _policy_for(purpose: int, work_begun: int) -> int:
	"""§4.2's `refund_policy`, derived from the only two facts REQ-SET-126/127 depend on."""
	if is_removal(purpose):
		return REFUND_DEMOLITION
	return REFUND_PARTIAL if work_begun == 1 else REFUND_FULL


func deliver_material(project_ref: Vector2i, index: int, quantity_milli: int) -> OpResult:
	"""REQ-SET-124: credit one bill line with materials the caller has already moved physically.

	Refuses -- crediting nothing -- outside PHASE_AWAITING_MATERIALS, while paused, on a
	non-positive quantity, and on any delivery that would exceed the line's requirement. When the
	last line completes, the project advances to PHASE_READY and build work becomes available.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	var owner_refusal: StringName = _owned_mutation_refusal(row, project_ref, ExcavationContract.ACTION_DELIVER)
	if owner_refusal != REFUSE_NONE:
		return _refuse(owner_refusal)
	var code: StringName = _refuse_delivery(row, index, quantity_milli)
	if code != REFUSE_NONE:
		return _refuse(code)
	var cell: int = row * MATERIAL_SLOTS_PER_PROJECT + index
	_delivered_milli[cell] = _math.value
	if _all_materials_delivered(row):
		_phase[row] = PHASE_READY
	return OpResult.new(true, REFUSE_NONE, _delivered_milli[cell], project_ref)


func _refuse_delivery(row: int, index: int, quantity_milli: int) -> StringName:
	"""Validate one delivery completely; leave `_math` holding the new total on success."""
	if _phase[row] != PHASE_AWAITING_MATERIALS:
		return REFUSE_WRONG_PHASE
	if _paused[row] == 1:
		return REFUSE_PAUSED
	if quantity_milli <= 0:
		return REFUSE_QUANTITY
	if index < 0 or index >= _project_bill_count(row):
		return REFUSE_MATERIAL_INDEX
	var required: int = _project_required_milli(row, index)
	if required <= 0:
		return ModularContract.REFUSE_QUOTE
	var cell: int = row * MATERIAL_SLOTS_PER_PROJECT + index
	if not IntMath.checked_add_into(_delivered_milli[cell], quantity_milli, _math):
		return REFUSE_OVERFLOW
	if _math.value > required:
		return REFUSE_OVER_DELIVERY
	return REFUSE_NONE


func _all_materials_delivered(row: int) -> bool:
	"""True when every line of this project's delivery bill has reached its required quantity."""
	var count: int = _project_bill_count(row)
	if count < 0:
		return false
	for index: int in count:
		var required: int = _project_required_milli(row, index)
		if required <= 0 or _delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index] < required:
			return false
	return true


func begin_work(project_ref: Vector2i) -> OpResult:
	"""REQ-SET-125: consume the delivered materials into the project and enable build work.

	This is the ONLY transition that sets `work_begun`, and therefore the only place REQ-SET-126's
	refund fraction changes from 100% to 80%. It refuses unless every bill line is complete, so no
	project can earn a milli-WU against materials that were never delivered.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	var owner_refusal: StringName = _owned_mutation_refusal(row, project_ref, ExcavationContract.ACTION_BEGIN_WORK)
	if owner_refusal != REFUSE_NONE:
		return _refuse(owner_refusal)
	if _phase[row] != PHASE_READY:
		return _refuse(REFUSE_WRONG_PHASE)
	if _paused[row] == 1:
		return _refuse(REFUSE_PAUSED)
	if not _all_materials_delivered(row):
		return _refuse(REFUSE_MATERIALS_INCOMPLETE)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if not _subject_is_live(row, subject):
		return _refuse(REFUSE_SUBJECT_LOST)
	_work_begun[row] = 1
	_phase[row] = PHASE_WORK_DONE if (_purpose[row] == PURPOSE_EXCAVATION or is_modular(_purpose[row])) \
		and _remaining_mwu[row] == 0 else PHASE_WORKING
	_refund_policy[row] = _policy_for(_purpose[row], 1)
	if _purpose[row] == PURPOSE_BUILD:
		_buildings.set_building_state(subject, STATE_BUILDING)
	return OpResult.new(true, REFUSE_NONE, _remaining_mwu[row], project_ref)


static func excavation_start_refusal(actual: RefCounted, sites: ExcavationContract,
		project: Vector2i, job: Vector2i, paid: bool, output: Vector2i, mass: int) -> StringName:
	"""Exact purpose5 START facts are read without bill, spatial, worker or source observers."""
	var code: StringName = _excavation_start_context(actual, sites, project, job, paid)
	if code != REFUSE_NONE:
		return code
	var row: int = actual._directory.get_typed_row(project)
	var site: int = sites._candidate_row
	if row < 0 or row >= CONSTRUCTION_CAPACITY or actual._present[row] != 1 \
			or actual._ref_slot[row] != project.x or actual._ref_generation[row] != project.y \
			or actual._purpose[row] != PURPOSE_EXCAVATION or actual._subject_slot[row] != site \
			or actual._subject_generation[row] != sites.SITE_GENERATION \
			or actual._type_id[row] != sites._operation[site]:
		return REFUSE_STALE_PROJECT_REF
	if actual._paused[row] != 0:
		return REFUSE_PAUSED
	if actual._phase[row] != PHASE_READY or actual._work_begun[row] != 0 \
			or actual._remaining_mwu[row] < 0 or actual._max_workers[row] < 1:
		return REFUSE_WRONG_PHASE
	code = _excavation_start_job(actual, sites, row, site, project, job)
	if code == REFUSE_NONE:
		code = _excavation_start_bill(actual, sites, row, paid)
	if code == REFUSE_NONE:
		code = _excavation_start_output(sites, site, output, mass)
	return _excavation_start_receipt(sites, row, project, job, paid, output, mass) if code == REFUSE_NONE else code


static func _excavation_start_context(actual: RefCounted, sites: ExcavationContract,
		project: Vector2i, job: Vector2i, paid: bool) -> StringName:
	"""A coincident handle or permissive base cannot enter the actual synchronous Sites window."""
	if actual == null or sites == null or not "_starting" in sites or not sites._starting \
			or sites._start_poisoned or sites._ready_error != REFUSE_NONE or sites._construction != actual \
			or actual._excavation_authority == null or actual._excavation_authority.get_ref() != sites \
			or sites._permit_project != project \
			or sites._permit_action != (ExcavationContract.ACTION_BEGIN_WORK if paid else ExcavationContract.ACTION_WIP) \
			or sites._candidate_stage != ExcavationContract.STAGE_START \
			or sites._candidate_row < 0 or sites._candidate_row >= sites._count:
		return ExcavationContract.REFUSE_AUTHORITY
	var at: int = sites._candidate_row
	var funding: RefCounted = sites._funding
	if sites._present[at] != 1 or sites._project_slot[at] != project.x or sites._project_generation[at] != project.y \
			or sites._job_slot[at] != job.x or sites._job_generation[at] != job.y \
			or sites._jobs._directory != actual._directory or funding == null or funding._ready_error != REFUSE_NONE \
			or funding._construction != actual or funding._inventory != sites._inventory or funding._pool != sites._pool \
			or funding._items != sites._items or not sites._items._loaded \
			or sites._items._registered_inventory == null or sites._items._registered_inventory.get_ref() != sites._inventory:
		return ExcavationContract.REFUSE_AUTHORITY
	return REFUSE_NONE if actual._directory.is_valid_of_kind(project, EntityDirectory.KIND_CONSTRUCTION) \
		and actual._directory.is_valid_of_kind(job, EntityDirectory.KIND_JOB) \
		and actual._directory.is_valid_of_kind(sites._domain.world_ref, EntityDirectory.KIND_WORLD) else REFUSE_STALE_PROJECT_REF


static func _excavation_start_job(actual: RefCounted, sites: ExcavationContract,
		row: int, site: int, project: Vector2i, job: Vector2i) -> StringName:
	"""The sole accepted BUILD Job must still mirror exact retained physical work and worker ownership."""
	var jobs: RefCounted = sites._jobs
	var at: int = actual._directory.get_typed_row(job)
	var operation: int = actual._type_id[row]
	if at < 0 or at >= sites._job_site.size() or jobs._job_present[at] != 1 \
			or jobs._job_ref_slot[at] != job.x or jobs._job_ref_generation[at] != job.y \
			or sites._job_site[at] != site or jobs._requester_slot[at] != project.x \
			or jobs._requester_generation[at] != project.y or jobs._is_coordinator[at] != 0 \
			or jobs._coordinator_slot[at] != -1 or jobs._kind[at] != jobs.JOB_KIND_BUILD \
			or jobs._remaining_mwu[at] != actual._remaining_mwu[row] \
			or not ExcavationContract.valid_operation(operation):
		return sites.REFUSE_JOB
	var earned: int = sites._earned_mwu[site * ExcavationContract.OP_COUNT + operation]
	if earned < 0 or actual._remaining_mwu[row] != ExcavationContract.work_mwu(operation) - earned:
		return REFUSE_WRONG_PHASE
	var code: StringName = _excavation_start_physical(sites, site, operation)
	return _excavation_start_worker(sites, site, at, job) if code == REFUSE_NONE else code


static func _excavation_start_physical(sites: ExcavationContract, row: int, operation: int) -> StringName:
	"""The final same-operation phase must still have its real required retained support state."""
	var phase: int = sites._phase[row]
	var installed: int = sites._installed[row]
	var allowed: bool = false
	match operation:
		ExcavationContract.OP_BRACE:
			allowed = installed == 0 and (phase == sites.SOLID or phase == sites.BACKFILLED or phase == sites.BRACING)
		ExcavationContract.OP_CUT:
			allowed = installed == 1 and (phase == sites.BRACED or phase == sites.CUTTING)
		ExcavationContract.OP_FINISH:
			allowed = installed == 1 and (phase == sites.OPEN_UNFINISHED or phase == sites.FINISHING)
		ExcavationContract.OP_BACKFILL_CLOSE:
			allowed = installed == 1 and (phase == sites.OPEN_UNFINISHED or phase == sites.FINISHING \
				or phase == sites.SUPPORTED_VOID or phase == sites.CLOSING and sites._closure_before[row] != sites.BRACED \
				and sites._closure_before[row] != sites.CUTTING)
		ExcavationContract.OP_UNOPENED_SUPPORT_CLOSE:
			allowed = installed == 1 and (phase == sites.BRACED or phase == sites.CUTTING \
				or phase == sites.CLOSING and (sites._closure_before[row] == sites.BRACED or sites._closure_before[row] == sites.CUTTING))
	return REFUSE_NONE if allowed else sites.REFUSE_PHASE


static func _excavation_start_worker(sites: ExcavationContract, site: int, job_row: int, job: Vector2i) -> StringName:
	"""Read actual assignment, life stage and eligibility columns after the final spatial observer."""
	var jobs: RefCounted = sites._jobs
	var worker: Vector2i = Vector2i(jobs._worker_slot[job_row], jobs._worker_generation[job_row])
	if not jobs._directory.is_valid_of_kind(worker, EntityDirectory.KIND_RESIDENT):
		return sites.REFUSE_WORKER
	var row: int = jobs._directory.get_typed_row(worker)
	var residents: RefCounted = sites._work._residents
	if residents != jobs._residents or row < 0 or row >= sites._worker_site.size() \
			or residents._present[row] != 1 or residents._ref_slot[row] != worker.x \
			or residents._ref_generation[row] != worker.y or residents._life_stage[row] == residents.LIFE_STAGE_CHILD \
			or jobs._agent_present[row] != 1 or jobs._agent_job_slot[row] != job.x \
			or jobs._agent_job_generation[row] != job.y or sites._worker_site[row] != site \
			or sites._worker_generation[row] != worker.y \
			or (jobs._tool_gate[job_row] != jobs.GATE_SATISFIED and jobs._tool_gate[job_row] != jobs.GATE_NOT_REQUIRED):
		return sites.REFUSE_WORKER
	var needs: RefCounted = jobs._needs
	if needs == null or needs != residents._needs or needs._present[row] != 1 \
			or needs._status[row] == needs.STATUS_DEAD or needs._status[row] == needs.STATUS_INCAPACITATED \
			or needs._need_value[row * needs.NEED_COUNT + needs.NEED_REST] <= jobs.REST_COLLAPSE_THRESHOLD:
		return sites.REFUSE_WORKER
	if jobs._tool_gate[job_row] == jobs.GATE_NOT_REQUIRED: # DEC-052: claws need no tool, and none is claimed.
		return REFUSE_NONE if sites._work._tool_lot_slot[row] == -1 else sites.REFUSE_WORKER
	return _excavation_start_tool(sites, row, worker, job)


static func _excavation_start_tool(sites: ExcavationContract, row: int, worker: Vector2i, job: Vector2i) -> StringName:
	"""Resolve Gear's full lot/owner/claim and positive durability directly, without observers."""
	var work: RefCounted = sites._work
	var gear: RefCounted = work._gear
	var inventory: RefCounted = sites._inventory
	var lot: Vector2i = Vector2i(work._tool_lot_slot[row], work._tool_lot_generation[row])
	if gear == null or gear._inventory != inventory or lot.x < 0 or lot.x >= inventory._l_capacity \
			or inventory._l_live[lot.x] != 1 or inventory._l_generation[lot.x] != lot.y \
			or inventory._l_container_slot[lot.x] != -1 or work._tool_job_slot[row] != job.x \
			or work._tool_job_generation[row] != job.y or work._tool_broken[row] != 0:
		return sites.REFUSE_WORKER
	var at: int = gear._lot_row[lot.x]
	if at < 0 or at >= gear._row_capacity or gear._occupied[at] != 1 or gear._lot_slot[at] != lot.x \
			or gear._lot_generation[at] != lot.y or gear._equipped[at] != 1 \
			or gear._owner_slot[at] != worker.x or gear._owner_generation[at] != worker.y \
			or gear._claim_job_slot[at] != job.x or gear._claim_job_generation[at] != job.y or gear._durability[at] <= 0 \
			or sites._work._residents._equip_tool_item_id[row] != gear._item_id[at]:
		return sites.REFUSE_WORKER
	return REFUSE_NONE


static func _excavation_start_bill(actual: RefCounted, sites: ExcavationContract, row: int, paid: bool) -> StringName:
	"""Every delivered and staged item quantity still equals the adopted immutable operation bill."""
	var operation: int = actual._type_id[row]
	var funding: RefCounted = sites._funding
	var count: int = ExcavationContract.input_count(operation)
	if count < 0 or funding._s_count < 0 or (not paid and funding._s_count > funding._free_count):
		return REFUSE_MATERIALS_INCOMPLETE
	for line: int in MATERIAL_SLOTS_PER_PROJECT:
		var amount: int = ExcavationContract.input_milli(operation, line) if line < count else 0
		if actual._delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + line] != amount:
			return REFUSE_MATERIALS_INCOMPLETE
	for item: int in funding._s_totals.size():
		var amount: int = 0
		for line: int in count:
			var key: StringName = ExcavationContract.input_key(operation, line)
			if sites._items._item_ids.get(key, -1) == item:
				amount = ExcavationContract.input_milli(operation, line)
		if funding._s_totals[item] != amount or funding._s_returned[item] != amount:
			return REFUSE_MATERIALS_INCOMPLETE
	return REFUSE_NONE


static func _excavation_start_output(sites: ExcavationContract, site: int, output: Vector2i, mass: int) -> StringName:
	"""The original staged output must still be the Site's exact finite full-generation container."""
	if output != Vector2i(sites._output_slot[site], sites._output_generation[site]):
		return sites.REFUSE_OUTPUT
	var operation: int = sites._operation[site]
	var expected: int = 0
	if operation == ExcavationContract.OP_CUT:
		expected = _excavation_output_mass(sites, &"excavated_earth", ExcavationContract.EARTH_MILLI)
	elif operation == ExcavationContract.OP_BACKFILL_CLOSE or operation == ExcavationContract.OP_UNOPENED_SUPPORT_CLOSE:
		var wood: int = _excavation_output_mass(sites, &"wood", ExcavationContract.SALVAGE_WOOD_MILLI)
		var stone: int = _excavation_output_mass(sites, &"stone", ExcavationContract.SALVAGE_STONE_MILLI)
		expected = wood + stone if wood >= 0 and stone >= 0 else -1
	if mass != expected or expected < 0:
		return sites.REFUSE_OUTPUT
	if mass == 0:
		return REFUSE_NONE if output == NULL_REF else sites.REFUSE_OUTPUT
	var inventory: RefCounted = sites._inventory
	if output.x < 0 or output.x >= inventory._c_capacity or inventory._c_live[output.x] != 1 \
			or inventory._c_generation[output.x] != output.y or inventory._c_reachable[output.x] != 1 \
			or inventory._c_reserved_mass_g[output.x] < mass \
			or inventory._c_used_mass_g[output.x] + inventory._c_reserved_mass_g[output.x] > inventory._c_max_mass_g[output.x]:
		return sites.REFUSE_OUTPUT
	return REFUSE_NONE


static func _excavation_output_mass(sites: ExcavationContract, key: StringName, quantity: int) -> int:
	"""Exact per-lot rounded output mass reads the actual registered item column without callbacks."""
	var item: int = sites._items._item_ids.get(key, -1)
	var inventory: RefCounted = sites._inventory
	if item < 0 or item >= inventory._item_mass_g.size() or inventory._item_mass_g[item] <= 0:
		return -1
	@warning_ignore("integer_division")
	return (quantity * inventory._item_mass_g[item] + 999) / 1000


static func _excavation_start_receipt(sites: ExcavationContract, row: int, project: Vector2i,
		job: Vector2i, paid: bool, output: Vector2i, mass: int) -> StringName:
	"""Free-input phases need no receipt nodes; they still need exact funded identity and output ownership."""
	var funding: RefCounted = sites._funding
	var funded: bool = funding._project_slot[row] == project.x and funding._project_generation[row] == project.y
	if paid:
		return REFUSE_NONE if funded and funding._output_slot[row] == output.x \
			and funding._output_generation[row] == output.y and funding._output_mass_g[row] == mass \
			and (funding._s_count == 0 or funding._head[row] >= 0) and not sites._inventory._tx_open \
			and funding._settling_project == NULL_REF and funding._settling_job == NULL_REF else REFUSE_WRONG_PHASE
	return REFUSE_NONE if not funded and sites._inventory._tx_open \
		and funding._settling_project == project and funding._settling_job == job else REFUSE_WRONG_PHASE


static func begin_excavation_work_preflighted(actual: RefCounted, sites: ExcavationContract,
		project: Vector2i, job: Vector2i) -> OpResult:
	"""Publish only the exact already-paid START without calling the ordinary owner/bill observers."""
	var scope: StringName = _excavation_start_context(actual, sites, project, job, true)
	if scope != REFUSE_NONE:
		return OpResult.new(false, scope, 0, NULL_REF)
	var row: int = actual._directory.get_typed_row(project)
	var funding: RefCounted = sites._funding
	var output: Vector2i = Vector2i(funding._output_slot[row], funding._output_generation[row])
	var code: StringName = excavation_start_refusal(actual, sites, project, job, true, output, funding._output_mass_g[row])
	if code != REFUSE_NONE:
		return OpResult.new(false, code, 0, NULL_REF)
	actual._work_begun[row] = 1
	actual._phase[row] = PHASE_WORK_DONE if actual._remaining_mwu[row] == 0 else PHASE_WORKING
	actual._refund_policy[row] = REFUND_PARTIAL
	actual._assigned_count[row] = 1
	var job_row: int = actual._directory.get_typed_row(job)
	sites._jobs._state[job_row] = sites._jobs.JOB_STATE_COMPLETE if actual._remaining_mwu[row] == 0 else sites._jobs.JOB_STATE_WORK
	return OpResult.new(true, REFUSE_NONE, actual._remaining_mwu[row], project)


static func connector_start_refusal(actual: RefCounted, router: ModularContract,
		project: Vector2i, job: Vector2i, paid: bool) -> StringName:
	"""The same concrete prepayment/postpayment leaf proves exact start facts without an owner or Recipe callback."""
	var code: StringName = _connector_start_context(actual, router, project, paid)
	if code != REFUSE_NONE:
		return code
	var row: int = actual._directory.get_typed_row(project)
	if row < 0 or row >= CONSTRUCTION_CAPACITY or actual._present[row] != 1 \
			or actual._ref_slot[row] != project.x or actual._ref_generation[row] != project.y \
			or actual._purpose[row] != PURPOSE_CONNECTOR_INSTALL:
		return REFUSE_STALE_PROJECT_REF
	if actual._paused[row] != 0:
		return REFUSE_PAUSED
	if actual._phase[row] != PHASE_READY or actual._work_begun[row] != 0 or actual._remaining_mwu[row] < 0:
		return REFUSE_WRONG_PHASE
	code = _connector_start_job(actual, router, row, project, job)
	if code == REFUSE_NONE:
		code = _connector_start_bill(actual, router, row)
	return _connector_start_receipt(router, row, project, job, paid) if code == REFUSE_NONE else code


static func _connector_start_context(actual: RefCounted, router: ModularContract,
		project: Vector2i, paid: bool) -> StringName:
	"""A base/foreign authority or coincident numeric handles cannot borrow an actual Router settlement window."""
	if actual == null or router == null or not "_funding" in router or not "_connector_owner" in router \
			or not "_quote" in router or actual._modular_authority == null \
			or actual._modular_authority.get_ref() != router or router._construction != actual \
			or router._ready_error != REFUSE_NONE or not router._busy or router._permit_project != project \
			or router._permit_action != (ModularContract.ACTION_BEGIN_WORK if paid else ModularContract.ACTION_WIP) \
			or router._connector_owner == null or router._connector_owner.get_ref() == null:
		return ModularContract.REFUSE_AUTHORITY
	var funding: RefCounted = router._funding
	if funding == null or funding._ready_error != REFUSE_NONE or funding._construction != actual \
			or funding._inventory != router._inventory or funding._pool != router._pool or funding._items != router._items \
			or router._jobs._directory != actual._directory or not router._items._loaded \
			or router._items._registered_inventory == null or router._items._registered_inventory.get_ref() != router._inventory:
		return ModularContract.REFUSE_AUTHORITY
	if not actual._directory.is_valid_of_kind(router._world, EntityDirectory.KIND_WORLD) \
			or not actual._directory.is_valid_of_kind(project, EntityDirectory.KIND_CONSTRUCTION):
		return REFUSE_STALE_PROJECT_REF
	return REFUSE_NONE


static func _connector_start_job(actual: RefCounted, router: ModularContract,
		row: int, project: Vector2i, job: Vector2i) -> StringName:
	"""Validate the actual accepted primary Job and unchanged remaining work from concrete mirrored rows."""
	if not actual._directory.is_valid_of_kind(job, EntityDirectory.KIND_JOB):
		return ModularContract.REFUSE_AUTHORITY
	var at: int = actual._directory.get_typed_row(job)
	var jobs: RefCounted = router._jobs
	if at < 0 or at >= router._job_slot.size() or jobs._job_present[at] != 1 \
			or jobs._job_ref_slot[at] != job.x or jobs._job_ref_generation[at] != job.y \
			or router._job_slot[at] != job.x or router._job_generation[at] != job.y \
			or router._project_slot[at] != project.x or router._project_generation[at] != project.y \
			or jobs._requester_slot[at] != project.x or jobs._requester_generation[at] != project.y \
			or jobs._coordinator_slot[at] != -1 or jobs._remaining_mwu[at] != actual._remaining_mwu[row] \
			or jobs._kind[at] != router._quote.job_kind:
		return ModularContract.REFUSE_AUTHORITY
	return REFUSE_NONE


static func _connector_start_bill(actual: RefCounted, router: ModularContract, row: int) -> StringName:
	"""Retained prepared quotes and all four delivered cells must still equal the complete staged immutable bill."""
	var quote: ModularContract.Quote = router._quote
	var staged: ModularContract.Quote = router._funding._quote
	if quote == null or staged == null or quote.input_count < 1 or quote.input_count > MATERIAL_SLOTS_PER_PROJECT \
			or quote.input_keys.size() != MATERIAL_SLOTS_PER_PROJECT or quote.input_milli.size() != MATERIAL_SLOTS_PER_PROJECT \
			or staged.input_keys.size() != MATERIAL_SLOTS_PER_PROJECT or staged.input_milli.size() != MATERIAL_SLOTS_PER_PROJECT \
			or quote.subject != Vector2i(actual._subject_slot[row], actual._subject_generation[row]) \
			or quote.operation != actual._type_id[row] or quote.remaining_mwu != actual._remaining_mwu[row] \
			or quote.total_mwu <= 0 or quote.remaining_mwu > quote.total_mwu \
			or quote.max_workers != actual._max_workers[row] or quote.quantity_milli != 0 or quote.output_count != 0:
		return ModularContract.REFUSE_QUOTE
	if staged.subject != quote.subject or staged.operation != quote.operation or staged.total_mwu != quote.total_mwu \
			or staged.remaining_mwu != quote.remaining_mwu or staged.job_kind != quote.job_kind \
			or staged.max_workers != quote.max_workers or staged.input_count != quote.input_count \
			or staged.quantity_milli != 0 or staged.output_count != 0:
		return ModularContract.REFUSE_QUOTE
	for line: int in MATERIAL_SLOTS_PER_PROJECT:
		var code: StringName = _connector_start_line(actual, router, row, line)
		if code != REFUSE_NONE:
			return code
	return REFUSE_NONE


static func _connector_start_line(actual: RefCounted, router: ModularContract, row: int, line: int) -> StringName:
	"""Item IDs come from the actual registered catalog, without an overridable lookup after payment."""
	var quote: ModularContract.Quote = router._quote
	var funding: RefCounted = router._funding
	var amount: int = quote.input_milli[line]
	if quote.input_keys[line] != funding._quote.input_keys[line] or amount != funding._quote.input_milli[line] \
			or actual._delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + line] != amount:
		return REFUSE_MATERIALS_INCOMPLETE
	if line >= quote.input_count:
		return REFUSE_NONE if amount == 0 and quote.input_keys[line] == &"" else ModularContract.REFUSE_QUOTE
	var item: int = router._items._item_ids.get(quote.input_keys[line], -1)
	if amount <= 0 or item < 0 or item >= funding._s_totals.size() \
			or funding._s_totals[item] != amount or funding._s_returned[item] != amount:
		return REFUSE_MATERIALS_INCOMPLETE
	for previous: int in line:
		if quote.input_keys[previous] == quote.input_keys[line]:
			return ModularContract.REFUSE_QUOTE
	return REFUSE_NONE


static func _connector_start_receipt(router: ModularContract, row: int,
		project: Vector2i, job: Vector2i, paid: bool) -> StringName:
	"""The pure tail requires the full actual receipt; the prepayment leaf requires its original open transaction."""
	var funding: RefCounted = router._funding
	var funded: bool = funding._project_slot[row] == project.x and funding._project_generation[row] == project.y
	if paid:
		return REFUSE_NONE if funded and funding._head[row] >= 0 and funding._output_slot[row] == -1 \
			and funding._output_mass_g[row] == 0 and funding._settling_project == NULL_REF \
			and funding._settling_job == NULL_REF and not router._inventory._tx_open else REFUSE_WRONG_PHASE
	return REFUSE_NONE if not funded and funding._settling_project == project \
		and funding._settling_job == job and router._inventory._tx_open else REFUSE_WRONG_PHASE


static func begin_connector_work_preflighted(actual: RefCounted, router: ModularContract,
		project: Vector2i, job: Vector2i) -> OpResult:
	"""Publish the preflighted connector-only start after WIP commits; ordinary begin_work remains unchanged."""
	var code: StringName = connector_start_refusal(actual, router, project, job, true)
	if code != REFUSE_NONE:
		return OpResult.new(false, code, 0, NULL_REF)
	var row: int = actual._directory.get_typed_row(project)
	actual._work_begun[row] = 1
	actual._phase[row] = PHASE_WORK_DONE if actual._remaining_mwu[row] == 0 else PHASE_WORKING
	actual._refund_policy[row] = REFUND_PARTIAL
	return OpResult.new(true, REFUSE_NONE, actual._remaining_mwu[row], project)


func add_work_mwu(project_ref: Vector2i, mwu: int) -> OpResult:
	"""Retire milli-WU against a working project; return the milli-WU still outstanding.

	Refuses in every phase but PHASE_WORKING, which is what makes REQ-SET-125's "as progress
	begins" a precondition rather than a comment. A contribution larger than the remainder is
	capped at it rather than refused: §5.3's capped final contribution semantics.

	Allocates one result; `add_work_mwu_into()` is the same door for the per-tick caller.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not add_work_mwu_into(project_ref, mwu, out):
		return _refuse(StringName(out.error))
	return OpResult.new(true, REFUSE_NONE, out.value, project_ref)


func add_work_mwu_into(project_ref: Vector2i, mwu: int, out: IntMath.IntResult) -> bool:
	"""`add_work_mwu()` without allocating: `out.value` is the milli-WU still outstanding.

	Decision 0537 (D6): the demolition work bridge credits each productive tick's accepted
	milli-WU here, on the tick path, so this form writes into a caller-owned result. The refusals
	and their order are `add_work_mwu()`'s, because that door now delegates to this one.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	var owner_refusal: StringName = _owned_mutation_refusal(row, project_ref, ExcavationContract.ACTION_WORK)
	if owner_refusal != REFUSE_NONE:
		return out.refuse(owner_refusal)
	if _phase[row] != PHASE_WORKING:
		return out.refuse(REFUSE_WRONG_PHASE)
	if _paused[row] == 1:
		return out.refuse(REFUSE_PAUSED)
	if mwu <= 0:
		return out.refuse(REFUSE_INVALID_WORK)
	_remaining_mwu[row] = maxi(0, _remaining_mwu[row] - mwu)
	if _remaining_mwu[row] == 0:
		_phase[row] = PHASE_WORK_DONE
	return out.succeed(_remaining_mwu[row])


func commit_completion(project_ref: Vector2i) -> OpResult:
	"""Atomically publish a finished BUILD, UPGRADE or FURNITURE project's result and retire it.

	ECON-003's commit-pending rule in force: if the Building edit refuses, the project stays in
	PHASE_WORK_DONE with its earned work intact and the retry costs nothing. A demolition or a
	furniture removal is REFUSED by name, COORDINATOR_ONLY (decision 0536): completing one here
	would skip its Inventory claim and leave its stores orphaned on a freed footprint.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if is_removal(_purpose[row]) or _purpose[row] == PURPOSE_EXCAVATION or is_modular(_purpose[row]):
		return _refuse(REFUSE_COORDINATOR_ONLY)
	if _phase[row] != PHASE_WORK_DONE:
		return _refuse(REFUSE_WRONG_PHASE)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if not _subject_is_live(row, subject):
		return _refuse(REFUSE_SUBJECT_LOST)
	var code: StringName = _apply_completion(row, subject)
	if code != REFUSE_NONE:
		return _refuse(code)
	_retire(row, project_ref, subject)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func _apply_completion(row: int, subject: Vector2i) -> StringName:
	"""Make the one Building edit this project's purpose commits, or report why it cannot."""
	match _purpose[row]:
		PURPOSE_BUILD:
			return REFUSE_NONE if _buildings.set_building_state(subject, STATE_ACTIVE).ok \
				else REFUSE_NOT_ACTIVE
		PURPOSE_UPGRADE:
			return REFUSE_NONE if _buildings.set_building_tier(
				subject, BuildingDefinitions.TIER_TWO).ok else REFUSE_NO_UPGRADE_PACKAGE
	return REFUSE_NONE


func _demolish_subject(row: int, subject: Vector2i) -> StringName:
	"""Unlink and remove a demolition's building; on a refusal relink it, leaving it untouched."""
	_buildings.set_building_construction(subject, NULL_REF)
	var result: Buildings.OpResult = _buildings.demolish_building(subject)
	if not result.ok:
		_buildings.set_building_construction(subject, _ref_of_row(row))
		return result.error
	return REFUSE_NONE


# --- the coordinator's split completion (DEMO-CONTAIN-R01 #6, decision 0535) ---------------------

func demolition_commit_refusal(project_ref: Vector2i) -> StringName:
	"""Why a finished removal could not be committed right now, or REFUSE_NONE. Writes nothing.

	The coordinator's composed completion runs this in its prove-everything phase: a live
	DEMOLITION or furniture-removal row whose work is done (PHASE_WORK_DONE: earned, not yet
	published) and whose subject still stands. Every other condition is the coordinator's.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return REFUSE_STALE_PROJECT_REF
	if not is_removal(_purpose[row]):
		return REFUSE_NOT_A_DEMOLITION
	if _phase[row] != PHASE_WORK_DONE:
		return REFUSE_WRONG_PHASE
	if not _subject_is_live(row, Vector2i(_subject_slot[row], _subject_generation[row])):
		return REFUSE_SUBJECT_LOST
	return REFUSE_NONE


func remove_demolished_subject(project_ref: Vector2i) -> OpResult:
	"""#6's subject step alone: remove a finished removal's building or piece; keep the row.

	`retire_demolition()` is the second half; #6 places the 50% return BETWEEN them. A demolition
	unlinks and removes its building (`demolish_building()`'s BUILDING_HAS_ROOMS refuses, relinked);
	a furniture removal removes its piece (`remove_furniture()`'s FURNITURE_IN_USE refuses).
	Refuses everything `demolition_commit_refusal()` names, writing nothing on any refusal.
	"""
	var code: StringName = demolition_commit_refusal(project_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	var row: int = _row_of(project_ref)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if _purpose[row] == PURPOSE_DEMOLISH:
		code = _demolish_subject(row, subject)
	else:
		code = _buildings.remove_furniture(subject).error
	if code != REFUSE_NONE:
		return _refuse(code)
	return OpResult.new(true, REFUSE_NONE, row, project_ref)


func retire_demolition(project_ref: Vector2i) -> OpResult:
	"""#6's step (6): retire a finished removal whose subject `remove_demolished_subject()` took.

	Refuses a stale ref, anything but a removal, a project whose work is not done, and -- by
	name, SUBJECT_STILL_STANDING -- one whose subject still stands, so no DEMOLISHING building is
	ever left with no project behind it. The row and its paid-ledger snapshot are freed.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if not is_removal(_purpose[row]):
		return _refuse(REFUSE_NOT_A_DEMOLITION)
	if _phase[row] != PHASE_WORK_DONE:
		return _refuse(REFUSE_WRONG_PHASE)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if _subject_is_live(row, subject):
		return _refuse(REFUSE_SUBJECT_STANDING)
	_retire(row, project_ref, subject)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func close_demolition_refund(project_ref: Vector2i) -> OpResult:
	"""The coordinator's cancellation half for a demolition or a furniture removal (P3, 0536).

	`close_refund()` refuses these by name; the coordinator releases the removal's Inventory claim
	first and then calls this. A cancelled demolition returns its building to ACTIVE; nothing is
	charged or returned either way (decision 0534's ruling R5). Refuses a stale ref, anything but
	a removal, and a project not yet in PHASE_REFUNDING, writing nothing.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if not is_removal(_purpose[row]):
		return _refuse(REFUSE_NOT_A_DEMOLITION)
	if _phase[row] != PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if _purpose[row] == PURPOSE_DEMOLISH and _buildings.is_live_building(subject):
		_buildings.set_building_state(subject, STATE_ACTIVE)
	_retire(row, project_ref, subject)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func _retire(row: int, project_ref: Vector2i, subject: Vector2i) -> void:
	"""Clear the subject's back-reference, free the row and hand the directory slot back."""
	if not is_furniture_subject(_purpose[row]) and _purpose[row] != PURPOSE_EXCAVATION \
			and not is_modular(_purpose[row]) and _buildings.is_live_building(subject):
		_buildings.set_building_construction(subject, NULL_REF)
	_present[row] = 0
	_work_begun[row] = 0
	_ref_slot[row] = EntityDirectory.NULL_SLOT
	_ref_generation[row] = EntityDirectory.NULL_GENERATION
	_subject_slot[row] = EntityDirectory.NULL_SLOT
	_subject_generation[row] = EntityDirectory.NULL_GENERATION
	_material_container_slot[row] = EntityDirectory.NULL_SLOT
	_material_container_generation[row] = EntityDirectory.NULL_GENERATION
	_assigned_count[row] = 0
	_paused[row] = 0
	_remaining_mwu[row] = 0
	_paid_base_type[row] = NO_PAID_PACKAGE
	_paid_upgrade_mask[row] = 0
	for index: int in MATERIAL_SLOTS_PER_PROJECT:
		_delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index] = 0
	_live_count -= 1
	_directory.destroy(project_ref)


func begin_refund(project_ref: Vector2i) -> OpResult:
	"""REQ-SET-126: freeze a project for cancellation without freeing anything.

	PHASE_REFUNDING accepts no further delivery and no further work, so the manifest
	`cancellation_refund_milli_into()` reads cannot move under a caller that is placing lots.
	`close_refund()` is the second half; until it is called the project is exactly as it was.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	var owner_refusal: StringName = _owned_mutation_refusal(row, project_ref, ExcavationContract.ACTION_CANCEL)
	if owner_refusal != REFUSE_NONE:
		return _refuse(owner_refusal)
	if _phase[row] == PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	_phase[row] = PHASE_REFUNDING
	_assigned_count[row] = 0
	return OpResult.new(true, REFUSE_NONE, _refund_policy[row], project_ref)


func cancellation_refund_milli_into(project_ref: Vector2i, index: int,
		out: IntMath.IntResult) -> bool:
	"""REQ-SET-126's manifest line: 100% of delivered before work, 80% after, floored to milli-U.

	REFUSES a demolition project outright. ARCH-JOB-004 forbids an undifferentiated "refund all"
	helper, so the 50% demolition return is a separate function and cannot be reached from here.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	if is_removal(_purpose[row]):
		return out.refuse(REFUSE_IS_A_DEMOLITION)
	if index < 0 or index >= _project_bill_count(row):
		return out.refuse(REFUSE_MATERIAL_INDEX)
	var delivered: int = _delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index]
	if _refund_policy[row] == REFUND_FULL:
		@warning_ignore("integer_division") return out.succeed(delivered * REFUND_FULL_NUM / REFUND_FULL_DEN)
	if not IntMath.checked_mul_into(delivered, REFUND_PARTIAL_NUM, out):
		return out.refuse(REFUSE_OVERFLOW)
	return IntMath.floor_div_into(out.value, REFUND_PARTIAL_DEN, out)


func demolition_return_milli_into(project_ref: Vector2i, index: int,
		out: IntMath.IntResult) -> bool:
	"""One return-manifest line's milli-U: 50% of the item's ORIGINAL paid cost, floored.

	REFUSES anything but a demolition or a furniture removal. BUILD-C4-R01: a building's basis is
	the row's paid-ledger snapshot -- the base package plus each completed upgrade, totalled per
	item -- floored once per item. Each piece of furniture adds 50% of ITS OWN bill, floored once
	per item of that piece (DEMO-CONTAIN-R01's furniture rule; decision 0536). Never the delivered
	ledger, and never anything but the compiled bills under the rules hash.
	"""
	var row: int = _removal_row(project_ref, out)
	if row == NO_ROW:
		return false
	var count: int = _return_of_row(row)
	if index < 0 or index >= count:
		return out.refuse(REFUSE_MATERIAL_INDEX)
	return out.succeed(_return_milli[index])


func demolition_return_key_index_into(project_ref: Vector2i, index: int,
		out: IntMath.IntResult) -> bool:
	"""The MATERIAL_KEYS index of one return-manifest line. Refuses anything but a removal."""
	var row: int = _removal_row(project_ref, out)
	if row == NO_ROW:
		return false
	if index < 0 or index >= _return_of_row(row):
		return out.refuse(REFUSE_MATERIAL_INDEX)
	return out.succeed(_return_key[index])


func demolition_return_size_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""How many lines a removal's return manifest has. Refuses anything but a removal."""
	var row: int = _removal_row(project_ref, out)
	if row == NO_ROW:
		return false
	return out.succeed(_return_of_row(row))


func demolition_return_preview_into(building_ref: Vector2i, out_keys: PackedInt32Array,
		out_milli: PackedInt64Array, out: IntMath.IntResult) -> bool:
	"""The combined return a demolition admitted NOW would carry, already halved and floored.

	The building's type and tier exactly as `open_demolition()`'s snapshot will read them, plus
	every piece of furniture in its rooms now, so the coordinator can reserve output capacity for
	the whole return before its first write. `out.value` is the line count; both buffers must hold
	RETURN_LINE_CAPACITY cells. Writes nothing else.
	"""
	var type_result: Buildings.OpResult = _buildings.type_id_of_building(building_ref)
	if not type_result.ok:
		return out.refuse(REFUSE_STALE_BUILDING_REF)
	if not _return_buffers_fit(out_keys, out_milli):
		return out.refuse(REFUSE_MANIFEST_BUFFER)
	var count: int = _building_return(type_result.value, type_result.value,
		demolition_upgrade_mask_of(building_ref))
	return _copy_return_into(_add_furniture_returns(building_ref, count), out_keys, out_milli, out)


func furniture_removal_return_preview_into(furniture_ref: Vector2i, out_keys: PackedInt32Array,
		out_milli: PackedInt64Array, out: IntMath.IntResult) -> bool:
	"""The return one piece's removal admitted NOW would carry: 50% of its bill, floored per item."""
	var type_result: Buildings.OpResult = _buildings.type_id_of_furniture(furniture_ref)
	if not type_result.ok:
		return out.refuse(REFUSE_STALE_FURNITURE_REF)
	if not _return_buffers_fit(out_keys, out_milli):
		return out.refuse(REFUSE_MANIFEST_BUFFER)
	return _copy_return_into(_add_piece_return(type_result.value, 0), out_keys, out_milli, out)


func demolition_return_into(project_ref: Vector2i, out_keys: PackedInt32Array,
		out_milli: PackedInt64Array, out: IntMath.IntResult) -> bool:
	"""A removal's whole return manifest in one call: its snapshot, plus furniture, halved.

	The same lines `demolition_return_*_into()` read one at a time, for the coordinator's commit
	(decisions 0535, 0536); `out.value` is the line count. Refuses anything but a live removal and
	buffers under RETURN_LINE_CAPACITY cells. Writes nothing else.
	"""
	var row: int = _removal_row(project_ref, out)
	if row == NO_ROW:
		return false
	if not _return_buffers_fit(out_keys, out_milli):
		return out.refuse(REFUSE_MANIFEST_BUFFER)
	return _copy_return_into(_return_of_row(row), out_keys, out_milli, out)


func _return_buffers_fit(out_keys: PackedInt32Array, out_milli: PackedInt64Array) -> bool:
	"""Whether a caller's two manifest buffers each hold RETURN_LINE_CAPACITY cells."""
	return out_keys.size() >= RETURN_LINE_CAPACITY and out_milli.size() >= RETURN_LINE_CAPACITY


func _copy_return_into(count: int, out_keys: PackedInt32Array, out_milli: PackedInt64Array,
		out: IntMath.IntResult) -> bool:
	"""Copy the return scratch's first `count` lines out."""
	for index: int in count:
		out_keys[index] = _return_key[index]
		out_milli[index] = _return_milli[index]
	return out.succeed(count)


func paid_base_type_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""ConstructionPaidLedger `base_type`: the base package key, or NO_PAID_PACKAGE."""
	return _field_into(project_ref, _paid_base_type, out)


func paid_upgrade_mask_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""ConstructionPaidLedger `upgrade_mask`: the completed-upgrade bits this row recorded."""
	return _field_into(project_ref, _paid_upgrade_mask, out)


func _removal_row(project_ref: Vector2i, out: IntMath.IntResult) -> int:
	"""The live DEMOLITION or furniture-removal row behind a ref, or NO_ROW with `out` refused."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		out.refuse(REFUSE_STALE_PROJECT_REF)
		return NO_ROW
	if not is_removal(_purpose[row]):
		out.refuse(REFUSE_NOT_A_DEMOLITION)
		return NO_ROW
	return row


func _return_of_row(row: int) -> int:
	"""Fill the return scratch for one removal row; return its line count.

	A furniture removal returns its piece's own half (its paid base key is the piece's type). A
	demolition returns its snapshot's half plus every piece still in its building's rooms; once
	the building is gone (between #6's steps 4 and 6) it has no rooms, so only the snapshot.
	"""
	if _purpose[row] == PURPOSE_REMOVE_FURNITURE:
		return _add_piece_return(_paid_base_type[row], 0)
	var count: int = _building_return(_type_id[row], _paid_base_type[row], _paid_upgrade_mask[row])
	return _add_furniture_returns(Vector2i(_subject_slot[row], _subject_generation[row]), count)


func _building_return(type_id: int, paid_base: int, mask: int) -> int:
	"""The building's own half into the return scratch: base + upgrade per item, floored ONCE."""
	var count: int = _manifest_into(type_id, paid_base, mask)
	for line: int in count:
		_return_key[line] = _manifest_key[line]
		_return_milli[line] = _half(_manifest_milli[line])
	return count


func _add_furniture_returns(building_ref: Vector2i, count: int) -> int:
	"""Add every piece in a building's rooms to the return scratch, each piece floored on its own."""
	for room_row: int in _buildings.rooms_of_building(building_ref):
		for furniture_row: int in _buildings.furniture_rows_in_room(
				_buildings.room_ref_of_row(room_row)):
			var piece: Vector2i = _buildings.furniture_ref_of_row(furniture_row)
			count = _add_piece_return(_buildings.type_id_of_furniture(piece).value, count)
	return count


func _add_piece_return(furniture_type: int, count: int) -> int:
	"""Add one piece's 50% of its §4.3 bill, floored once per item of THAT piece.

	DEMO-CONTAIN-R01's furniture rule ("same rule as buildings"): the piece's package totalled per
	item, then floored once per item. Its package is DERIVED from its type -- Brendan's ruling on
	decision 0535's P1, R4's reading applied to furniture, starter pieces included (0536).
	"""
	var base: int = furniture_type * MATERIAL_SLOTS_PER_PROJECT
	for index: int in _furniture_count[furniture_type]:
		count = _add_return_line(_furniture_key[base + index],
			_half(_furniture_milli[base + index]), count)
	return count


func _add_return_line(key_index: int, milli: int, count: int) -> int:
	"""Add an already-halved quantity to its item's return line, opening a line for a new item."""
	for line: int in count:
		if _return_key[line] == key_index:
			_return_milli[line] += milli
			return count
	_return_key[count] = key_index
	_return_milli[count] = milli
	return count + 1


func _manifest_of_row(row: int) -> int:
	"""Fill the manifest scratch from one row's paid-ledger snapshot; return its line count."""
	return _manifest_into(_type_id[row], _paid_base_type[row], _paid_upgrade_mask[row])


func _manifest_into(type_id: int, paid_base: int, mask: int) -> int:
	"""Total each item's paid milli-U into the scratch, base package then completed upgrade.

	Lines are in first-appearance order: the base bill's own order, then any key only the
	upgrade names. `_assert_bills()` proves every union fits MATERIAL_SLOTS_PER_PROJECT lines.
	"""
	var count: int = 0
	var base: int = type_id * MATERIAL_SLOTS_PER_PROJECT
	if paid_base != NO_PAID_PACKAGE:
		for index: int in _build_count[type_id]:
			count = _add_manifest_line(_build_key[base + index], _build_milli[base + index], count)
	if mask & UPGRADE_TIER_TWO_BIT != 0:
		for index: int in _upgrade_count[type_id]:
			count = _add_manifest_line(_upgrade_key[base + index], _upgrade_milli[base + index],
				count)
	return count


func _add_manifest_line(key_index: int, milli: int, count: int) -> int:
	"""Add one package entry to its item's line, opening a new line for a new item.

	A plain sum: two authored int32 quantities cannot overflow int64.
	"""
	for line: int in count:
		if _manifest_key[line] == key_index:
			_manifest_milli[line] += milli
			return count
	_manifest_key[count] = key_index
	_manifest_milli[count] = milli
	return count + 1


static func _half(total_milli: int) -> int:
	"""REQ-SET-127's 50% of one item's total, floored to milli-U once.

	A plain floor: the operand is one or two authored int32 quantities, never negative, so the
	product by REFUND_DEMOLITION_NUM cannot overflow int64.
	"""
	@warning_ignore("integer_division") return total_milli * REFUND_DEMOLITION_NUM / REFUND_DEMOLITION_DEN


func close_refund(project_ref: Vector2i) -> OpResult:
	"""Retire a cancelled BUILD, UPGRADE or FURNITURE project once its refund has been placed.

	A cancelled BUILD project also removes the blueprint it was building: a cancelled blueprint is
	not a building. If that removal refuses -- a blueprint that somehow owns rooms -- the project
	stays in PHASE_REFUNDING with its ledger intact and the retry spends nothing. A demolition or
	a furniture removal is REFUSED by name, COORDINATOR_ONLY: its claim must be released first, and
	`close_demolition_refund()` is the coordinator's door (decision 0536).
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if is_removal(_purpose[row]) or _purpose[row] == PURPOSE_EXCAVATION or is_modular(_purpose[row]):
		return _refuse(REFUSE_COORDINATOR_ONLY)
	if _phase[row] != PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if _purpose[row] == PURPOSE_BUILD and _buildings.is_live_building(subject):
		_buildings.set_building_construction(subject, NULL_REF)
		var result: Buildings.OpResult = _buildings.demolish_building(subject)
		if not result.ok:
			_buildings.set_building_construction(subject, project_ref)
			return _refuse(result.error)
	_retire(row, project_ref, subject)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


# --- pause, workers and the material container ---------------------------------------------------

func set_paused(project_ref: Vector2i, paused: bool) -> OpResult:
	"""REQ-SET-137: retain delivered materials and progress, and release the assigned workers.

	Neither the delivered ledger nor `remaining_mwu` nor the phase moves. `assigned_count` drops
	to 0, which is this store's whole share of "release workers and unfinished ingredient leases";
	the leases themselves belong to `reservations.gd` and are not touched here.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	_paused[row] = 1 if paused else 0
	if paused:
		_assigned_count[row] = 0
	return OpResult.new(true, REFUSE_NONE, _paused[row], project_ref)


func set_assigned_count(project_ref: Vector2i, count: int) -> OpResult:
	"""Bind how many builders are working this project, capped by §5.9's `max_builders`."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if _paused[row] == 1:
		return _refuse(REFUSE_PAUSED)
	if _phase[row] == PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	if count < 0 or count > _max_workers[row]:
		return _refuse(REFUSE_INVALID_WORKERS)
	_assigned_count[row] = count
	return OpResult.new(true, REFUSE_NONE, count, project_ref)


func set_material_container(project_ref: Vector2i, container_ref: Vector2i) -> OpResult:
	"""Bind or clear §4.2's `material_container`. The null reference `(-1, 0)` clears it.

	INVENTORY CONTAINER NAMESPACE, not the directory's. This store holds no `inventory.gd`
	reference, so the pair is range-validated and nothing more; a store that CAN attest it must
	do so at the composition boundary. The four namespaces -- directory, inventory container,
	inventory lot, navigation route -- are distinct, and validating this one as a directory
	reference would accept a stale handle whose numbers happened to match.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	var owner_refusal: StringName = _owned_mutation_refusal(row, project_ref, ExcavationContract.ACTION_CONTAINER)
	if owner_refusal != REFUSE_NONE:
		return _refuse(owner_refusal)
	if container_ref != NULL_REF and (container_ref.x < 0 or container_ref.y <= 0
			or container_ref.x > INT32_MAX or container_ref.y > INT32_MAX):
		return _refuse(REFUSE_INVALID_CONTAINER_REF)
	_material_container_slot[row] = container_ref.x
	_material_container_generation[row] = container_ref.y
	return OpResult.new(true, REFUSE_NONE, container_ref.x, project_ref)


# --- accessors -----------------------------------------------------------------------------------

func _row_of(project_ref: Vector2i) -> int:
	"""The typed row a live project reference names, or NO_ROW. Internal; never returned raw."""
	if not _directory.is_valid_of_kind(project_ref, EntityDirectory.KIND_CONSTRUCTION):
		return NO_ROW
	var row: int = _directory.get_typed_row(project_ref)
	if row < 0 or row >= CONSTRUCTION_CAPACITY or _present[row] != 1:
		return NO_ROW
	if _ref_slot[row] != project_ref.x or _ref_generation[row] != project_ref.y:
		return NO_ROW
	return row


func _ref_of_row(row: int) -> Vector2i:
	"""The reference a live project row hands back, or the GDD null reference `(-1, 0)`."""
	if row < 0 or row >= CONSTRUCTION_CAPACITY or _present[row] != 1:
		return NULL_REF
	return Vector2i(_ref_slot[row], _ref_generation[row])


func is_live_project(project_ref: Vector2i) -> bool:
	"""True when this reference names a live project row of this store."""
	return _row_of(project_ref) != NO_ROW


func _field_into(project_ref: Vector2i, column: PackedInt32Array,
		out: IntMath.IntResult) -> bool:
	"""Read one int32 project column, refusing a stale reference instead of answering 0."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	return out.succeed(column[row])


func phase_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Where this project is in REQ-SET-124-127's sequence."""
	return _field_into(project_ref, _phase, out)


func purpose_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""What this project is for: build, upgrade, furniture or demolition."""
	return _field_into(project_ref, _purpose, out)


func type_id_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""The BuildingDefinition or FurnitureDefinition id this project prices against."""
	return _field_into(project_ref, _type_id, out)


func refund_policy_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""§4.2's `refund_policy`: which of REQ-SET-126/127's three fractions applies right now."""
	return _field_into(project_ref, _refund_policy, out)


func assigned_count_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""How many builders are bound to this project."""
	return _field_into(project_ref, _assigned_count, out)


func max_workers_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""§5.9's builder cap for this project."""
	return _field_into(project_ref, _max_workers, out)


func remaining_mwu_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""§4.2's `remaining_mwu`: the milli-WU still outstanding on this project."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	return out.succeed(_remaining_mwu[row])


func delivered_milli_into(project_ref: Vector2i, index: int, out: IntMath.IntResult) -> bool:
	"""How much of one bill line has been delivered. Refuses outside this project's bill."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	if index < 0 or index >= _project_bill_count(row):
		return out.refuse(REFUSE_MATERIAL_INDEX)
	return out.succeed(_delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index])


func is_paused(project_ref: Vector2i) -> bool:
	"""§4.2's `paused`. False for a stale reference, which is not a live paused project."""
	var row: int = _row_of(project_ref)
	return row != NO_ROW and _paused[row] == 1


func has_work_begun(project_ref: Vector2i) -> bool:
	"""Whether REQ-SET-125's consumption has happened, which is what moves 100% to 80%."""
	var row: int = _row_of(project_ref)
	return row != NO_ROW and _work_begun[row] == 1


func subject_ref_of(project_ref: Vector2i) -> Vector2i:
	"""The Building or Furniture this project acts on, or the null reference `(-1, 0)`."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return NULL_REF
	return Vector2i(_subject_slot[row], _subject_generation[row])


func material_container_ref_of(project_ref: Vector2i) -> Vector2i:
	"""§4.2's `material_container`, an INVENTORY CONTAINER reference, or `(-1, 0)`."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return NULL_REF
	return Vector2i(_material_container_slot[row], _material_container_generation[row])


func project_of_building(building_ref: Vector2i) -> Vector2i:
	"""The project acting on one building, read from `Building.construction`, or `(-1, 0)`."""
	var construction: Vector2i = _buildings.construction_ref_of_building(building_ref)
	return construction if is_live_project(construction) else NULL_REF


func project_of_subject(subject_ref: Vector2i) -> Vector2i:
	"""The live project acting on ANY subject -- a building OR a furniture row -- or `(-1, 0)`.

	`project_of_building()` reads the `Building.construction` link; furniture carries no such
	column, so the only way to ask the question for a bed is the subject scan below. A demolition
	gate must ask it for every furniture row it is about to destroy, because a furniture project
	can hold a material container full of delivered goods that belongs to nobody else.
	"""
	var row: int = _project_of_subject(subject_ref)
	return NULL_REF if row == NO_ROW else _ref_of_row(row)


func _project_of_subject(subject_ref: Vector2i) -> int:
	"""The row of the live project whose subject is this reference, or NO_ROW.

	A bounded scan, and deliberately so: a reverse index keyed by subject would be a second
	source of truth for a link `Building.construction` already carries, and furniture carries no
	such column at all. Placement is a cold path.
	"""
	var seen: int = 0
	for row: int in CONSTRUCTION_CAPACITY:
		if seen == _live_count:
			break
		if _present[row] != 1:
			continue
		seen += 1
		if _purpose[row] != PURPOSE_EXCAVATION and _purpose[row] != PURPOSE_SPOIL_TIP \
				and _purpose[row] != PURPOSE_CONNECTOR_INSTALL \
				and _subject_slot[row] == subject_ref.x and _subject_generation[row] == subject_ref.y:
			return row
	return NO_ROW


func live_project_count() -> int:
	"""How many construction projects are live."""
	return _live_count


# --- demolition gates and verification ------------------------------------------------------------

func occupant_count_of_building(building_ref: Vector2i) -> int:
	"""REQ-SET-128's resident half: how many occupants this building's rooms still report.

	PUBLIC so the composed demolition gate rechecks this exact count -- from these exact rows --
	after it has proved its endpoint set, instead of carrying a stale number or a second rule.
	"""
	var total: int = 0
	for room_row: int in _buildings.rooms_of_building(building_ref):
		var room_ref: Vector2i = _buildings.room_ref_of_row(room_row)
		var result: Buildings.OpResult = _buildings.occupants_of_room(room_ref)
		if result.ok:
			total += result.value
	return total


func furniture_user_count_of_building(building_ref: Vector2i) -> int:
	"""REQ-SET-128's resident half again: furniture still bound to a live user blocks demolition.

	PUBLIC for the same reason as `occupant_count_of_building()`.
	"""
	var total: int = 0
	for room_row: int in _buildings.rooms_of_building(building_ref):
		var room_ref: Vector2i = _buildings.room_ref_of_row(room_row)
		for furniture_row: int in _buildings.furniture_rows_in_room(room_ref):
			var furniture: Vector2i = _buildings.furniture_ref_of_row(furniture_row)
			if _buildings.user_ref_of_furniture(furniture) != NULL_REF:
				total += 1
	return total


func _subject_is_live(row: int, subject: Vector2i) -> bool:
	"""Whether this project's subject still exists in the store that owns it."""
	if is_modular(_purpose[row]):
		return _read_modular_facts(row) == REFUSE_NONE
	if _purpose[row] == PURPOSE_EXCAVATION:
		var authority: ExcavationContract = excavation_authority()
		return authority != null and authority.is_live_site(subject)
	if is_furniture_subject(_purpose[row]):
		return _buildings.is_live_furniture(subject)
	return _buildings.is_live_building(subject)


static func is_furniture_subject(purpose: int) -> bool:
	"""Whether a purpose's subject is a Furniture row (FURNITURE, REMOVE_FURNITURE) not a Building."""
	return purpose == PURPOSE_FURNITURE or purpose == PURPOSE_REMOVE_FURNITURE or purpose == PURPOSE_SPATIAL_FURNITURE


static func is_removal(purpose: int) -> bool:
	"""Whether a purpose takes something down: a building demolition or a furniture removal.

	Both return 50% of a paid package (REFUND_DEMOLITION), deliver nothing, and complete and are
	cancelled only through the coordinator (decision 0536, REFUSE_COORDINATOR_ONLY).
	"""
	return purpose == PURPOSE_DEMOLISH or purpose == PURPOSE_REMOVE_FURNITURE


func verify_refund_policies() -> OpResult:
	"""Recompute §4.2's `refund_policy` for every live row and REFUSE a disagreement.

	The load-time comparison a decoder owes this column, on `buildings.verify_room_masks()`'s
	precedent. Unreachable through this store's own API -- the policy is written only by the
	recomputation this check runs -- so only a decoder writing policies straight from a file can
	produce one. It is repaired by refusing, never silently.
	"""
	for row: int in CONSTRUCTION_CAPACITY:
		if _present[row] != 1:
			continue
		if _refund_policy[row] != _policy_for(_purpose[row], _work_begun[row]):
			return OpResult.new(false, REFUSE_POLICY_MISMATCH, row, _ref_of_row(row))
	return OpResult.new(true, REFUSE_NONE, _live_count, NULL_REF)


func state_bytes() -> PackedByteArray:
	"""Exact serialization of all authoritative state, for byte-identical refusal checks.

	NOT A PRODUCTION CALL. It builds a fresh buffer holding every column at its FULL allocated
	length -- roughly 5 MB at spec capacity -- so two images can be compared byte for byte. The
	immutable bill columns are excluded: they are compiled catalog data that no operation writes.
	"""
	var out: PackedByteArray = PackedByteArray()
	out.append_array(var_to_bytes(_material_container_slot))
	out.append_array(var_to_bytes(_material_container_generation))
	out.append_array(var_to_bytes(_assigned_count))
	out.append_array(var_to_bytes(_max_workers))
	out.append_array(var_to_bytes(_refund_policy))
	out.append_array(var_to_bytes(_remaining_mwu))
	out.append_array(var_to_bytes(_paused))
	out.append_array(var_to_bytes(_present))
	out.append_array(var_to_bytes(_work_begun))
	out.append_array(var_to_bytes(_ref_slot))
	out.append_array(var_to_bytes(_ref_generation))
	out.append_array(var_to_bytes(_subject_slot))
	out.append_array(var_to_bytes(_subject_generation))
	out.append_array(var_to_bytes(_purpose))
	out.append_array(var_to_bytes(_type_id))
	out.append_array(var_to_bytes(_phase))
	out.append_array(var_to_bytes(_delivered_milli))
	out.append_array(var_to_bytes(_paid_base_type))
	out.append_array(var_to_bytes(_paid_upgrade_mask))
	out.append_array(var_to_bytes(PackedInt64Array([_live_count])))
	return out


func _refuse(code: StringName) -> OpResult:
	"""One refused outcome: no value, the null reference, and the code that explains it."""
	return OpResult.new(false, code, 0, NULL_REF)

# =================================================================================================
# CONSTRUCTION-S4-VALIDATE-R01v2 (ADR 0186): bounded local Columns validation surface.
#
# APPEND-ONLY. Everything below this line is additive: a cold `Columns` row-family image, its
# independent safe source preflight, and the ordered pure `columns_refusal()` predicate the
# accepted contract (docs/planning/construction_component_validation_contract.md) and its witness
# manifest (witness-plan-v2.json) describe. No schema, lifecycle, gameplay behavior, packed-state
# budget or existing declaration above this line is touched. This is LOCAL validation only: it
# proves one Columns image is internally well-formed against the eleven ordered gates below. It
# proves nothing about saved identity, delivered materials, capture/apply or a loaded world
# (section "Saved coverage and integration boundary"), and constructs no live Construction,
# Buildings, Directory or BuildingDefinitions instance anywhere in this section.
# =================================================================================================

## The eleven frozen refusal codes this section may return, plus success (REFUSE_NONE, above).
const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSE_COLUMN_SOURCE_METADATA: StringName = &"COLUMN_SOURCE_METADATA"
const REFUSE_COLUMN_FLAG: StringName = &"COLUMN_FLAG"
const REFUSE_COLUMN_ENUM: StringName = &"COLUMN_ENUM"
const REFUSE_COLUMN_VALUE: StringName = &"COLUMN_VALUE"
const REFUSE_COLUMN_REF: StringName = &"COLUMN_REF"
const REFUSE_COLUMN_FREE: StringName = &"COLUMN_FREE"
const REFUSE_COLUMN_TYPE: StringName = &"COLUMN_TYPE"
const REFUSE_COLUMN_WORKERS: StringName = &"COLUMN_WORKERS"
const REFUSE_COLUMN_POLICY: StringName = &"COLUMN_POLICY"
const REFUSE_COLUMN_PHASE: StringName = &"COLUMN_PHASE"

## The Directory namespace's own capacity, read as a constant (no directory instance needed).
const COLUMN_DIRECTORY_CAPACITY: int = EntityDirectory.DIRECTORY_CAPACITY

## R01v2 FROZEN SOURCE SCALARS. Independent literal anchors for every scalar, ordinal, index
## constant, capacity and material key the gate arrays and the fact/bill scans below consume.
## `_source_scalar_refusal()` compares each one with the live source constant of the same meaning
## BEFORE any dictionary, fact row, index constant or gate array is read, so a source edit refuses
## with COLUMN_SOURCE_METADATA instead of being silently reinterpreted or used as an unchecked
## index. No new game value is assigned here and no existing declaration is moved or changed.
const SOURCE_ROW_CAPACITY: int = 82944
const SOURCE_MATERIAL_SLOTS_PER_PROJECT: int = 4
const SOURCE_MAX_BUILDERS: int = 4
const SOURCE_DEMOLITION_WORK_NUM: int = 1
const SOURCE_DEMOLITION_WORK_DEN: int = 4
const SOURCE_INT32_MAX: int = 2147483647
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0
const SOURCE_DIRECTORY_CAPACITY: int = 352418
const SOURCE_PURPOSE_BUILD: int = 0
const SOURCE_PURPOSE_UPGRADE: int = 1
const SOURCE_PURPOSE_FURNITURE: int = 2
const SOURCE_PURPOSE_DEMOLISH: int = 3
const SOURCE_PURPOSE_COUNT: int = 4
const SOURCE_PHASE_AWAITING_MATERIALS: int = 0
const SOURCE_PHASE_READY: int = 1
const SOURCE_PHASE_WORKING: int = 2
const SOURCE_PHASE_WORK_DONE: int = 3
const SOURCE_PHASE_REFUNDING: int = 4
const SOURCE_PHASE_COUNT: int = 5
const SOURCE_REFUND_FULL: int = 0
const SOURCE_REFUND_PARTIAL: int = 1
const SOURCE_REFUND_DEMOLITION: int = 2
const SOURCE_REFUND_POLICY_COUNT: int = 3
const SOURCE_BUILDING_KIND_COUNT: int = 30
const SOURCE_FURNITURE_KIND_COUNT: int = 9
const SOURCE_TIER_TWO_COUNT: int = 4
const SOURCE_B_WORK_MWU: int = 2
const SOURCE_B_MAX_BUILDERS: int = 9
const SOURCE_B_FIELD_COUNT: int = 10
const SOURCE_F_WORK_MWU: int = 2
const SOURCE_F_FIELD_COUNT: int = 4
const SOURCE_MATERIAL_KEY_COUNT: int = 6
const SOURCE_MATERIAL_KEYS: Array[String] = [
	"wood", "stone", "cloth", "iron", "rope", "wax",
]
const SOURCE_TIER_TWO_KEYS: Array[String] = [
	"covered_store", "hall", "residence", "workshop",
]

## Frozen gate-consumed arrays, transcribed exactly from frozen-source-facts.json in the same
## canonical ascending id order Catalog.BUILDING_DEFINITION / Catalog.FURNITURE_DEFINITION assign
## (both already alphabetical in this project). These are gate facts for the PURE predicate only;
## exact bill quantity/order mirrors belong to the later bridge's independent SOURCE_* anchors.
const COLUMN_BUILDING_KEYS: Array[String] = [
	"apiary", "boathouse", "brewery", "cellar", "composter", "covered_store",
	"dirt_path", "dryer", "fence", "fisher_shelter", "forester_lodge", "gate",
	"hall", "infirmary", "kitchen", "lookout", "memorial_garden", "mill",
	"nursery", "open_stockpile", "paved_path", "preserver", "quarry_shed", "residence",
	"saltpan", "stone_wall", "weir", "well", "workbench", "workshop",
]
const COLUMN_BUILDING_WORK_MWU: Array[int] = [
	180000, 720000, 480000, 900000, 120000, 480000,
	2000, 240000, 12000, 240000, 240000, 90000,
	2400000, 1000000, 600000, 180000, 240000, 720000,
	300000, 60000, 6000, 480000, 240000, 1200000,
	240000, 30000, 480000, 240000, 180000, 720000,
]
const COLUMN_BUILDING_MAX_WORKERS: Array[int] = [
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
]
const COLUMN_BUILDING_BILL_PAIR_COUNTS: Array[int] = [
	2, 3, 3, 2, 1, 2,
	0, 2, 1, 2, 2, 2,
	3, 3, 3, 2, 2, 2,
	2, 1, 1, 3, 2, 3,
	2, 1, 3, 2, 2, 3,
]
const COLUMN_FURNITURE_KEYS: Array[String] = [
	"bed", "decoration", "hearth", "interior_door", "interior_partition",
	"kitchen_bench", "patient_bed", "seat", "shelf",
]
const COLUMN_FURNITURE_WORK_MWU: Array[int] = [
	20000, 12000, 60000, 12000, 8000, 60000, 24000, 10000, 16000,
]
const COLUMN_FURNITURE_BILL_PAIR_COUNTS: Array[int] = [
	2, 2, 1, 1, 1, 3, 2, 1, 1,
]

## The four tier-2 keys in canonical BuildingDefinition id order (5, 12, 23, 29): covered_store,
## hall, residence, workshop, matching BuildingDefinitions.TIER_TWO_KEYS' own order.
const COLUMN_UPGRADE_IDS: Array[int] = [5, 12, 23, 29]
const COLUMN_UPGRADE_WORK_MWU: Array[int] = [600000, 1200000, 1200000, 720000]
const COLUMN_UPGRADE_BILL_PAIR_COUNTS: Array[int] = [2, 3, 3, 2]


class Columns extends RefCounted:
	"""The cold 16-column Construction owner image (contract "Exact public surface").

	Sixteen typed packed properties, named by removing the schema key's leading underscore, in the
	exact ordinal order the owning contract table fixes. `_init(true)` (the default) allocates the
	CLEAR image: every property resized to ROW_CAPACITY and filled with its declared clear value.
	`_init(false)` is the borrowed-view constructor: every property stays an empty typed array, for
	a caller (this file's static preflight, or a future bridge) to assign shaped buffers into.
	This class performs no validation, no allocation beyond its own properties, no live read, no
	diagnostics and no serialized copy; `columns_refusal()` below is the sole pure predicate over it.
	"""

	## Self-contained row count; deliberately a literal so this class never needs to resolve an
	## outer-scope constant to know its own shape (contract owner1 primary 82944).
	const ROW_CAPACITY: int = 82944

	var present: PackedByteArray = PackedByteArray()
	var material_container_slot: PackedInt32Array = PackedInt32Array()
	var material_container_generation: PackedInt32Array = PackedInt32Array()
	var assigned_count: PackedInt32Array = PackedInt32Array()
	var max_workers: PackedInt32Array = PackedInt32Array()
	var refund_policy: PackedInt32Array = PackedInt32Array()
	var remaining_mwu: PackedInt64Array = PackedInt64Array()
	var paused: PackedByteArray = PackedByteArray()
	var work_begun: PackedByteArray = PackedByteArray()
	var ref_slot: PackedInt32Array = PackedInt32Array()
	var ref_generation: PackedInt32Array = PackedInt32Array()
	var subject_slot: PackedInt32Array = PackedInt32Array()
	var subject_generation: PackedInt32Array = PackedInt32Array()
	var purpose: PackedInt32Array = PackedInt32Array()
	var type_id: PackedInt32Array = PackedInt32Array()
	var phase: PackedInt32Array = PackedInt32Array()

	func _init(allocate_defaults: bool = true) -> void:
		"""`true` (default): allocate the clear image. `false`: leave every property empty."""
		if not allocate_defaults:
			return
		_resize_columns()
		_fill_clear_values()

	func _resize_columns() -> void:
		"""Resize all sixteen properties to ROW_CAPACITY; a borrowed view never reaches it."""
		present.resize(ROW_CAPACITY)
		material_container_slot.resize(ROW_CAPACITY)
		material_container_generation.resize(ROW_CAPACITY)
		assigned_count.resize(ROW_CAPACITY)
		max_workers.resize(ROW_CAPACITY)
		refund_policy.resize(ROW_CAPACITY)
		remaining_mwu.resize(ROW_CAPACITY)
		paused.resize(ROW_CAPACITY)
		work_begun.resize(ROW_CAPACITY)
		ref_slot.resize(ROW_CAPACITY)
		ref_generation.resize(ROW_CAPACITY)
		subject_slot.resize(ROW_CAPACITY)
		subject_generation.resize(ROW_CAPACITY)
		purpose.resize(ROW_CAPACITY)
		type_id.resize(ROW_CAPACITY)
		phase.resize(ROW_CAPACITY)

	func _fill_clear_values() -> void:
		"""Fill each resized property with its declared clear value, in ordinal order."""
		present.fill(0)
		material_container_slot.fill(-1)
		material_container_generation.fill(0)
		assigned_count.fill(0)
		max_workers.fill(0)
		refund_policy.fill(0)
		remaining_mwu.fill(0)
		paused.fill(0)
		work_begun.fill(0)
		ref_slot.fill(-1)
		ref_generation.fill(0)
		subject_slot.fill(-1)
		subject_generation.fill(0)
		purpose.fill(0)
		type_id.fill(-1)
		phase.fill(0)

	func is_sized() -> bool:
		"""True only when all sixteen properties are exactly ROW_CAPACITY long."""
		return present.size() == ROW_CAPACITY \
			and material_container_slot.size() == ROW_CAPACITY \
			and material_container_generation.size() == ROW_CAPACITY \
			and assigned_count.size() == ROW_CAPACITY \
			and max_workers.size() == ROW_CAPACITY \
			and refund_policy.size() == ROW_CAPACITY \
			and remaining_mwu.size() == ROW_CAPACITY \
			and paused.size() == ROW_CAPACITY \
			and work_begun.size() == ROW_CAPACITY \
			and ref_slot.size() == ROW_CAPACITY \
			and ref_generation.size() == ROW_CAPACITY \
			and subject_slot.size() == ROW_CAPACITY \
			and subject_generation.size() == ROW_CAPACITY \
			and purpose.size() == ROW_CAPACITY \
			and type_id.size() == ROW_CAPACITY \
			and phase.size() == ROW_CAPACITY


# --- independent safe source preflight -----------------------------------------------------------

static func _bill_shape_ok(bill: Variant, expected_pairs: int) -> bool:
	"""A compiled bill Array: TYPE_ARRAY, even length, bounded/matched pair count, typed contents.

	Order matches the contract exactly: TYPE_ARRAY, then even length, then pair count 0..4, then
	each key's exact TYPE_STRING before any StringName(key) membership test, then each quantity's
	actual integer type and positive value. Bounds and type proof always precede indexing.
	"""
	if typeof(bill) != TYPE_ARRAY:
		return false
	var pairs: Array = bill
	if pairs.size() % 2 != 0:
		return false
	@warning_ignore("integer_division") var pair_count: int = pairs.size() / 2
	if pair_count < 0 or pair_count > MATERIAL_SLOTS_PER_PROJECT or pair_count != expected_pairs:
		return false
	for index: int in pair_count:
		if typeof(pairs[index * 2]) != TYPE_STRING:
			return false
		if not MATERIAL_KEYS.has(StringName(String(pairs[index * 2]))):
			return false
		if typeof(pairs[index * 2 + 1]) != TYPE_INT:
			return false
		if int(pairs[index * 2 + 1]) <= 0:
			return false
	return true


static func _fact_row_scalars_typed(fields: Array, expected_count: int) -> bool:
	"""Exact extent, then EVERY scalar of one immutable fact row is an actual TYPE_INT.

	Shared by both owner fact-row helpers. Extent is proven first, then each of the row's
	scalars -- not only the gate-consumed work/max-builder indices -- must be an actual
	integer before any field is interpreted. Types only: no coercion, no value comparison
	against a numeric mirror, no new dictionary, packed buffer, domain or gate.
	"""
	if fields.size() != expected_count:
		return false
	for index: int in expected_count:
		if typeof(fields[index]) != TYPE_INT:
			return false
	return true


static func _metadata_refusal_building(id: int, key: String) -> bool:
	"""True when one BuildingDefinition id/key pair fails the frozen source comparison."""
	if not Catalog.BUILDING_DEFINITION.has(key) or typeof(Catalog.BUILDING_DEFINITION[key]) != TYPE_INT:
		return true
	if int(Catalog.BUILDING_DEFINITION[key]) != id:
		return true
	if not BuildingDefinitions.BUILDING_FACTS.has(key):
		return true
	var row: Variant = BuildingDefinitions.BUILDING_FACTS[key]
	if typeof(row) != TYPE_ARRAY:
		return true
	var fields: Array = row
	if not _fact_row_scalars_typed(fields, BuildingDefinitions.B_FIELD_COUNT):
		return true
	if typeof(fields[BuildingDefinitions.B_WORK_MWU]) != TYPE_INT \
			or int(fields[BuildingDefinitions.B_WORK_MWU]) != COLUMN_BUILDING_WORK_MWU[id]:
		return true
	if typeof(fields[BuildingDefinitions.B_MAX_BUILDERS]) != TYPE_INT \
			or int(fields[BuildingDefinitions.B_MAX_BUILDERS]) != COLUMN_BUILDING_MAX_WORKERS[id]:
		return true
	if COLUMN_BUILDING_WORK_MWU[id] <= 0 or COLUMN_BUILDING_WORK_MWU[id] % DEMOLITION_WORK_DEN != 0:
		return true
	if not BUILD_MATERIALS.has(key):
		return true
	return not _bill_shape_ok(BUILD_MATERIALS[key], COLUMN_BUILDING_BILL_PAIR_COUNTS[id])


static func _metadata_refusal_furniture(id: int, key: String) -> bool:
	"""True when one FurnitureDefinition id/key pair fails the frozen source comparison."""
	if not Catalog.FURNITURE_DEFINITION.has(key) or typeof(Catalog.FURNITURE_DEFINITION[key]) != TYPE_INT:
		return true
	if int(Catalog.FURNITURE_DEFINITION[key]) != id:
		return true
	if not BuildingDefinitions.FURNITURE_FACTS.has(key):
		return true
	var row: Variant = BuildingDefinitions.FURNITURE_FACTS[key]
	if typeof(row) != TYPE_ARRAY:
		return true
	var fields: Array = row
	if not _fact_row_scalars_typed(fields, BuildingDefinitions.F_FIELD_COUNT):
		return true
	if typeof(fields[BuildingDefinitions.F_WORK_MWU]) != TYPE_INT \
			or int(fields[BuildingDefinitions.F_WORK_MWU]) != COLUMN_FURNITURE_WORK_MWU[id]:
		return true
	if COLUMN_FURNITURE_WORK_MWU[id] <= 0:
		return true
	if not FURNITURE_MATERIALS.has(key):
		return true
	return not _bill_shape_ok(FURNITURE_MATERIALS[key], COLUMN_FURNITURE_BILL_PAIR_COUNTS[id])


static func _metadata_refusal_upgrade(index: int, id: int) -> bool:
	"""True when one tier-2 upgrade index/id pair fails the frozen source comparison."""
	if index < 0 or index >= BuildingDefinitions.TIER_TWO_KEYS.size():
		return true
	var key: String = BuildingDefinitions.TIER_TWO_KEYS[index]
	if not Catalog.BUILDING_DEFINITION.has(key) or typeof(Catalog.BUILDING_DEFINITION[key]) != TYPE_INT:
		return true
	if int(Catalog.BUILDING_DEFINITION[key]) != id:
		return true
	if not UPGRADE_WORK_MWU.has(key) or typeof(UPGRADE_WORK_MWU[key]) != TYPE_INT:
		return true
	if int(UPGRADE_WORK_MWU[key]) != COLUMN_UPGRADE_WORK_MWU[index] or int(UPGRADE_WORK_MWU[key]) <= 0:
		return true
	if not UPGRADE_MATERIALS.has(key):
		return true
	return not _bill_shape_ok(UPGRADE_MATERIALS[key], COLUMN_UPGRADE_BILL_PAIR_COUNTS[index])


static func _source_capacity_scalars_ok() -> bool:
	"""Pin capacity, stride, builder cap, demolition ratio and reference scalars.

	Each is consumed by a gate or by the bill scan below, so each is compared with its frozen
	literal before any dictionary is read or any fact row is indexed.
	"""
	if CONSTRUCTION_CAPACITY != SOURCE_ROW_CAPACITY or Columns.ROW_CAPACITY != SOURCE_ROW_CAPACITY:
		return false
	if MATERIAL_SLOTS_PER_PROJECT != SOURCE_MATERIAL_SLOTS_PER_PROJECT:
		return false
	if MAX_BUILDERS != SOURCE_MAX_BUILDERS:
		return false
	if DEMOLITION_WORK_NUM != SOURCE_DEMOLITION_WORK_NUM:
		return false
	if DEMOLITION_WORK_DEN != SOURCE_DEMOLITION_WORK_DEN or SOURCE_DEMOLITION_WORK_DEN <= 0:
		return false
	if INT32_MAX != SOURCE_INT32_MAX:
		return false
	if NULL_REF.x != SOURCE_NULL_SLOT or NULL_REF.y != SOURCE_NULL_GENERATION:
		return false
	if COLUMN_DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY or SOURCE_DIRECTORY_CAPACITY <= 0:
		return false
	return true


static func _source_enum_scalars_ok() -> bool:
	"""Pin every purpose, phase and refund ordinal and count the gates compare against."""
	if PURPOSE_BUILD != SOURCE_PURPOSE_BUILD or PURPOSE_UPGRADE != SOURCE_PURPOSE_UPGRADE:
		return false
	if PURPOSE_FURNITURE != SOURCE_PURPOSE_FURNITURE \
			or PURPOSE_DEMOLISH != SOURCE_PURPOSE_DEMOLISH or PURPOSE_COUNT != SOURCE_PURPOSE_COUNT:
		return false
	if PHASE_AWAITING_MATERIALS != SOURCE_PHASE_AWAITING_MATERIALS \
			or PHASE_READY != SOURCE_PHASE_READY or PHASE_WORKING != SOURCE_PHASE_WORKING:
		return false
	if PHASE_WORK_DONE != SOURCE_PHASE_WORK_DONE or PHASE_REFUNDING != SOURCE_PHASE_REFUNDING \
			or PHASE_COUNT != SOURCE_PHASE_COUNT:
		return false
	if REFUND_FULL != SOURCE_REFUND_FULL or REFUND_PARTIAL != SOURCE_REFUND_PARTIAL:
		return false
	if REFUND_DEMOLITION != SOURCE_REFUND_DEMOLITION \
			or REFUND_POLICY_COUNT != SOURCE_REFUND_POLICY_COUNT:
		return false
	return true


static func _source_domain_scalars_ok() -> bool:
	"""Pin both domain counts and every fact-row index constant BEFORE a row is indexed."""
	if BUILDING_KINDS != SOURCE_BUILDING_KIND_COUNT \
			or BuildingDefinitions.BUILDING_DEFINITION_COUNT != SOURCE_BUILDING_KIND_COUNT:
		return false
	if FURNITURE_KINDS != SOURCE_FURNITURE_KIND_COUNT \
			or BuildingDefinitions.FURNITURE_DEFINITION_COUNT != SOURCE_FURNITURE_KIND_COUNT:
		return false
	if BuildingDefinitions.B_FIELD_COUNT != SOURCE_B_FIELD_COUNT \
			or BuildingDefinitions.F_FIELD_COUNT != SOURCE_F_FIELD_COUNT:
		return false
	if BuildingDefinitions.B_WORK_MWU != SOURCE_B_WORK_MWU \
			or BuildingDefinitions.B_MAX_BUILDERS != SOURCE_B_MAX_BUILDERS \
			or BuildingDefinitions.F_WORK_MWU != SOURCE_F_WORK_MWU:
		return false
	if SOURCE_B_WORK_MWU < 0 or SOURCE_B_WORK_MWU >= SOURCE_B_FIELD_COUNT:
		return false
	if SOURCE_B_MAX_BUILDERS < 0 or SOURCE_B_MAX_BUILDERS >= SOURCE_B_FIELD_COUNT:
		return false
	if SOURCE_F_WORK_MWU < 0 or SOURCE_F_WORK_MWU >= SOURCE_F_FIELD_COUNT:
		return false
	return true


static func _source_key_scalars_ok() -> bool:
	"""Pin the six material keys in order and the four tier-two keys the upgrade scan walks."""
	if MATERIAL_KEY_COUNT != SOURCE_MATERIAL_KEY_COUNT \
			or MATERIAL_KEYS.size() != SOURCE_MATERIAL_KEY_COUNT \
			or SOURCE_MATERIAL_KEYS.size() != SOURCE_MATERIAL_KEY_COUNT:
		return false
	for index: int in SOURCE_MATERIAL_KEY_COUNT:
		if MATERIAL_KEYS[index] != StringName(SOURCE_MATERIAL_KEYS[index]):
			return false
	if SOURCE_TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_COUNT \
			or BuildingDefinitions.TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_COUNT:
		return false
	for index: int in SOURCE_TIER_TWO_COUNT:
		if BuildingDefinitions.TIER_TWO_KEYS[index] != SOURCE_TIER_TWO_KEYS[index]:
			return false
	return true


static func _source_scalar_refusal() -> StringName:
	"""Every pinned scalar, ordinal, index constant and key sequence, before any source read.

	Returns REFUSE_COLUMN_SOURCE_METADATA on the first disagreement, REFUSE_NONE otherwise. This
	is a guard, not a second bill-quantity oracle: exact authored quantities and their order stay
	the later bridge's independent SOURCE_* anchor (contract "Immutable facts and safe source
	preflight"), and nothing here reads a Columns image or any live state.
	"""
	if not _source_capacity_scalars_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	if not _source_enum_scalars_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	if not _source_domain_scalars_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	if not _source_key_scalars_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	return REFUSE_NONE


static func column_source_metadata_refusal() -> StringName:
	"""Independent safe source preflight (contract "Immutable facts and safe source preflight").

	Compares the frozen COLUMN_* gate arrays against BuildingDefinitions' and this file's own
	static catalog Dictionaries -- never constructing a live Definitions/Buildings/Construction
	instance, and never calling Catalog.compile_domain or verify_compiled_enum. Every shape/type
	bound is proven before it is used to index. Protects itself independently of any caller;
	`columns_refusal()` does not assume this already ran. Returns REFUSE_NONE on success.
	"""
	var scalar_code: StringName = _source_scalar_refusal()
	if scalar_code != REFUSE_NONE:
		return scalar_code
	if not _gate_array_extents_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	if not _source_dictionary_extents_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	if not _source_stored_key_types_ok():
		return REFUSE_COLUMN_SOURCE_METADATA
	return _source_row_scan_refusal()


static func _gate_array_extents_ok() -> bool:
	"""Exact extents of the ten frozen gate-consumed arrays, before any one of them is indexed."""
	if COLUMN_BUILDING_KEYS.size() != BUILDING_KINDS or COLUMN_BUILDING_WORK_MWU.size() != BUILDING_KINDS \
			or COLUMN_BUILDING_MAX_WORKERS.size() != BUILDING_KINDS \
			or COLUMN_BUILDING_BILL_PAIR_COUNTS.size() != BUILDING_KINDS:
		return false
	if COLUMN_FURNITURE_KEYS.size() != FURNITURE_KINDS or COLUMN_FURNITURE_WORK_MWU.size() != FURNITURE_KINDS \
			or COLUMN_FURNITURE_BILL_PAIR_COUNTS.size() != FURNITURE_KINDS:
		return false
	if COLUMN_UPGRADE_IDS.size() != 4 or COLUMN_UPGRADE_WORK_MWU.size() != 4 \
			or COLUMN_UPGRADE_BILL_PAIR_COUNTS.size() != 4:
		return false
	return true


static func _source_dictionary_extents_ok() -> bool:
	"""Exact key counts of every catalog, fact and bill Dictionary the row scan below walks."""
	if Catalog.BUILDING_DEFINITION.size() != BUILDING_KINDS or BuildingDefinitions.BUILDING_FACTS.size() != BUILDING_KINDS \
			or BUILD_MATERIALS.size() != BUILDING_KINDS:
		return false
	if Catalog.FURNITURE_DEFINITION.size() != FURNITURE_KINDS or BuildingDefinitions.FURNITURE_FACTS.size() != FURNITURE_KINDS \
			or FURNITURE_MATERIALS.size() != FURNITURE_KINDS:
		return false
	if UPGRADE_MATERIALS.size() != 4 or UPGRADE_WORK_MWU.size() != 4:
		return false
	return true


static func _stored_keys_are_exact_strings(source: Dictionary) -> bool:
	"""Every ACTUAL stored key of one source dictionary is exact TYPE_STRING.

	Godot aliases String and StringName in dictionary lookup, so `.has(frozen_string)` cannot
	observe a stored-key type change: the four mutations in dictionary-key-types-a1/result.json
	executed cleanly and evaded COLUMN_SOURCE_METADATA. Only inspecting the stored keys
	themselves can see it. Cold and read-only, bounded by the already-pinned key count, with no
	coercion, no new packed buffer, no live read and no canonical ID/value check replaced.
	"""
	for key: Variant in source.keys():
		if typeof(key) != TYPE_STRING:
			return false
	return true


static func _source_stored_key_types_ok() -> bool:
	"""The eight source dictionaries the canonical ID walk then looks keys up in.

	Runs after the extent pins and BEFORE `_source_row_scan_refusal()`, so the ID/value walk
	still proves every ordinal, work, max-worker and bill shape exactly as before; this only
	removes the aliasing blind spot ahead of it. Independent review closure extends the same
	guard to the four bill/work dictionaries the row and upgrade scans look keys up in --
	BUILD_MATERIALS, FURNITURE_MATERIALS, UPGRADE_MATERIALS and UPGRADE_WORK_MWU -- which
	alias identically. Bill ELEMENT key types stay separate, in `_bill_shape_ok()`. No
	gate-consumed value scope changes.
	"""
	if not _stored_keys_are_exact_strings(Catalog.BUILDING_DEFINITION):
		return false
	if not _stored_keys_are_exact_strings(Catalog.FURNITURE_DEFINITION):
		return false
	if not _stored_keys_are_exact_strings(BuildingDefinitions.BUILDING_FACTS):
		return false
	if not _stored_keys_are_exact_strings(BuildingDefinitions.FURNITURE_FACTS):
		return false
	if not _stored_keys_are_exact_strings(BUILD_MATERIALS):
		return false
	if not _stored_keys_are_exact_strings(FURNITURE_MATERIALS):
		return false
	if not _stored_keys_are_exact_strings(UPGRADE_MATERIALS):
		return false
	return _stored_keys_are_exact_strings(UPGRADE_WORK_MWU)


static func _source_row_scan_refusal() -> StringName:
	"""Both domains in canonical id order, then the four tier-two upgrade indexes."""
	for id: int in BUILDING_KINDS:
		if _metadata_refusal_building(id, COLUMN_BUILDING_KEYS[id]):
			return REFUSE_COLUMN_SOURCE_METADATA
	for id: int in FURNITURE_KINDS:
		if _metadata_refusal_furniture(id, COLUMN_FURNITURE_KEYS[id]):
			return REFUSE_COLUMN_SOURCE_METADATA
	for index: int in 4:
		if _metadata_refusal_upgrade(index, COLUMN_UPGRADE_IDS[index]):
			return REFUSE_COLUMN_SOURCE_METADATA
	return REFUSE_NONE


# --- the ordered pure row predicate ---------------------------------------------------------------

static func _column_flag_scan_refusal(image: Columns) -> StringName:
	"""Scan present, paused, work_begun -- that exact order, each in full -- for canonical 0/1."""
	for value: int in image.present:
		if value != 0 and value != 1:
			return REFUSE_COLUMN_FLAG
	for value: int in image.paused:
		if value != 0 and value != 1:
			return REFUSE_COLUMN_FLAG
	for value: int in image.work_begun:
		if value != 0 and value != 1:
			return REFUSE_COLUMN_FLAG
	return REFUSE_NONE


static func _enum_gate_refusal(image: Columns, row: int) -> StringName:
	"""Gate 1 (ENUM): purpose 0..3, phase 0..4, refund_policy 0..2."""
	var purpose: int = image.purpose[row]
	if purpose < PURPOSE_BUILD or purpose >= PURPOSE_COUNT:
		return REFUSE_COLUMN_ENUM
	var phase: int = image.phase[row]
	if phase < PHASE_AWAITING_MATERIALS or phase >= PHASE_COUNT:
		return REFUSE_COLUMN_ENUM
	var policy: int = image.refund_policy[row]
	if policy < REFUND_FULL or policy >= REFUND_POLICY_COUNT:
		return REFUSE_COLUMN_ENUM
	return REFUSE_NONE


static func _value_gate_refusal(image: Columns, row: int) -> StringName:
	"""Gate 2 (VALUE): non-negative counters/quantities; type_id no lower than the -1 sentinel."""
	if image.remaining_mwu[row] < 0 or image.assigned_count[row] < 0:
		return REFUSE_COLUMN_VALUE
	if image.max_workers[row] < 0 or image.type_id[row] < -1:
		return REFUSE_COLUMN_VALUE
	return REFUSE_NONE


static func _ref_pair_refusal(slot: int, generation: int, max_slot: int) -> StringName:
	"""One reference pair: exactly NULL(-1,0), or slot 0..max_slot with generation 1..MAX_i32."""
	if slot == NULL_REF.x and generation == NULL_REF.y:
		return REFUSE_NONE
	if slot < 0 or slot > max_slot:
		return REFUSE_COLUMN_REF
	if generation < 1 or generation > INT32_MAX:
		return REFUSE_COLUMN_REF
	return REFUSE_NONE


static func _ref_gate_refusal(image: Columns, row: int) -> StringName:
	"""Gate 3 (REF): self/subject in the Directory namespace, container in Inventory's own."""
	var max_directory_slot: int = COLUMN_DIRECTORY_CAPACITY - 1
	var self_code: StringName = _ref_pair_refusal(
		image.ref_slot[row], image.ref_generation[row], max_directory_slot)
	if self_code != REFUSE_NONE:
		return self_code
	var subject_code: StringName = _ref_pair_refusal(
		image.subject_slot[row], image.subject_generation[row], max_directory_slot)
	if subject_code != REFUSE_NONE:
		return subject_code
	return _ref_pair_refusal(
		image.material_container_slot[row], image.material_container_generation[row], INT32_MAX)


static func _free_row_refusal(image: Columns, row: int) -> StringName:
	"""Gate 4 (FREE), inactive-row half: null self/subject/container and zeroed progress, always;
	the never-used clear shortcut is stricter still, and distinct from retained-row history."""
	if image.ref_slot[row] != NULL_REF.x or image.ref_generation[row] != NULL_REF.y:
		return REFUSE_COLUMN_FREE
	if image.subject_slot[row] != NULL_REF.x or image.subject_generation[row] != NULL_REF.y:
		return REFUSE_COLUMN_FREE
	if image.material_container_slot[row] != NULL_REF.x \
			or image.material_container_generation[row] != NULL_REF.y:
		return REFUSE_COLUMN_FREE
	if image.remaining_mwu[row] != 0 or image.assigned_count[row] != 0:
		return REFUSE_COLUMN_FREE
	if image.paused[row] != 0 or image.work_begun[row] != 0:
		return REFUSE_COLUMN_FREE
	if image.max_workers[row] == 0:
		if image.purpose[row] != PURPOSE_BUILD or image.type_id[row] != -1:
			return REFUSE_COLUMN_FREE
		if image.phase[row] != PHASE_AWAITING_MATERIALS or image.refund_policy[row] != REFUND_FULL:
			return REFUSE_COLUMN_FREE
	return REFUSE_NONE


static func _free_gate_refusal(image: Columns, row: int) -> StringName:
	"""Gate 4 (FREE): dispatch by present. Present rows require nonnull self AND subject."""
	if image.present[row] == 0:
		return _free_row_refusal(image, row)
	if image.ref_slot[row] == NULL_REF.x and image.ref_generation[row] == NULL_REF.y:
		return REFUSE_COLUMN_FREE
	if image.subject_slot[row] == NULL_REF.x and image.subject_generation[row] == NULL_REF.y:
		return REFUSE_COLUMN_FREE
	return REFUSE_NONE


static func _type_refusal(purpose: int, type_id: int) -> StringName:
	"""A validated (non-sentinel) type_id against its purpose's own domain."""
	match purpose:
		PURPOSE_BUILD, PURPOSE_DEMOLISH:
			if type_id < 0 or type_id >= BUILDING_KINDS:
				return REFUSE_COLUMN_TYPE
		PURPOSE_FURNITURE:
			if type_id < 0 or type_id >= FURNITURE_KINDS:
				return REFUSE_COLUMN_TYPE
		PURPOSE_UPGRADE:
			if not COLUMN_UPGRADE_IDS.has(type_id):
				return REFUSE_COLUMN_TYPE
	return REFUSE_NONE


static func _type_gate_refusal(image: Columns, row: int, purpose: int) -> StringName:
	"""Gate 5 (TYPE): the -1 sentinel is legal only for the exact never-used clear row."""
	var type_id: int = image.type_id[row]
	if type_id == -1:
		if image.present[row] == 0 and image.max_workers[row] == 0:
			return REFUSE_NONE
		return REFUSE_COLUMN_TYPE
	return _type_refusal(purpose, type_id)


static func _workers_gate_refusal(image: Columns, row: int, purpose: int) -> StringName:
	"""Gate 6 (WORKERS): catalog-matched capacity, the assigned cap, paused/refunding idleness.

	PRECONDITION, NOT A NEW FAILURE PATH: `_row_refusal()` reaches this helper only AFTER gate 5
	(TYPE) has returned REFUSE_NONE for this row, so a non-sentinel `type_id` is already proven
	to lie inside its purpose's own domain before COLUMN_BUILDING_MAX_WORKERS is indexed below.
	The frozen gate order is unchanged and this helper stays private by convention: it must
	never be called before the TYPE gate has passed.
	"""
	var max_workers_val: int = image.max_workers[row]
	if image.type_id[row] != -1:
		var expected_max: int = MAX_BUILDERS if purpose == PURPOSE_FURNITURE \
			else COLUMN_BUILDING_MAX_WORKERS[image.type_id[row]]
		if max_workers_val != expected_max:
			return REFUSE_COLUMN_WORKERS
	if image.assigned_count[row] > max_workers_val:
		return REFUSE_COLUMN_WORKERS
	var must_be_idle: bool = image.paused[row] == 1 or image.phase[row] == PHASE_REFUNDING
	if must_be_idle and image.assigned_count[row] != 0:
		return REFUSE_COLUMN_WORKERS
	return REFUSE_NONE


static func _policy_gate_refusal(image: Columns, row: int, purpose: int) -> StringName:
	"""Gate 7 (POLICY): demolition is always DEMOLITION; never recompute from cleared work_begun."""
	if purpose == PURPOSE_DEMOLISH:
		if image.refund_policy[row] != REFUND_DEMOLITION:
			return REFUSE_COLUMN_POLICY
		return REFUSE_NONE
	if image.present[row] == 1:
		var expected: int = REFUND_PARTIAL if image.work_begun[row] == 1 else REFUND_FULL
		if image.refund_policy[row] != expected:
			return REFUSE_COLUMN_POLICY
		return REFUSE_NONE
	if image.phase[row] == PHASE_WORK_DONE and image.refund_policy[row] != REFUND_PARTIAL:
		return REFUSE_COLUMN_POLICY
	if image.phase[row] == PHASE_REFUNDING and image.refund_policy[row] != REFUND_FULL \
			and image.refund_policy[row] != REFUND_PARTIAL:
		return REFUSE_COLUMN_POLICY
	return REFUSE_NONE


static func _declared_work_mwu_for_row(purpose: int, type_id: int) -> int:
	"""Frozen declared work W for a validated purpose/type pair, from the gate arrays alone.

	Callers must have already run the TYPE gate; an out-of-range pair returns 0, which the PHASE
	gate treats as a refusal rather than a valid zero-work project ("All W are positive").
	"""
	match purpose:
		PURPOSE_BUILD:
			if type_id < 0 or type_id >= BUILDING_KINDS:
				return 0
			return COLUMN_BUILDING_WORK_MWU[type_id]
		PURPOSE_FURNITURE:
			if type_id < 0 or type_id >= FURNITURE_KINDS:
				return 0
			return COLUMN_FURNITURE_WORK_MWU[type_id]
		PURPOSE_UPGRADE:
			var index: int = COLUMN_UPGRADE_IDS.find(type_id)
			if index < 0:
				return 0
			return COLUMN_UPGRADE_WORK_MWU[index]
		PURPOSE_DEMOLISH:
			if type_id < 0 or type_id >= BUILDING_KINDS:
				return 0
			@warning_ignore("integer_division") return COLUMN_BUILDING_WORK_MWU[type_id] * DEMOLITION_WORK_NUM / DEMOLITION_WORK_DEN
	return 0


static func _declared_bill_pairs_for_row(purpose: int, type_id: int) -> int:
	"""Frozen delivery-bill pair count for a validated purpose/type pair. DEMOLISH is always 0."""
	match purpose:
		PURPOSE_BUILD:
			if type_id < 0 or type_id >= BUILDING_KINDS:
				return 0
			return COLUMN_BUILDING_BILL_PAIR_COUNTS[type_id]
		PURPOSE_FURNITURE:
			if type_id < 0 or type_id >= FURNITURE_KINDS:
				return 0
			return COLUMN_FURNITURE_BILL_PAIR_COUNTS[type_id]
		PURPOSE_UPGRADE:
			var index: int = COLUMN_UPGRADE_IDS.find(type_id)
			if index < 0:
				return 0
			return COLUMN_UPGRADE_BILL_PAIR_COUNTS[index]
	return 0


static func _live_phase_shape_refusal(image: Columns, row: int, purpose: int, type_id: int,
		phase: int, w: int) -> StringName:
	"""The per-phase work_begun/remaining_mwu shape a LIVE row's phase declares (contract §8)."""
	var begun: int = image.work_begun[row]
	var remaining: int = image.remaining_mwu[row]
	match phase:
		PHASE_AWAITING_MATERIALS:
			if begun != 0 or remaining != w:
				return REFUSE_COLUMN_PHASE
			if _declared_bill_pairs_for_row(purpose, type_id) <= 0:
				return REFUSE_COLUMN_PHASE
		PHASE_READY:
			if begun != 0 or remaining != w:
				return REFUSE_COLUMN_PHASE
		PHASE_WORKING:
			if begun != 1 or remaining < 1 or remaining > w:
				return REFUSE_COLUMN_PHASE
		PHASE_WORK_DONE:
			if begun != 1 or remaining != 0:
				return REFUSE_COLUMN_PHASE
		PHASE_REFUNDING:
			var awaiting_shape: bool = begun == 0 and remaining == w
			var working_shape: bool = begun == 1 and remaining >= 0 and remaining <= w
			if not (awaiting_shape or working_shape):
				return REFUSE_COLUMN_PHASE
	return REFUSE_NONE


static func _phase_gate_refusal(image: Columns, row: int, purpose: int) -> StringName:
	"""Gate 8 (PHASE): retained rows admit only WORK_DONE/REFUNDING; live rows check W exactly."""
	var type_id: int = image.type_id[row]
	if type_id == -1:
		return REFUSE_NONE
	var phase: int = image.phase[row]
	if image.present[row] == 0:
		if phase != PHASE_WORK_DONE and phase != PHASE_REFUNDING:
			return REFUSE_COLUMN_PHASE
		return REFUSE_NONE
	var w: int = _declared_work_mwu_for_row(purpose, type_id)
	if w <= 0:
		return REFUSE_COLUMN_PHASE
	return _live_phase_shape_refusal(image, row, purpose, type_id, phase, w)


static func _row_refusal(image: Columns, row: int) -> StringName:
	"""One row through gates 1-8 in the frozen order; returns the first gate that refuses."""
	var enum_code: StringName = _enum_gate_refusal(image, row)
	if enum_code != REFUSE_NONE:
		return enum_code
	var value_code: StringName = _value_gate_refusal(image, row)
	if value_code != REFUSE_NONE:
		return value_code
	var ref_code: StringName = _ref_gate_refusal(image, row)
	if ref_code != REFUSE_NONE:
		return ref_code
	var free_code: StringName = _free_gate_refusal(image, row)
	if free_code != REFUSE_NONE:
		return free_code
	var purpose: int = image.purpose[row]
	var type_code: StringName = _type_gate_refusal(image, row, purpose)
	if type_code != REFUSE_NONE:
		return type_code
	var workers_code: StringName = _workers_gate_refusal(image, row, purpose)
	if workers_code != REFUSE_NONE:
		return workers_code
	var policy_code: StringName = _policy_gate_refusal(image, row, purpose)
	if policy_code != REFUSE_NONE:
		return policy_code
	return _phase_gate_refusal(image, row, purpose)


static func columns_refusal(image: Columns) -> StringName:
	"""Deterministic local refusal order (contract "Deterministic local refusal order").

	Read-only pure predicate over a caller-owned cold `Columns` image: no diagnostics, live reads,
	clock, callbacks, serialized copies, packed scratch or per-row objects. Shape fails first, then
	the independent source preflight, then the three flag buffers are scanned in full (present,
	paused, work_begun, that order), then rows 0..82943 are visited ascending and the first failing
	gate on a row is returned. Never relies on any caller having already run the source preflight.
	Returns REFUSE_NONE on success.
	"""
	if image == null or not image.is_sized():
		return REFUSE_COLUMN_SHAPE
	var source_code: StringName = column_source_metadata_refusal()
	if source_code != REFUSE_NONE:
		return source_code
	if _columns_proven(image):
		return REFUSE_NONE
	var flag_code: StringName = _column_flag_scan_refusal(image)
	if flag_code != REFUSE_NONE:
		return flag_code
	for row: int in image.present.size():
		var row_code: StringName = _row_refusal(image, row)
		if row_code != REFUSE_NONE:
			return row_code
	return REFUSE_NONE


static func _columns_proven(image: Columns) -> bool:
	"""ADR 1235: the flag and row walks above provably accept. Every gate reads only its own row
	of these sixteen columns, so `ColumnProofs.rows_proven()` may judge identical rows once; any
	doubt returns false and the walks run, so each refusal is unchanged."""
	for flags: PackedByteArray in [image.present, image.paused, image.work_begun]:
		if not ColumnProofs.bytes_are_flags(flags):
			return false
	return ColumnProofs.rows_proven(_image_columns(image),
		_image_row_ok.bind(image))


static func _image_row_ok(row: int, image: Columns) -> bool:
	"""One row passes gates 1-8 (bound, not a lambda: see `Buildings._building_row_ok()`)."""
	return _row_refusal(image, row) == REFUSE_NONE


# --- ADR1155: owner-owned release after the complete original World has been cleared. ---

static func world_retirement_refusal_in(actual: RefCounted, ids: EntityDirectory,
		world: Vector2i, persistent_id: int, excavation: ExcavationContract,
		modular: ModularContract, cleared: bool) -> StringName:
	"""Preserve exact optional-null/expired authority distinctions and every paid live row."""
	if actual == null or actual._directory != ids or actual._buildings == null \
			or actual._buildings._directory != ids:
		return &"WORLD_RETIREMENT_CONSTRUCTION"
	if not _retirement_authority_matches(actual._excavation_authority, excavation) \
			or not _retirement_authority_matches(actual._modular_authority, modular):
		return &"WORLD_RETIREMENT_CONSTRUCTION"
	var code: StringName = Buildings.whole_world_retirement_refusal_in(ids, world, persistent_id, cleared)
	if code != &"": return code
	if cleared and (actual._live_count != 0 or actual._present.has(1) \
			or actual._delivered_milli.count(0) != actual._delivered_milli.size()):
		return &"WORLD_RETIREMENT_NOT_EMPTY"
	return &""


static func _retirement_authority_matches(binding: WeakRef, expected: RefCounted) -> bool:
	"""An expired original weak binding is not the optional unbound state."""
	return binding == null if expected == null else binding != null and binding.get_ref() == expected


static func world_retirement_release_preflighted_in(actual: RefCounted, ids: EntityDirectory,
		world: Vector2i, persistent_id: int, excavation: ExcavationContract,
		modular: ModularContract) -> StringName:
	"""Release this owner's two exact lifetime links without refunding, clearing or allocating."""
	var code: StringName = world_retirement_refusal_in(actual, ids, world, persistent_id, excavation, modular, true)
	if code != &"": return code
	actual._excavation_authority = null
	actual._modular_authority = null
	return &""



# --- ARCH-SAVE-002 sections 4 + 5 + the Q7 section 6 owners bulk API (ADR 1222 build step 3) -----
#
# Construction's saved rows travel in THREE images restored in one call:
#   * `columns` -- the frozen section-4 owner (ADR 0186): every row whose purpose is BUILD,
#     UPGRADE, FURNITURE or DEMOLISH, and the exact clear row everywhere else;
#   * `extension` -- section 6 owner `construction_extension` (DEC-055 Q7(a)): the same sixteen
#     columns for every row whose purpose is outside the frozen enum (REMOVE_FURNITURE, EXCAVATION,
#     SPATIAL_FURNITURE, SPOIL_TIP, CONNECTOR_INSTALL), and the exact clear row everywhere else;
#   * `ledger` -- section 5's `_delivered_milli` plus section 6 owner `construction_paid_ledger`.
# A row is carried by exactly one of the first two images. `restore_columns()` judges `columns`
# with the frozen `columns_refusal()`, `extension` with `extension_refusal()`, the split, the
# ledger shape and the Directory resolution of every present row before its first write, then
# installs the merged rows and recounts `_live_count`. Live semantics of an extended row (its
# Site, Router or spatial owner) are re-proved by the underground restore, not here.

const REFUSE_COLUMN_SPLIT: StringName = &"COLUMN_SPLIT"
const REFUSE_COLUMN_LEDGER: StringName = &"COLUMN_LEDGER"
const REFUSE_COLUMN_DIRECTORY: StringName = &"COLUMN_DIRECTORY"

## The code of the most recent refused bulk column call, or REFUSE_NONE. Category 3.
var _last_column_refusal: StringName = REFUSE_NONE


class Ledger extends RefCounted:
	"""Caller-owned image of the delivered ledger (section 5) and the paid ledger (section 6)."""
	var delivered_milli: PackedInt64Array = PackedInt64Array()
	var paid_base_type: PackedInt32Array = PackedInt32Array()
	var paid_upgrade_mask: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Size all three columns and fill the clear store's values."""
		delivered_milli.resize(DELIVERED_CELLS)
		paid_base_type.resize(CONSTRUCTION_CAPACITY)
		paid_upgrade_mask.resize(CONSTRUCTION_CAPACITY)
		delivered_milli.fill(0)
		paid_base_type.fill(NO_PAID_PACKAGE)
		paid_upgrade_mask.fill(0)

	func is_sized() -> bool:
		"""True only at the canonical extents."""
		return delivered_milli.size() == DELIVERED_CELLS \
			and paid_base_type.size() == CONSTRUCTION_CAPACITY \
			and paid_upgrade_mask.size() == CONSTRUCTION_CAPACITY

	func equals(other: Ledger) -> bool:
		"""All three columns byte-identical."""
		return other != null and delivered_milli == other.delivered_milli \
			and paid_base_type == other.paid_base_type \
			and paid_upgrade_mask == other.paid_upgrade_mask


func last_column_refusal() -> StringName:
	"""The code of the most recent refused bulk column call, or REFUSE_NONE after a success."""
	return _last_column_refusal


func copy_columns_into(columns: Columns, extension: Columns, ledger: Ledger) -> bool:
	"""Snapshot every row into the frozen or extension image, and both ledgers. False = SHAPE."""
	if columns == null or extension == null or ledger == null or not columns.is_sized() \
			or not extension.is_sized() or not ledger.is_sized():
		_last_column_refusal = REFUSE_COLUMN_SHAPE
		return false
	columns._fill_clear_values()
	extension._fill_clear_values()
	for row: int in CONSTRUCTION_CAPACITY:
		_copy_row_into(extension if _purpose[row] >= PURPOSE_COUNT else columns, row)
	ledger.delivered_milli.clear()
	ledger.delivered_milli.append_array(_delivered_milli)
	ledger.paid_base_type.clear()
	ledger.paid_base_type.append_array(_paid_base_type)
	ledger.paid_upgrade_mask.clear()
	ledger.paid_upgrade_mask.append_array(_paid_upgrade_mask)
	_last_column_refusal = REFUSE_NONE
	return true


func _copy_row_into(out: Columns, row: int) -> void:
	"""One live row's sixteen values into `out` at the same physical row."""
	out.present[row] = _present[row]
	out.material_container_slot[row] = _material_container_slot[row]
	out.material_container_generation[row] = _material_container_generation[row]
	out.assigned_count[row] = _assigned_count[row]
	out.max_workers[row] = _max_workers[row]
	out.refund_policy[row] = _refund_policy[row]
	out.remaining_mwu[row] = _remaining_mwu[row]
	out.paused[row] = _paused[row]
	out.work_begun[row] = _work_begun[row]
	out.ref_slot[row] = _ref_slot[row]
	out.ref_generation[row] = _ref_generation[row]
	out.subject_slot[row] = _subject_slot[row]
	out.subject_generation[row] = _subject_generation[row]
	out.purpose[row] = _purpose[row]
	out.type_id[row] = _type_id[row]
	out.phase[row] = _phase[row]


func restore_columns(columns: Columns, extension: Columns, ledger: Ledger) -> bool:
	"""Install the three images in one call, then recount. False writes nothing.

	Allocate before consume (decision 0059): every predicate below and the Directory resolution
	run before the first write. Authority WeakRefs are untouched; re-mounting re-binds them.
	"""
	var code: StringName = columns_refusal(columns)
	if code == REFUSE_NONE and not _restore_proven(columns, extension, ledger):
		code = extension_refusal(extension)
		if code == REFUSE_NONE:
			code = split_refusal(columns, extension)
		if code == REFUSE_NONE:
			code = _ledger_refusal(columns, extension, ledger)
	if code == REFUSE_NONE:
		code = _directory_refusal(columns, extension)
	if code != REFUSE_NONE:
		_last_column_refusal = code
		return false
	_install_merged(columns, extension)
	_delivered_milli = ledger.delivered_milli.duplicate()
	_paid_base_type = ledger.paid_base_type.duplicate()
	_paid_upgrade_mask = ledger.paid_upgrade_mask.duplicate()
	_live_count = _present.count(1)
	_last_column_refusal = REFUSE_NONE
	return true


func _install_merged(columns: Columns, extension: Columns) -> void:
	"""Private copies of the frozen image, then every extension-owned row written over them."""
	_present = columns.present.duplicate()
	_material_container_slot = columns.material_container_slot.duplicate()
	_material_container_generation = columns.material_container_generation.duplicate()
	_assigned_count = columns.assigned_count.duplicate()
	_max_workers = columns.max_workers.duplicate()
	_refund_policy = columns.refund_policy.duplicate()
	_remaining_mwu = columns.remaining_mwu.duplicate()
	_paused = columns.paused.duplicate()
	_work_begun = columns.work_begun.duplicate()
	_ref_slot = columns.ref_slot.duplicate()
	_ref_generation = columns.ref_generation.duplicate()
	_subject_slot = columns.subject_slot.duplicate()
	_subject_generation = columns.subject_generation.duplicate()
	_purpose = columns.purpose.duplicate()
	_type_id = columns.type_id.duplicate()
	_phase = columns.phase.duplicate()
	for row: int in CONSTRUCTION_CAPACITY:
		if extension.purpose[row] >= PURPOSE_COUNT:
			_install_extension_row(extension, row)


func _install_extension_row(extension: Columns, row: int) -> void:
	"""Overwrite one physical row with the extension image's values."""
	_present[row] = extension.present[row]
	_material_container_slot[row] = extension.material_container_slot[row]
	_material_container_generation[row] = extension.material_container_generation[row]
	_assigned_count[row] = extension.assigned_count[row]
	_max_workers[row] = extension.max_workers[row]
	_refund_policy[row] = extension.refund_policy[row]
	_remaining_mwu[row] = extension.remaining_mwu[row]
	_paused[row] = extension.paused[row]
	_work_begun[row] = extension.work_begun[row]
	_ref_slot[row] = extension.ref_slot[row]
	_ref_generation[row] = extension.ref_generation[row]
	_subject_slot[row] = extension.subject_slot[row]
	_subject_generation[row] = extension.subject_generation[row]
	_purpose[row] = extension.purpose[row]
	_type_id[row] = extension.type_id[row]
	_phase[row] = extension.phase[row]


func _ledger_refusal(columns: Columns, extension: Columns, ledger: Ledger) -> StringName:
	"""Shape, no delivery past a row's own bill (a modular quote may use every line), and clear
	paid ledgers on every never-used row."""
	if ledger == null or not ledger.is_sized():
		return REFUSE_COLUMN_SHAPE
	for row: int in CONSTRUCTION_CAPACITY:
		if not _ledger_row_ok(columns, extension, ledger, row):
			return REFUSE_COLUMN_LEDGER
	for value: int in ledger.delivered_milli:
		if value < 0:
			return REFUSE_COLUMN_LEDGER
	return REFUSE_NONE


func _ledger_row_ok(columns: Columns, extension: Columns, ledger: Ledger,
		row: int) -> bool:
	"""One row of `_ledger_refusal()`: no delivery past the row's bill, paid ledgers in range and
	clear on a never-used row. Reads only that row of both images and of the ledger."""
	var image: Columns = extension if extension.purpose[row] >= PURPOSE_COUNT else columns
	var bill: int = 0
	if is_modular(image.purpose[row]):
		bill = MATERIAL_SLOTS_PER_PROJECT
	elif image.type_id[row] != -1:
		bill = _bill_count_of(image.purpose[row], image.type_id[row])
	for index: int in range(bill, MATERIAL_SLOTS_PER_PROJECT):
		if ledger.delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index] != 0:
			return false
	if ledger.paid_base_type[row] < NO_PAID_PACKAGE or ledger.paid_upgrade_mask[row] < 0:
		return false
	return image.type_id[row] != -1 or (ledger.paid_base_type[row] == NO_PAID_PACKAGE
		and ledger.paid_upgrade_mask[row] == 0)


func _restore_proven(columns: Columns, extension: Columns, ledger: Ledger) -> bool:
	"""ADR 1235: `extension_refusal()`, `split_refusal()` and `_ledger_refusal()` provably accept.
	Their row gates read only that row of both images and of the ledger, so `ColumnProofs`
	judges identical rows once; any doubt returns false and the three walks run unchanged."""
	if extension == null or not extension.is_sized() or not columns.is_sized() \
			or ledger == null or not ledger.is_sized():
		return false
	for flags: PackedByteArray in [extension.present, extension.paused, extension.work_begun]:
		if not ColumnProofs.bytes_are_flags(flags):
			return false
	var extra: PackedInt32Array = PackedInt32Array()
	if ColumnProofs.i64_minimum(ledger.delivered_milli) < 0 or not ColumnProofs.strided_deviant_rows(
			ledger.delivered_milli, MATERIAL_SLOTS_PER_PROJECT, CONSTRUCTION_CAPACITY, extra):
		return false
	var inputs: Array = _image_columns(columns) + _image_columns(extension)
	inputs.append_array([ledger.paid_base_type, ledger.paid_upgrade_mask])
	return ColumnProofs.rows_proven(inputs, _restore_row_ok.bind(columns, extension, ledger), extra)


func _restore_row_ok(row: int, columns: Columns, extension: Columns, ledger: Ledger) -> bool:
	"""One row of the extension, split and ledger walks."""
	var purpose: int = extension.purpose[row]
	if purpose < PURPOSE_COUNT:
		if not _is_clear_row(extension, row):
			return false
	elif _extension_row_refusal(extension, row, purpose) != REFUSE_NONE \
			or not _is_clear_row(columns, row):
		return false
	return _ledger_row_ok(columns, extension, ledger, row)


static func _image_columns(image: Columns) -> Array:
	"""The sixteen columns of one image, in ordinal order."""
	return [image.present, image.material_container_slot, image.material_container_generation,
		image.assigned_count, image.max_workers, image.refund_policy, image.remaining_mwu,
		image.paused, image.work_begun, image.ref_slot, image.ref_generation, image.subject_slot,
		image.subject_generation, image.purpose, image.type_id, image.phase]


func _directory_refusal(columns: Columns, extension: Columns) -> StringName:
	"""Every present row's own reference resolves to a live CONSTRUCTION entry at that row. Only
	rows present in either image can be present in the one that carries them (ADR 1235)."""
	var rows: PackedInt32Array = ColumnProofs.rows_holding(columns.present, 1)
	rows.append_array(ColumnProofs.rows_holding(extension.present, 1))
	rows.sort()
	for row: int in rows:
		var image: Columns = extension if extension.purpose[row] >= PURPOSE_COUNT else columns
		if image.present[row] != 1:
			continue
		var ref: Vector2i = Vector2i(image.ref_slot[row], image.ref_generation[row])
		if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_CONSTRUCTION) \
				or _directory.get_typed_row(ref) != row:
			return REFUSE_COLUMN_DIRECTORY
	return REFUSE_NONE


# --- the pure extension predicates ---------------------------------------------------------------

static func split_refusal(columns: Columns, extension: Columns) -> StringName:
	"""Each row is carried by exactly one image: an extension-owned row is clear in `columns`."""
	if columns == null or extension == null or not columns.is_sized() or not extension.is_sized():
		return REFUSE_COLUMN_SHAPE
	for row: int in CONSTRUCTION_CAPACITY:
		if extension.purpose[row] >= PURPOSE_COUNT and not _is_clear_row(columns, row):
			return REFUSE_COLUMN_SPLIT
	return REFUSE_NONE


static func _is_clear_row(image: Columns, row: int) -> bool:
	"""The exact never-used clear row of `Columns._fill_clear_values()`."""
	return image.present[row] == 0 and image.material_container_slot[row] == NULL_REF.x \
		and image.material_container_generation[row] == NULL_REF.y \
		and image.assigned_count[row] == 0 and image.max_workers[row] == 0 \
		and image.refund_policy[row] == REFUND_FULL and image.remaining_mwu[row] == 0 \
		and image.paused[row] == 0 and image.work_begun[row] == 0 \
		and image.ref_slot[row] == NULL_REF.x and image.ref_generation[row] == NULL_REF.y \
		and image.subject_slot[row] == NULL_REF.x and image.subject_generation[row] == NULL_REF.y \
		and image.purpose[row] == PURPOSE_BUILD and image.type_id[row] == -1 \
		and image.phase[row] == PHASE_AWAITING_MATERIALS


static func extension_refusal(image: Columns) -> StringName:
	"""The structural predicate over the extension owner. Frozen-purpose rows must be clear.

	An extended row: purpose REMOVE_FURNITURE..CONNECTOR_INSTALL, phase and refund policy in
	domain, canonical flags, nonnegative counters with assigned <= max, well-shaped references,
	and the free-row canon (null refs, no progress) when not present.
	"""
	if image == null or not image.is_sized():
		return REFUSE_COLUMN_SHAPE
	var flags: StringName = _column_flag_scan_refusal(image)
	if flags != REFUSE_NONE:
		return flags
	for row: int in CONSTRUCTION_CAPACITY:
		var purpose: int = image.purpose[row]
		if purpose < PURPOSE_COUNT:
			if not _is_clear_row(image, row):
				return REFUSE_COLUMN_SPLIT
			continue
		var code: StringName = _extension_row_refusal(image, row, purpose)
		if code != REFUSE_NONE:
			return code
	return REFUSE_NONE


static func _extension_row_refusal(image: Columns, row: int, purpose: int) -> StringName:
	"""One extended row: enums, values, reference shape, then the present/free canon."""
	if purpose >= LIVE_PURPOSE_COUNT or image.phase[row] < 0 or image.phase[row] >= PHASE_COUNT \
			or image.refund_policy[row] < 0 or image.refund_policy[row] >= REFUND_POLICY_COUNT:
		return REFUSE_COLUMN_ENUM
	if image.remaining_mwu[row] < 0 or image.assigned_count[row] < 0 \
			or image.max_workers[row] < 0 or image.assigned_count[row] > image.max_workers[row]:
		return REFUSE_COLUMN_VALUE
	var ref_code: StringName = _ref_gate_refusal(image, row)
	if ref_code != REFUSE_NONE:
		return ref_code
	if image.present[row] == 1:
		return _free_gate_refusal(image, row)
	return _extension_free_refusal(image, row)


static func _extension_free_refusal(image: Columns, row: int) -> StringName:
	"""A retained (not present) extended row keeps its purpose/type/phase history and no more."""
	if image.ref_slot[row] != NULL_REF.x or image.ref_generation[row] != NULL_REF.y \
			or image.subject_slot[row] != NULL_REF.x \
			or image.subject_generation[row] != NULL_REF.y \
			or image.material_container_slot[row] != NULL_REF.x \
			or image.material_container_generation[row] != NULL_REF.y:
		return REFUSE_COLUMN_FREE
	if image.remaining_mwu[row] != 0 or image.assigned_count[row] != 0 \
			or image.paused[row] != 0 or image.work_begun[row] != 0:
		return REFUSE_COLUMN_FREE
	return REFUSE_NONE
