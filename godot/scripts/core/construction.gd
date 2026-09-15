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
##     demolition.
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
##   * A TIER-2 BUILDING'S DEMOLITION BASIS IS UNRESOLVED. REQ-SET-127 says "50% original material
##     costs" and "the declared construction WU x 0.25". §4.2's upgrade table declares no
##     demolition consequence and no document says whether a tier-2 package's materials and work
##     join that basis. This store uses the BASE §4.1 row for every tier and states so; no
##     summation rule was invented.
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

var _live_count: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_buildings: Buildings = null) -> void:
	"""Adopt or build the Building store, compile the three bills, and size every column once."""
	assert(CONSTRUCTION_CAPACITY
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
	var count: int = pairs.size() / 2
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
	if purpose == PURPOSE_FURNITURE:
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
	match purpose:
		PURPOSE_BUILD:
			return _build_count[type_id]
		PURPOSE_UPGRADE:
			return _upgrade_count[type_id]
		PURPOSE_FURNITURE:
			return _furniture_count[type_id]
	return 0


func bill_size_into(purpose: int, type_id: int, out: IntMath.IntResult) -> bool:
	"""Write the DELIVERY bill's pair count into `out`; refuse an unknown purpose or type."""
	if purpose < 0 or purpose >= PURPOSE_COUNT:
		return out.refuse(REFUSE_UNKNOWN_PURPOSE)
	if _bill_stride_row(purpose, type_id) == NO_ROW:
		return out.refuse(REFUSE_UNKNOWN_BUILDING_TYPE if purpose != PURPOSE_FURNITURE
			else REFUSE_UNKNOWN_FURNITURE_TYPE)
	return out.succeed(_bill_count_of(purpose, type_id))


func _bill_key_column(purpose: int) -> PackedInt32Array:
	"""The key column a delivery purpose reads. PURPOSE_DEMOLISH has no delivery bill."""
	if purpose == PURPOSE_UPGRADE:
		return _upgrade_key
	if purpose == PURPOSE_FURNITURE:
		return _furniture_key
	return _build_key


func _bill_milli_column(purpose: int) -> PackedInt64Array:
	"""The quantity column a delivery purpose reads. PURPOSE_DEMOLISH has no delivery bill."""
	if purpose == PURPOSE_UPGRADE:
		return _upgrade_milli
	if purpose == PURPOSE_FURNITURE:
		return _furniture_milli
	return _build_milli


func material_key_index_into(purpose: int, type_id: int, index: int,
		out: IntMath.IntResult) -> bool:
	"""Write the MATERIAL_KEYS index of one bill entry into `out`; refuse outside the bill."""
	if not bill_size_into(purpose, type_id, out):
		return false
	if index < 0 or index >= out.value:
		return out.refuse(REFUSE_MATERIAL_INDEX)
	var base: int = _bill_stride_row(purpose, type_id)
	return out.succeed(_bill_key_column(purpose)[base + index])


func required_milli_into(purpose: int, type_id: int, index: int,
		out: IntMath.IntResult) -> bool:
	"""Write one bill entry's required quantity_milli into `out`; refuse outside the bill."""
	if not bill_size_into(purpose, type_id, out):
		return false
	if index < 0 or index >= out.value:
		return out.refuse(REFUSE_MATERIAL_INDEX)
	var base: int = _bill_stride_row(purpose, type_id)
	return out.succeed(_bill_milli_column(purpose)[base + index])


func material_index_of_key_into(purpose: int, type_id: int, key: StringName,
		out: IntMath.IntResult) -> bool:
	"""Write the bill index carrying `key` into `out`. REFUSES rather than returning a sentinel.

	A caller that has resolved a compiled item id back to its key uses this to name the slot it
	is delivering into, so a load of wood can never be credited against the stone line.
	"""
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

	REQ-SET-127 prices a demolition at "the declared construction WU x 0.25" of the BASE §4.1 row.
	Whether a tier-2 package's own work joins that basis is unresolved (header); it does not here.
	"""
	if not bill_size_into(purpose, type_id, out):
		return false
	match purpose:
		PURPOSE_BUILD:
			return out.succeed(_definitions.work_mwu_of(type_id))
		PURPOSE_FURNITURE:
			return out.succeed(_definitions.furniture_work_mwu_of(type_id))
		PURPOSE_UPGRADE:
			if _upgrade_count[type_id] == 0:
				return out.refuse(REFUSE_NO_UPGRADE_PACKAGE)
			return out.succeed(_upgrade_work[type_id])
	return IntMath.floor_div_into(_definitions.work_mwu_of(type_id) * DEMOLITION_WORK_NUM,
		DEMOLITION_WORK_DEN, out)


# --- project lifecycle ---------------------------------------------------------------------------

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

	NOT THE PLAYER-FACING GATE. This publishes the project and moves the subject to DEMOLISHING
	as soon as the resident half passes; it can see no container at all. REQ-SET-128 in full is
	`settlement_system.gd::request_demolition()`, which proves endpoints and rechecks goods,
	claims and occupants before anything here is called.
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
	var opened: OpResult = _open(PURPOSE_DEMOLISH, building_ref,
		_buildings.type_id_of_building(building_ref).value)
	if opened.ok:
		_buildings.set_building_state(building_ref, STATE_DEMOLISHING)
	return opened


func open_furniture(furniture_ref: Vector2i) -> OpResult:
	"""Publish the §4.3 construction project for one placed furniture row.

	`buildings.gd` publishes a furniture row committed -- §4.2 gives Furniture no state column --
	so the row exists before its project completes. Nothing was invented to give it one.
	"""
	if not _buildings.is_live_furniture(furniture_ref):
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	if _project_of_subject(furniture_ref) != NO_ROW:
		return _refuse(REFUSE_ALREADY_UNDER_CONSTRUCTION)
	return _open(PURPOSE_FURNITURE, furniture_ref,
		_buildings.type_id_of_furniture(furniture_ref).value)


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
	var work: int = _math.value
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_CONSTRUCTION)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var row: int = _directory.get_typed_row(ref)
	_write_row(row, ref, purpose, subject_ref, type_id, work)
	if purpose != PURPOSE_FURNITURE:
		_buildings.set_building_construction(subject_ref, ref)
	_live_count += 1
	return OpResult.new(true, REFUSE_NONE, row, ref)


func _write_row(row: int, ref: Vector2i, purpose: int, subject_ref: Vector2i, type_id: int,
		work: int) -> void:
	"""Initialize every Construction column of a freshly allocated row before it is published."""
	_material_container_slot[row] = EntityDirectory.NULL_SLOT
	_material_container_generation[row] = EntityDirectory.NULL_GENERATION
	_assigned_count[row] = 0
	_max_workers[row] = _max_workers_for(purpose, type_id)
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
	_phase[row] = PHASE_AWAITING_MATERIALS if _bill_count_of(purpose, type_id) > 0 \
		else PHASE_READY
	_refund_policy[row] = _policy_for(purpose, 0)


func _max_workers_for(purpose: int, type_id: int) -> int:
	"""GDD §5.9's "Maximum 4 builders/project unless listed", read from the owning definition."""
	if purpose == PURPOSE_FURNITURE:
		return MAX_BUILDERS
	return _definitions.max_builders_of(type_id)


static func _policy_for(purpose: int, work_begun: int) -> int:
	"""§4.2's `refund_policy`, derived from the only two facts REQ-SET-126/127 depend on."""
	if purpose == PURPOSE_DEMOLISH:
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
	if index < 0 or index >= _bill_count_of(_purpose[row], _type_id[row]):
		return REFUSE_MATERIAL_INDEX
	var cell: int = row * MATERIAL_SLOTS_PER_PROJECT + index
	if not IntMath.checked_add_into(_delivered_milli[cell], quantity_milli, _math):
		return REFUSE_OVERFLOW
	var base: int = _bill_stride_row(_purpose[row], _type_id[row])
	if _math.value > _bill_milli_column(_purpose[row])[base + index]:
		return REFUSE_OVER_DELIVERY
	return REFUSE_NONE


func _all_materials_delivered(row: int) -> bool:
	"""True when every line of this project's delivery bill has reached its required quantity."""
	var purpose: int = _purpose[row]
	var base: int = _bill_stride_row(purpose, _type_id[row])
	var column: PackedInt64Array = _bill_milli_column(purpose)
	for index: int in _bill_count_of(purpose, _type_id[row]):
		if _delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index] < column[base + index]:
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
	_phase[row] = PHASE_WORKING
	_refund_policy[row] = _policy_for(_purpose[row], 1)
	if _purpose[row] == PURPOSE_BUILD:
		_buildings.set_building_state(subject, STATE_BUILDING)
	return OpResult.new(true, REFUSE_NONE, _remaining_mwu[row], project_ref)


func add_work_mwu(project_ref: Vector2i, mwu: int) -> OpResult:
	"""Retire milli-WU against a working project; return the milli-WU still outstanding.

	Refuses in every phase but PHASE_WORKING, which is what makes REQ-SET-125's "as progress
	begins" a precondition rather than a comment. A contribution larger than the remainder is
	capped at it rather than refused: §5.3's capped final contribution semantics.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if _phase[row] != PHASE_WORKING:
		return _refuse(REFUSE_WRONG_PHASE)
	if _paused[row] == 1:
		return _refuse(REFUSE_PAUSED)
	if mwu <= 0:
		return _refuse(REFUSE_INVALID_WORK)
	_remaining_mwu[row] = maxi(0, _remaining_mwu[row] - mwu)
	if _remaining_mwu[row] == 0:
		_phase[row] = PHASE_WORK_DONE
	return OpResult.new(true, REFUSE_NONE, _remaining_mwu[row], project_ref)


func commit_completion(project_ref: Vector2i) -> OpResult:
	"""Atomically publish a finished project's result and retire its row.

	ECON-003's commit-pending rule in force: if the Building edit refuses -- a demolition whose
	rooms still exist, for instance -- the project stays in PHASE_WORK_DONE with its earned work
	intact and the retry costs nothing. Nothing is published in halves.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
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
		PURPOSE_DEMOLISH:
			_buildings.set_building_construction(subject, NULL_REF)
			var result: Buildings.OpResult = _buildings.demolish_building(subject)
			if not result.ok:
				_buildings.set_building_construction(subject, _ref_of_row(row))
				return result.error
	return REFUSE_NONE


func _retire(row: int, project_ref: Vector2i, subject: Vector2i) -> void:
	"""Clear the subject's back-reference, free the row and hand the directory slot back."""
	if _purpose[row] != PURPOSE_FURNITURE and _buildings.is_live_building(subject):
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
	if _purpose[row] == PURPOSE_DEMOLISH:
		return out.refuse(REFUSE_IS_A_DEMOLITION)
	if index < 0 or index >= _bill_count_of(_purpose[row], _type_id[row]):
		return out.refuse(REFUSE_MATERIAL_INDEX)
	var delivered: int = _delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index]
	if _refund_policy[row] == REFUND_FULL:
		return out.succeed(delivered * REFUND_FULL_NUM / REFUND_FULL_DEN)
	if not IntMath.checked_mul_into(delivered, REFUND_PARTIAL_NUM, out):
		return out.refuse(REFUSE_OVERFLOW)
	return IntMath.floor_div_into(out.value, REFUND_PARTIAL_DEN, out)


func demolition_return_milli_into(project_ref: Vector2i, index: int,
		out: IntMath.IntResult) -> bool:
	"""REQ-SET-127's manifest line: 50% of the ORIGINAL §4.1 material cost, floored to milli-U.

	REFUSES anything but a demolition. The basis is the definition's own bill, never the delivered
	ledger, which a demolition never fills -- and never the tier-2 package (header).
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	if _purpose[row] != PURPOSE_DEMOLISH:
		return out.refuse(REFUSE_NOT_A_DEMOLITION)
	var type_id: int = _type_id[row]
	if index < 0 or index >= _build_count[type_id]:
		return out.refuse(REFUSE_MATERIAL_INDEX)
	var base: int = type_id * MATERIAL_SLOTS_PER_PROJECT
	if not IntMath.checked_mul_into(_build_milli[base + index], REFUND_DEMOLITION_NUM, out):
		return out.refuse(REFUSE_OVERFLOW)
	return IntMath.floor_div_into(out.value, REFUND_DEMOLITION_DEN, out)


func demolition_return_size_into(project_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""How many lines REQ-SET-127's return manifest has. Refuses anything but a demolition."""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return out.refuse(REFUSE_STALE_PROJECT_REF)
	if _purpose[row] != PURPOSE_DEMOLISH:
		return out.refuse(REFUSE_NOT_A_DEMOLITION)
	return out.succeed(_build_count[_type_id[row]])


func close_refund(project_ref: Vector2i) -> OpResult:
	"""Retire a cancelled project once its refund manifest has been placed.

	A cancelled BUILD project also removes the blueprint it was building: a cancelled blueprint is
	not a building. If that removal refuses -- a blueprint that somehow owns rooms -- the project
	stays in PHASE_REFUNDING with its ledger intact and the retry spends nothing.
	"""
	var row: int = _row_of(project_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_PROJECT_REF)
	if _phase[row] != PHASE_REFUNDING:
		return _refuse(REFUSE_WRONG_PHASE)
	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
	if _purpose[row] == PURPOSE_BUILD and _buildings.is_live_building(subject):
		_buildings.set_building_construction(subject, NULL_REF)
		var result: Buildings.OpResult = _buildings.demolish_building(subject)
		if not result.ok:
			_buildings.set_building_construction(subject, project_ref)
			return _refuse(result.error)
	if _purpose[row] == PURPOSE_DEMOLISH and _buildings.is_live_building(subject):
		_buildings.set_building_state(subject, STATE_ACTIVE)
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
	if index < 0 or index >= _bill_count_of(_purpose[row], _type_id[row]):
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
		if _subject_slot[row] == subject_ref.x and _subject_generation[row] == subject_ref.y:
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
	if _purpose[row] == PURPOSE_FURNITURE:
		return _buildings.is_live_furniture(subject)
	return _buildings.is_live_building(subject)


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
	out.append_array(var_to_bytes(PackedInt64Array([_live_count])))
	return out


func _refuse(code: StringName) -> OpResult:
	"""One refused outcome: no value, the null reference, and the code that explains it."""
	return OpResult.new(false, code, 0, NULL_REF)
