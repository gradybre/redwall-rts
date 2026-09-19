extends RefCounted
## Inventory lots, containers, and all-or-nothing inventory transactions.
##
## GDD §4.2 fixes the two row shapes this module owns:
##   InventoryContainer: owner: EntityRef, max_mass_g: int64, filters: bitset 64,
##                       reserved_mass_g: int64, policy: enum, reachable: bool
##   InventoryLot:       item_id: int32, quantity_milli: int64, reserved_milli: int64,
##                       quality: int32, age_milli_hours: int64, age_remainder: int64,
##                       provenance: enum, recipe_id: int32, container: EntityRef
## At most 16384 live lots; at most 101376 containers (ARCH-MEM-002); split/merge only by
## identical attributes.
##
## INTEGER ONLY. Every authoritative quantity is `quantity_milli` where 1000 = one catalog unit
## (BAL-NUM-001, ARCH-AUTH-003). Nothing here is a float and nothing here compares with an
## epsilon: the prototype's `economy_system.gd` needed SPEND_TOLERANCE only because float
## accumulation drifts, and exact integers have no such drift to absorb.
##
## Three invariants drive the whole design.
##
## 1. ALL-OR-NOTHING (GDD §4.2, BAL-SAFE-005). Every public mutator validates completely before
##    it writes anything, so a single operation can never half-apply. Multi-step sequences are
##    covered by an explicit transaction: begin(), a sequence of operations, commit(). Any
##    refusal inside an open transaction poisons it; every later operation then refuses without
##    touching state, and commit() rolls the whole sequence back and reports the first refusal.
##    Rollback replays a pre-image journal in reverse, restoring authoritative state byte for
##    byte -- see state_bytes().
##
## 2. CONSERVATION. Quantity enters only through create_lot() (a source) and leaves only
##    through sink_lot_quantity()/consume_reserved() (sinks), both of which are counted per
##    item. Moves, splits and merges are quantity-neutral by construction. audit() re-derives
##    the identity `live + sunk == sourced` from the row columns rather than trusting a running
##    total.
##
## 3. CAPACITY IS CHARGED PER LOT, AND REFUSAL IS EXPLICIT. BAL-NUM-001 and BAL-SAFE-002 give
##    the container rule as `sum(ceil_div(q*m,1000)) + reserved_mass <= max_mass`, with the
##    ceiling taken per lot and never on a summed total, so splitting cannot manufacture free
##    carrying capacity (BAL-SAFE-016). An over-capacity operation returns CAPACITY_EXCEEDED;
##    no quantity is ever silently clamped to fit.
##
## 4. A NULL CONTAINER IS AN EQUIPPED RECORD, AND NOTHING ELSE (decision 0061; ruling
##    `2026-09-09_ready06_open_item_answers.md` §4; READY_07 §7.2 step 5). GDD §4.2 gives a lot a
##    `container: EntityRef`, and ARCH-STATE-001 keeps the SAME indivisible quantity-1000 lot and
##    its GearInstance alive while equipped. So an equipped lot's container is the null ref
##    `(-1, 0)` -- and that is the ONLY thing a null container is ever allowed to mean.
##
##    THE DOUBLE COUNT IS UNREPRESENTABLE, NOT MERELY TESTED. `_l_container_slot[slot]` is one
##    field with one value. A lot is either threaded into exactly one container's intrusive list,
##    where it charges that container's used mass and counts as loose stock, or it carries
##    NULL_SLOT, is in no list at all, and counts as equipped. Container mass is only ever
##    credited through link/unlink, and `total_loose_milli()` is `total_live_milli()` minus
##    `total_equipped_milli()` by construction, so no arrangement of these columns can make one
##    lot contribute to both loose stock and a container -- or to equipped mass and storage.
##    `audit()` re-derives every container's mass from its list, which an equipped lot is not in.
##
##    AND THE NULL CONTAINER MUST BE PROVED, NOT ASSUMED. This module has no idea what gear is,
##    so it does not decide: it demands a proof from a bound EQUIPMENT AUTHORITY -- `gear.gd` --
##    whose `is_equipped_record(lot_ref)` answers true only for a live GearInstance flagged
##    equipped whose recorded owner is a live resident. `detach_lot_to_equipment()` refuses
##    unless the authority attests; `attach_equipped_lot()` refuses unless it STOPS attesting,
##    which is what makes "equipped and also shelved" unreachable from either door; and
##    `audit()` re-checks the biconditional for every live lot, so an orphaned null-container lot
##    -- an owner who died, an authority unbound -- is a refusal and not a silent hole. Nothing
##    here was weakened to admit a null container: create_lot() still requires a live container,
##    and split/merge/move/transfer/sink/reserve all refuse an equipped lot outright.
##
## 5. AGE IS WRITTEN HERE AND DECIDED ELSEWHERE (ARCH-SYS-004; GDD §5.8 REQ-SET-107–108).
##    `advance_lot_age_hour_into()` folds one game hour of effective storage age into the two
##    age columns, and `transform_lot_item_into()` performs §5.8's spoilage conversion on the
##    SAME row. Neither knows what a store factor, a season or a shelf life is: `stock_age.gd`
##    supplies the two already-chosen factors and the already-resolved outcome item, because an
##    inventory that decided them would be holding a copy of the food rules.
##
##    AN EQUIPPED LOT IS NOT AGED, AND BOTH MUTATORS REFUSE ONE WITH `LOT_EQUIPPED`. §5.8
##    defines age as EFFECTIVE STORAGE age through a store factor, and it names every non-store
##    case it covers -- prepared food left on tables takes the open-pile factor, and §5.9's
##    ground piles take 1500 -- without naming equipment. A lot held as equipment is therefore
##    in no store and HAS no factor, so aging it would be inventing one. That the GDD does not
##    decide this is a NAMED GAP, not a choice made here; `test_stock_age.gd` pins why it is
##    currently unobservable, and `stock_age.gd`'s header states the gap in full.
##
## 6. AN OVER-SHELF-LIFE SEED IS ADMITTED TO NO CONSUMER (STOCK-SEED-R01; decisions 0093, 0059).
##    The ruling splits one rule across two modules: `stock_age.gd` owns the PREDICATE
##    `refuses_seed_consumption(lot_ref)`, derived from persisted age and the item definition,
##    and this module owns ENFORCEMENT for quantity admission. Six admission paths ask it --
##    a new reservation, an unreserved withdrawal, the commit of an existing claim, a transfer,
##    a whole-lot move and a split -- plus the in-place transform, and each asks AGAIN every
##    time, so no verdict from an earlier tick can be replayed at commit.
##
##    NO SHELF LIFE IS COMPUTED HERE. This store knows an item's mass and category; it does not
##    know what a seed is, what a shelf hour is, or how the two compare. A second copy of that
##    comparison could disagree with the first, so the guard delegates and never duplicates.
##
##    ITS OWN CLEANUP STAYS POSSIBLE. Release/cancellation and the declared expiry
##    transform/sink remain permitted through one narrow, single-use CLEANUP DECLARATION set by
##    `release_all_reservations()` inside an open explicit transaction -- the ruling's own
##    invalidation step, which every declared-expiry sequence starts with. See the guard's
##    section comment for why that is the only shape that tells disposal from consumption.
##
## 7. PROVENANCE IS ADMITTED ONCE AND CARRIED EVERYWHERE (PROV-R01, decision 0113). The domain
##    check runs at create_lot(), the ONLY door that writes `_l_provenance` from a caller's
##    argument; every other path copies an already-admitted value from an existing row, so no
##    operation can launder an invalid origin in through a side door. What that means per
##    operation, which is the ruling's own list: split_lot() and transfer() pass
##    `_l_provenance[source]` into _write_new_lot() unchanged; move_lot() and
##    gear's detach/attach never touch the column at all; a cancelled reservation and a poisoned
##    transaction restore it from the journal pre-image byte for byte; merge_lots() requires
##    EQUALITY of provenance and refuses ATTRIBUTE_MISMATCH otherwise, so two origins can never
##    be averaged into one; and transform_lot_item_into() -- §5.8 spoilage -- CARRIES the origin
##    as history onto the new item while the new ITEM IDENTITY decides eligibility, so spoilage
##    manufactures no coastal or virgin-source entitlement.
##
## 8. CONTAINER ENUMERATION BY OWNER IS A BOUNDED SCAN, AND NEVER A SAVED INDEX (INV-GOODS-R01).
##    `containers_by_owner_into()` walks the finite container rows and writes the complete
##    INVENTORY-CONTAINER refs whose complete stored DIRECTORY owner pair equals the requested
##    one. THOSE ARE TWO DIFFERENT REFERENCE DOMAINS and this query is the boundary between them:
##    what goes in is a directory `(slot, generation)`, what comes out is an inventory-container
##    `(slot, generation)`, and neither is ever validated as the other. Nothing is persisted. The
##    ruling authorizes the scan and nothing more, because a saved reverse index is state that
##    must be advanced on every create/destroy and rebuilt on every load, and this is a cold
##    destructive path that runs once per demolition request.
##
##    A MISSING OWNER IS NOT AN EMPTY RESULT. `create_container()` writes the owner pair it is
##    handed WITHOUT validating it against the directory -- this module does not own the
##    directory and says so -- so the null ref `(-1, 0)` and a zero generation are real residue
##    in `_c_owner_slot`/`_c_owner_generation`, and answering a malformed owner with "every
##    container nobody owns" would read exactly like a proof that nothing is stored there. So a
##    malformed owner REFUSES, an undersized output REFUSES WITHOUT TRUNCATING, and the visible
##    count is zeroed on both. Only a complete scan for a well-formed owner may report 0.
##
##    IT PROVES OWNERSHIP AND NOT CONTAINMENT. Equality with a Building ref says a container is
##    keyed to that Building; it says nothing about what physically stands inside its footprint,
##    because a container row carries no position at all. The demolition gate that needs
##    containment is `settlement_system.gd::request_demolition()`, and it refuses.
##
## ARCH-MEM-001: every column is a packed array allocated once in _init(). No GDScript Array is
## allocated per row; a container's lots are an intrusive doubly linked list threaded through
## two packed lot columns, not a per-container child array.
##
## BLOCKERS. U4 (task 02 §"Unresolved contracts") leaves reservation *indexing* unspecified:
## 32768 Reservation rows against 8192 Job rows is exactly 4x, implying an owner-major
## `job*4+i` layout that neither document states and that would cap a recipe at four input
## lots. U5 budgets no allocator storage for non-directory child stores. So the Reservation row
## store (job, lot, quantity_milli, expiry, purpose) is NOT built here. What IS specified --
## GDD §4.2's per-lot `reserved_milli` with "total per lot <= quantity" -- is implemented, with
## a cancellation path that releases it exactly. See reserve_lot() for where the row store
## attaches once U4 and U5 are resolved.
##
## ALLOCATION (task 2.7, decision 0015). A public operation allocates EXACTLY ONE OpResult,
## built by _leave() as the call returns. Nothing inside allocates: internal helpers signal
## success or refusal with a StringName refusal code (REFUSE_NONE means success), carry a
## produced integer in the reused `_math` scratch, and record a completed operation's ref and
## value in `_out_ref`/`_out_value`. This is NOT a sentinel scheme: the refusal code and the
## value travel on separate channels, a refusal never leaves a usable-looking number behind
## (IntResult.refuse() zeroes the value, and _leave() builds a refusal result that carries
## NULL_REF and 0), and no arithmetic here can be decided on a value that does not exist. That
## is the H4 rule -- never encode a refusal INSIDE the value channel -- and it still holds.
##
## ALIASING. `_math`, `_plan`, `_out_ref` and `_out_value` are single reused instances/fields.
## This module emits no signal anywhere and calls out to a collaborator in exactly two places --
## the equipment attestation and STOCK-SEED-R01's seed-expiry query -- and NEITHER is made while
## one of those holds a live value: both are asked before anything is costed. `_attesting` is
## raised across both, so `_guard()` refuses any mutator an authority re-enters with, and a
## caller can never hold two of these at once because the only object that escapes is the
## freshly built OpResult. Within the module the rule is: copy `_math.value` into a local
## before the next call.
##
## Container refs use the GDD §4.1 `(slot, generation)` pair carried as Vector2i with the null
## ref `(-1, 0)`, matching entity_directory.gd, but this module allocates its own slots. Wiring
## lots and containers into the global directory (ARCH-ID-001 gives both a directory entry) is
## a separate integration step and is not part of task 2.5.

const IntMath := preload("res://scripts/core/int_math.gd")
## PROV-R01's protected InventoryProvenance domain. Read, never mirrored: this module
## publishes no provenance number of its own, so there is exactly one copy of each.
const CatalogScript := preload("res://scripts/core/catalog.gd")

const NULL_SLOT: int = -1
const NULL_GENERATION: int = 0
const NULL_REF: Vector2i = Vector2i(NULL_SLOT, NULL_GENERATION)
const MAX_INT32: int = 2147483647

## Spec capacities. ARCH-MEM-002: 101376 main containers, GDD §4.2: 16384 live lots,
## ARCH-STATE-004: at most 256 compiled ItemDefinition keys.
const CONTAINER_CAPACITY: int = 101376
const LOT_CAPACITY: int = 16384
const ITEM_CAPACITY: int = 256

## Milli-units per catalog unit (BAL-NUM-001).
const MILLI_PER_UNIT: int = 1000

## GDD §5.8's aging divisor: "Effective age per hour=floor(store_factor*temperature_factor/1000),
## retaining tick fractions". It is 1000 because BOTH factors are per-mille of the base 1000
## milli-hours an hour costs at store factor 1000 in an unmodified season -- it is NOT
## `MILLI_PER_UNIT`, which happens to share the number while meaning milli-units per catalog
## unit. Aliasing the two would make a later change to either silently change the other.
const AGE_FACTOR_DENOMINATOR: int = 1000

## Category bits available in the 64-bit `filters` mask (ARCH-STATE-004).
const CATEGORY_COUNT: int = 64
## Filters value admitting every category. Arithmetic shift keeps every bit set.
const FILTERS_ACCEPT_ALL: int = -1

## PROVENANCE IS A CLOSED PROTECTED DOMAIN (PROV-R01, decision 0113). It was opaque until
## 2026-09-12: GDD §4.3 did not number it, so this module treated `_l_provenance` as an
## arbitrary int32 it compared for equality and nothing more. PROV-R01 froze the complete
## six-member InventoryProvenance domain with explicit numbers, so `-1`, `6`, INT32_MAX and
## every other arbitrary value are now REFUSED at the one door that writes the column.
##
## THIS MODULE STILL PUBLISHES NO PROVENANCE NUMBER. The members live in `catalog.gd`, which
## owns the protected table and the artifact digest; every value named here is read from there.
## What inventory owns is ADMISSION to its own column and PRESERVATION across every operation.
##
## Container policy remains genuinely opaque: §4.3 numbers no policy enum, BAL-CAT-001 compiles
## it from sorted ASCII keys and no ruling has closed it, so `_c_policy` keeps the old
## equality-only treatment and UNSET_POLICY keeps its sentinel wording. That asymmetry is
## deliberate; do not "tidy" it by inventing a policy domain that no contract states.
##
## `UNSET_PROVENANCE` is the COMPATIBILITY SPELLING for ORDINARY and is no longer a sentinel:
## PROV-R01 says "The old `UNSET_PROVENANCE=0` is a compatibility spelling for ORDINARY, not a
## seventh member and not an unknown numeric wildcard." A cleared column therefore holds a real,
## valid member meaning ordinary harvest/freshwater/crafted origin -- which grants no privilege,
## and in particular "does not prove coastal collection or a virgin source".
const UNSET_PROVENANCE: int = CatalogScript.PROVENANCE_ORDINARY
## Container policy is still an opaque compiled enum; this is a genuine unset-field sentinel.
const UNSET_POLICY: int = 0

## Largest storage age that can still be rounded up to a whole hour without overflowing int64
## (ceil_div adds MILLI_PER_UNIT - 1 before dividing). Beyond it, the age is refused outright.
const MAX_AGE_MILLI_HOURS: int = 9223372036854774808

## Undo journal. A transaction is bounded work, so the arena is fixed and an operation that
## cannot fit refuses rather than growing it.
const JOURNAL_CAPACITY: int = 4096
const MAX_JOURNAL_PER_OP: int = 16
const ROW_STRIDE: int = 14

const _J_LOT: int = 0
const _J_CONTAINER: int = 1
const _J_LOT_FREE_CELL: int = 2
const _J_CONTAINER_FREE_CELL: int = 3
const _J_SOURCED: int = 4
const _J_SUNK: int = 5

## Lot pre-image field offsets inside the journal arena.
const LOT_F_ITEM: int = 0
const LOT_F_QUALITY: int = 1
const LOT_F_PROVENANCE: int = 2
const LOT_F_RECIPE: int = 3
const LOT_F_CONTAINER_SLOT: int = 4
const LOT_F_CONTAINER_GEN: int = 5
const LOT_F_GENERATION: int = 6
const LOT_F_LIVE: int = 7
const LOT_F_NEXT: int = 8
const LOT_F_PREV: int = 9
const LOT_F_QUANTITY: int = 10
const LOT_F_RESERVED: int = 11
const LOT_F_AGE: int = 12
const LOT_F_AGE_REMAINDER: int = 13

## Container pre-image field offsets inside the journal arena.
const CON_F_OWNER_SLOT: int = 0
const CON_F_OWNER_GEN: int = 1
const CON_F_POLICY: int = 2
const CON_F_GENERATION: int = 3
const CON_F_LIVE: int = 4
const CON_F_LOT_COUNT: int = 5
const CON_F_FIRST_LOT: int = 6
const CON_F_MAX_MASS: int = 7
const CON_F_FILTERS: int = 8
const CON_F_RESERVED_MASS: int = 9
const CON_F_USED_MASS: int = 10
const CON_F_REACHABLE: int = 11

## Refusal codes. Every refusal is explicit and named; nothing is clamped into a plausible
## looking success (ARCH-ID-004 style `CAPACITY_<STORE>` for the two row stores).
const REFUSE_NONE: StringName = &""
const REFUSE_CAPACITY_EXCEEDED: StringName = &"CAPACITY_EXCEEDED"
const REFUSE_CAPACITY_INVENTORY_LOT: StringName = &"CAPACITY_INVENTORY_LOT"
const REFUSE_CAPACITY_INVENTORY_CONTAINER: StringName = &"CAPACITY_INVENTORY_CONTAINER"
const REFUSE_INVALID_LOT: StringName = &"INVALID_LOT"
const REFUSE_INVALID_CONTAINER: StringName = &"INVALID_CONTAINER"
const REFUSE_UNKNOWN_ITEM: StringName = &"UNKNOWN_ITEM"
const REFUSE_ITEM_FILTERED: StringName = &"ITEM_FILTERED"
const REFUSE_INVALID_QUANTITY: StringName = &"INVALID_QUANTITY"
const REFUSE_INSUFFICIENT_UNRESERVED: StringName = &"INSUFFICIENT_UNRESERVED"
const REFUSE_INSUFFICIENT_RESERVED: StringName = &"INSUFFICIENT_RESERVED"
const REFUSE_RESERVED_EXCEEDS_QUANTITY: StringName = &"RESERVED_EXCEEDS_QUANTITY"
const REFUSE_ATTRIBUTE_MISMATCH: StringName = &"ATTRIBUTE_MISMATCH"
const REFUSE_AGE_MISMATCH: StringName = &"AGE_MISMATCH"
const REFUSE_SAME_LOT: StringName = &"SAME_LOT"
const REFUSE_SAME_CONTAINER: StringName = &"SAME_CONTAINER"
const REFUSE_DIFFERENT_CONTAINER: StringName = &"DIFFERENT_CONTAINER"
const REFUSE_CONTAINER_NOT_EMPTY: StringName = &"CONTAINER_NOT_EMPTY"
const REFUSE_CONTAINER_HAS_RESERVED_MASS: StringName = &"CONTAINER_HAS_RESERVED_MASS"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_TRANSACTION_POISONED: StringName = &"TRANSACTION_POISONED"
const REFUSE_NESTED_TRANSACTION: StringName = &"NESTED_TRANSACTION"
const REFUSE_NO_TRANSACTION: StringName = &"NO_TRANSACTION"
const REFUSE_JOURNAL_FULL: StringName = &"JOURNAL_FULL"
const REFUSE_ITEM_ALREADY_REGISTERED: StringName = &"ITEM_ALREADY_REGISTERED"
const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
const REFUSE_INVALID_MASS: StringName = &"INVALID_MASS"
const REFUSE_INVALID_CATEGORY: StringName = &"INVALID_CATEGORY"
const REFUSE_TRANSACTION_OPEN: StringName = &"TRANSACTION_OPEN"
const REFUSE_GENERATION_EXHAUSTED: StringName = &"GENERATION_EXHAUSTED"
const REFUSE_AUDIT_MASS: StringName = &"AUDIT_MASS_MISMATCH"
const REFUSE_AUDIT_RESERVED: StringName = &"AUDIT_RESERVED_EXCEEDS_QUANTITY"
const REFUSE_AUDIT_CONSERVATION: StringName = &"AUDIT_CONSERVATION_BROKEN"
const REFUSE_AUDIT_LOT_COUNT: StringName = &"AUDIT_LOT_COUNT_MISMATCH"
const REFUSE_AUDIT_CAPACITY: StringName = &"AUDIT_CAPACITY_EXCEEDED"
const REFUSE_LOT_EQUIPPED: StringName = &"LOT_EQUIPPED"
const REFUSE_LOT_NOT_EQUIPPED: StringName = &"LOT_NOT_EQUIPPED"
const REFUSE_LOT_HAS_RESERVATION: StringName = &"LOT_HAS_RESERVATION"
const REFUSE_NO_EQUIPMENT_AUTHORITY: StringName = &"NO_EQUIPMENT_AUTHORITY"
const REFUSE_INVALID_EQUIPMENT_AUTHORITY: StringName = &"INVALID_EQUIPMENT_AUTHORITY"
const REFUSE_NOT_AN_EQUIPPED_RECORD: StringName = &"NOT_AN_EQUIPPED_RECORD"
const REFUSE_STILL_AN_EQUIPPED_RECORD: StringName = &"STILL_AN_EQUIPPED_RECORD"
const REFUSE_EQUIPPED_LOTS_LIVE: StringName = &"EQUIPPED_LOTS_LIVE"
const REFUSE_INSUFFICIENT_RESERVED_MASS: StringName = &"INSUFFICIENT_RESERVED_MASS"
const REFUSE_ATTESTATION_REENTRY: StringName = &"ATTESTATION_REENTRY"
const REFUSE_AUDIT_ORPHAN_LOT: StringName = &"AUDIT_ORPHAN_LOT"
const REFUSE_AUDIT_EQUIPPED_COUNT: StringName = &"AUDIT_EQUIPPED_COUNT_MISMATCH"
const REFUSE_AUDIT_LOT_CYCLE: StringName = &"AUDIT_LOT_LIST_CYCLE"
## ARCH-SYS-004 StockAge additions. An aging factor is a GDD §5.8 table value and is never
## negative; an age that can no longer be rounded up to a whole hour refuses rather than being
## stored, because `_age_hours_ceil_into()` would then refuse for every later merge instead.
const REFUSE_INVALID_AGE_FACTOR: StringName = &"INVALID_AGE_FACTOR"
const REFUSE_AGE_LIMIT_REACHED: StringName = &"AGE_LIMIT_REACHED"
const REFUSE_SAME_ITEM: StringName = &"SAME_ITEM"

## PROV-R01: a lot value outside the six published InventoryProvenance members is refused, not
## stored and not reinterpreted. It is its own code rather than OVERFLOW because `6` and `-1`
## fit an int32 perfectly well and are still not origins; conflating the two would let a reader
## conclude that only magnitude was the problem.
const REFUSE_INVALID_PROVENANCE: StringName = &"INVALID_PROVENANCE"

## The single method name an equipment authority must publish. Duck typed on purpose: `gear.gd`
## preloads this module, so this module must not preload `gear.gd` back.
const EQUIPMENT_ATTESTATION_METHOD: StringName = &"is_equipped_record"

## STOCK-SEED-R01 refusals. A seed lot whose persisted age has reached its catalog shelf
## threshold may not be reserved, withdrawn, committed, transferred, moved, split or
## transformed into anything a consumer asked for. The threshold itself is NOT computed here:
## `stock_age.gd` owns that arithmetic and this module owns admission.
const REFUSE_SEED_PAST_SHELF_LIFE: StringName = &"SEED_PAST_SHELF_LIFE"
const REFUSE_INVALID_SEED_EXPIRY_AUTHORITY: StringName = &"INVALID_SEED_EXPIRY_AUTHORITY"

## The single method name a seed-expiry authority must publish, duck typed for the same reason
## as EQUIPMENT_ATTESTATION_METHOD: `stock_age.gd` preloads this module, so this module cannot
## preload `stock_age.gd` back and cannot name its type.
const SEED_EXPIRY_ATTESTATION_METHOD: StringName = &"refuses_seed_consumption"

## INV-GOODS-R01's two enumeration refusals. Both are refusals of the QUESTION, not reports of an
## empty store, and both zero the count so an ignored `false` cannot surface 0 as an answer.
## A malformed owner is refused rather than matched against the unvalidated owner residue
## `create_container()` is free to write; an output buffer too small for the complete result is
## refused rather than filled to its brim, because a truncated list of stranded goods is exactly
## the shape of evidence that would let a destructive edit through.
const REFUSE_INVALID_OWNER_REF: StringName = &"INVALID_OWNER_REF"
const REFUSE_OWNER_OUTPUT_TOO_SMALL: StringName = &"OWNER_OUTPUT_TOO_SMALL"


class OpResult:
	"""Outcome of one inventory operation: success flag, refusal code, produced ref and value.

	`.ok` MUST be inspected before `.ref` or `.value` is used. A refusal never carries a
	partially applied effect.
	"""
	var ok: bool
	var error: StringName
	var ref: Vector2i
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_ref: Vector2i, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		ref = p_ref
		value = p_value


class TransferPlan:
	"""Validated, fully costed description of one transfer, produced before any state changes.

	A single reused instance lives on the inventory so planning a transfer allocates nothing.
	"""
	var source_slot: int = NULL_SLOT
	var dest_container: int = NULL_SLOT
	var target_slot: int = NULL_SLOT
	var quantity_milli: int = 0
	var source_delta_g: int = 0
	var dest_delta_g: int = 0
	var source_emptied: bool = false
	## Already-checked age the merge target adopts, so _apply_transfer() computes nothing.
	var target_age_milli_hours: int = 0


# Container columns (ARCH-MEM-001: separate contiguous packed columns, allocated once).
var _c_owner_slot: PackedInt32Array = PackedInt32Array()
var _c_owner_generation: PackedInt32Array = PackedInt32Array()
var _c_policy: PackedInt32Array = PackedInt32Array()
var _c_generation: PackedInt32Array = PackedInt32Array()
var _c_lot_count: PackedInt32Array = PackedInt32Array()
var _c_first_lot: PackedInt32Array = PackedInt32Array()
var _c_max_mass_g: PackedInt64Array = PackedInt64Array()
var _c_filters: PackedInt64Array = PackedInt64Array()
var _c_reserved_mass_g: PackedInt64Array = PackedInt64Array()
# Maintained sum of the per-lot ceil debits held by the container. audit() re-derives it.
var _c_used_mass_g: PackedInt64Array = PackedInt64Array()
var _c_live: PackedByteArray = PackedByteArray()
var _c_reachable: PackedByteArray = PackedByteArray()

# Lot columns.
var _l_item_id: PackedInt32Array = PackedInt32Array()
var _l_quality: PackedInt32Array = PackedInt32Array()
var _l_provenance: PackedInt32Array = PackedInt32Array()
var _l_recipe_id: PackedInt32Array = PackedInt32Array()
var _l_container_slot: PackedInt32Array = PackedInt32Array()
var _l_container_generation: PackedInt32Array = PackedInt32Array()
var _l_generation: PackedInt32Array = PackedInt32Array()
var _l_next: PackedInt32Array = PackedInt32Array()
var _l_prev: PackedInt32Array = PackedInt32Array()
var _l_quantity_milli: PackedInt64Array = PackedInt64Array()
var _l_reserved_milli: PackedInt64Array = PackedInt64Array()
var _l_age_milli_hours: PackedInt64Array = PackedInt64Array()
var _l_age_remainder: PackedInt64Array = PackedInt64Array()
var _l_live: PackedByteArray = PackedByteArray()

# Free-slot stacks. A stack, not the directory's min-heap, because push/pop of the same value
# restores the array exactly, which is what byte-identical rollback requires.
var _c_free: PackedInt32Array = PackedInt32Array()
var _l_free: PackedInt32Array = PackedInt32Array()
var _c_free_count: int = 0
var _l_free_count: int = 0
var _c_live_count: int = 0
var _l_live_count: int = 0
var _c_capacity: int = 0
var _l_capacity: int = 0

# Catalog-time item facts. Not simulation state: registration is refused while a transaction is
# open and is never journaled. Masses are GDD §5.7; the mapping arrives from catalog.gd once
# that module's compiled ItemDefinition domain is wired in.
var _item_mass_g: PackedInt32Array = PackedInt32Array()
var _item_category: PackedInt32Array = PackedInt32Array()
var _item_registered: PackedByteArray = PackedByteArray()

# Conservation ledger, per item id.
var _sourced_milli: PackedInt64Array = PackedInt64Array()
var _sunk_milli: PackedInt64Array = PackedInt64Array()

# Undo journal (scratch, not authoritative state).
var _j_kind: PackedInt32Array = PackedInt32Array()
var _j_index: PackedInt32Array = PackedInt32Array()
var _j_row: PackedInt64Array = PackedInt64Array()
var _j_count: int = 0

var _tx_open: bool = false
var _tx_poisoned: bool = false
var _tx_error: StringName = REFUSE_NONE
var _tx_saved_c_free_count: int = 0
var _tx_saved_l_free_count: int = 0
var _tx_saved_c_live_count: int = 0
var _tx_saved_l_live_count: int = 0
var _tx_saved_equipped_count: int = 0

var _plan: TransferPlan = TransferPlan.new()

## The store that can prove a null-container lot is an equipped record with a live owner. Not
## simulation state and not journaled: it is a wiring reference, like `residents.gd`'s directory.
var _equipment_authority: Object = null
## Live lots whose container is the null ref. Derived from the columns, maintained like the live
## counts and restored the same way on rollback; `audit()` re-derives it.
var _equipped_lot_count: int = 0
## True only while an authority call is running -- the equipment attestation or STOCK-SEED-R01's
## seed-expiry query. `_guard()` refuses every mutator while it is set, so an authority that
## tries to re-enter this module cannot half-apply an operation.
var _attesting: bool = false

## STOCK-SEED-R01's seed-consumer eligibility authority: the object publishing
## `refuses_seed_consumption(lot_ref) -> bool`. `stock_age.gd` is the real one. Wiring, not
## simulation state: not journaled, absent from state_bytes(), and it survives clear().
## STOCK-C4-LIFETIME-R01: BORROWED, therefore held WEAKLY. `settlement_system.gd` owns both
## objects and `stock_age.gd` already holds this store strongly, so a strong edge back would
## close an ownership cycle neither side can break. Still not journaled, still not saved state.
var _seed_expiry_authority: WeakRef = null
## Cleanup declaration, in the INVENTORY LOT generation namespace (never the container one).
## `release_all_reservations()` sets `_tx_cleanup_lot`; the next operation inside the SAME
## explicit transaction picks it up in `_op_cleanup_lot` and clears the pending one, so a
## declaration is good for exactly one following step and never crosses a transaction. This is
## how the ruling's permitted "declared expiry transform/sink" is told apart from a consumer
## helping itself. Transaction scratch: not journaled, not in state_bytes().
var _tx_cleanup_lot: Vector2i = NULL_REF
var _op_cleanup_lot: Vector2i = NULL_REF

# Task 2.7 scratch. Not simulation state: rollback and state_bytes() both ignore these.
## Checked-arithmetic scratch shared by every internal helper. A helper that produces one
## integer leaves it here; its caller copies `_math.value` into a local before the next call.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## Ref and value of the last successful `_*_checked()` operation. Read only by _leave(), which
## turns them into the single OpResult a public call returns.
var _out_ref: Vector2i = NULL_REF
var _out_value: int = 0
## audit()'s per-item live tally, allocated once with the other columns (ARCH-MEM-005) and
## refilled rather than rebuilt on each audit.
var _audit_live_milli: PackedInt64Array = PackedInt64Array()
## One past the highest slot either store has ever handed out. NOT authoritative state and
## NOT a count of live rows: it is a conservative upper bound on where a live row can be,
## which lets the diagnostic walks below scan occupancy instead of capacity. Every live row
## was allocated, so no live row sits at or above it. It only grows within a run -- a
## rollback that un-allocates a slot leaves it high, which is still a correct bound -- it is
## never journaled, and state_bytes() excludes it, because two byte images of identical
## authoritative state must not differ over a scan hint.
var _c_slot_high_water: int = 0
var _l_slot_high_water: int = 0

## Why the last `copy_canonical_columns_into()` or `restore_canonical_columns()` refused
## (INV-CANON-R01). Diagnostic scratch, never journaled and absent from state_bytes(): a save
## boundary is not a public mutator and has no OpResult to carry, so the refusal reason travels
## here beside the `false` rather than inside a value channel.
var _canonical_detail: String = ""


func _init(p_container_capacity: int = CONTAINER_CAPACITY, p_lot_capacity: int = LOT_CAPACITY) -> void:
	"""Allocate every column once at the requested capacities.

	Defaults are the specification bounds. A smaller capacity may be requested by a test or a
	bounded harness; a larger one is clamped down, because the memory ledger fixes the maxima.
	"""
	_c_capacity = clampi(p_container_capacity, 1, CONTAINER_CAPACITY)
	_l_capacity = clampi(p_lot_capacity, 1, LOT_CAPACITY)
	_allocate_container_columns()
	_allocate_lot_columns()
	_allocate_shared_columns()
	clear()


func _allocate_container_columns() -> void:
	"""Size every container column to the container capacity, once."""
	_c_owner_slot.resize(_c_capacity)
	_c_owner_generation.resize(_c_capacity)
	_c_policy.resize(_c_capacity)
	_c_generation.resize(_c_capacity)
	_c_lot_count.resize(_c_capacity)
	_c_first_lot.resize(_c_capacity)
	_c_max_mass_g.resize(_c_capacity)
	_c_filters.resize(_c_capacity)
	_c_reserved_mass_g.resize(_c_capacity)
	_c_used_mass_g.resize(_c_capacity)
	_c_live.resize(_c_capacity)
	_c_reachable.resize(_c_capacity)
	_c_free.resize(_c_capacity)


func _allocate_lot_columns() -> void:
	"""Size every lot column to the lot capacity, once."""
	_l_item_id.resize(_l_capacity)
	_l_quality.resize(_l_capacity)
	_l_provenance.resize(_l_capacity)
	_l_recipe_id.resize(_l_capacity)
	_l_container_slot.resize(_l_capacity)
	_l_container_generation.resize(_l_capacity)
	_l_generation.resize(_l_capacity)
	_l_next.resize(_l_capacity)
	_l_prev.resize(_l_capacity)
	_l_quantity_milli.resize(_l_capacity)
	_l_reserved_milli.resize(_l_capacity)
	_l_age_milli_hours.resize(_l_capacity)
	_l_age_remainder.resize(_l_capacity)
	_l_live.resize(_l_capacity)
	_l_free.resize(_l_capacity)


func _allocate_shared_columns() -> void:
	"""Size the item registry, the conservation ledger and the undo journal, once."""
	_item_mass_g.resize(ITEM_CAPACITY)
	_item_category.resize(ITEM_CAPACITY)
	_item_registered.resize(ITEM_CAPACITY)
	_sourced_milli.resize(ITEM_CAPACITY)
	_sunk_milli.resize(ITEM_CAPACITY)
	_j_kind.resize(JOURNAL_CAPACITY)
	_j_index.resize(JOURNAL_CAPACITY)
	_j_row.resize(JOURNAL_CAPACITY * ROW_STRIDE)
	_audit_live_milli.resize(ITEM_CAPACITY)


func clear() -> void:
	"""Return every store to its empty state by refilling the existing buffers.

	Never calls resize(): ARCH-MEM-001 allocates once, and updates must not reallocate.

	Emptying a store is not the same as rewinding it. Both generation columns step FORWARD
	here instead of being refilled with 1, so a lot or container ref taken before the clear
	can never validate against a row handed out after it; see _advance_generations().
	"""
	_clear_container_rows()
	_clear_lot_rows()
	_item_mass_g.fill(0)
	_item_category.fill(0)
	_item_registered.fill(0)
	_sourced_milli.fill(0)
	_sunk_milli.fill(0)
	_j_count = 0
	_tx_open = false
	_tx_poisoned = false
	_tx_error = REFUSE_NONE
	_tx_cleanup_lot = NULL_REF
	_op_cleanup_lot = NULL_REF
	_equipped_lot_count = 0


func _clear_container_rows() -> void:
	"""Reset container columns and refill the free stack so pops ascend from slot 0."""
	_c_owner_slot.fill(NULL_SLOT)
	_c_owner_generation.fill(NULL_GENERATION)
	_c_policy.fill(UNSET_POLICY)
	_c_lot_count.fill(0)
	_c_first_lot.fill(NULL_SLOT)
	_c_max_mass_g.fill(0)
	_c_filters.fill(0)
	_c_reserved_mass_g.fill(0)
	_c_used_mass_g.fill(0)
	_c_live.fill(0)
	_c_reachable.fill(0)
	_advance_generations(_c_generation, _c_capacity)
	_c_free_count = _refill_free_stack(_c_free, _c_generation, _c_capacity)
	_c_live_count = 0
	_c_slot_high_water = 0


func _clear_lot_rows() -> void:
	"""Reset lot columns and refill the free stack so pops ascend from slot 0."""
	_l_item_id.fill(0)
	_l_quality.fill(0)
	_l_provenance.fill(UNSET_PROVENANCE)
	_l_recipe_id.fill(0)
	_l_container_slot.fill(NULL_SLOT)
	_l_container_generation.fill(NULL_GENERATION)
	_l_next.fill(NULL_SLOT)
	_l_prev.fill(NULL_SLOT)
	_l_quantity_milli.fill(0)
	_l_reserved_milli.fill(0)
	_l_age_milli_hours.fill(0)
	_l_age_remainder.fill(0)
	_l_live.fill(0)
	_advance_generations(_l_generation, _l_capacity)
	_l_free_count = _refill_free_stack(_l_free, _l_generation, _l_capacity)
	_l_live_count = 0
	_l_slot_high_water = 0


func _advance_generations(generations: PackedInt32Array, capacity: int) -> void:
	"""Step every slot's generation one past the value it last handed out.

	A generation column refilled with 1 hands the next create the very `(slot, generation)`
	pair a ref taken before the clear still holds, and that ref then reads and mutates an
	unrelated row. Generations only move forward -- on free, and across a clear. A slot whose
	generation is spent is left at its maximum; _refill_free_stack() then keeps it out of the
	pool, so nothing here can wrap an int32 column negative.
	"""
	for slot: int in range(capacity):
		if generations[slot] < MAX_INT32:
			generations[slot] += 1


func _refill_free_stack(stack: PackedInt32Array, generations: PackedInt32Array, capacity: int) -> int:
	"""Rebuild a free stack highest-slot-first and return how many slots it holds.

	The count is returned rather than assumed to be the capacity because a slot whose
	generation is spent is skipped: handing it out again would need a wrapped generation,
	which is the aliasing the generation column exists to prevent.
	"""
	stack.fill(NULL_SLOT)
	var pushed: int = 0
	var slot: int = capacity - 1
	while slot >= 0:
		if generations[slot] < MAX_INT32:
			stack[pushed] = slot
			pushed += 1
		slot -= 1
	return pushed


# --- Item registry (catalog time) ---------------------------------------------------------

func register_item(item_id: int, mass_g: int, category: int) -> OpResult:
	"""Bind an item id to its GDD §5.7 unit mass in grams and its 0..63 filter category.

	Catalog-time only: refused while a transaction is open, and never journaled, because item
	masses are compiled facts rather than simulation state.
	"""
	if _tx_open:
		return _refuse(REFUSE_TRANSACTION_OPEN)
	if item_id < 0 or item_id >= ITEM_CAPACITY:
		return _refuse(REFUSE_INVALID_ITEM_ID)
	if mass_g <= 0:
		return _refuse(REFUSE_INVALID_MASS)
	if category < 0 or category >= CATEGORY_COUNT:
		return _refuse(REFUSE_INVALID_CATEGORY)
	if _item_registered[item_id] == 1:
		return _refuse(REFUSE_ITEM_ALREADY_REGISTERED)
	_item_mass_g[item_id] = mass_g
	_item_category[item_id] = category
	_item_registered[item_id] = 1
	return _ok(NULL_REF, item_id)


func is_item_registered(item_id: int) -> bool:
	"""True when the item id carries a compiled mass and category."""
	if item_id < 0 or item_id >= ITEM_CAPACITY:
		return false
	return _item_registered[item_id] == 1


func item_mass_g(item_id: int) -> int:
	"""Unit mass in grams for a registered item, or 0 when it is unknown."""
	if not is_item_registered(item_id):
		return 0
	return _item_mass_g[item_id]


func item_category(item_id: int) -> int:
	"""Filter category bit index for a registered item, or -1 when it is unknown."""
	if not is_item_registered(item_id):
		return -1
	return _item_category[item_id]


func category_mask(category: int) -> int:
	"""Single-category filters mask, for composing a container's 64-bit filter bitset."""
	if category < 0 or category >= CATEGORY_COUNT:
		return 0
	return 1 << category


# --- Transactions -------------------------------------------------------------------------

func begin() -> OpResult:
	"""Open an explicit multi-operation transaction. Nesting is refused, not silently joined."""
	if _tx_open:
		return _refuse(REFUSE_NESTED_TRANSACTION)
	_open_transaction()
	return _ok(NULL_REF, 0)


func commit() -> OpResult:
	"""Close an explicit transaction.

	A transaction poisoned by an earlier refusal is rolled back in full and the first refusal
	code is returned, so a caller that ignored an intermediate result still cannot half-apply.
	"""
	if not _tx_open:
		return _refuse(REFUSE_NO_TRANSACTION)
	if _tx_poisoned:
		var code: StringName = _tx_error
		_rollback()
		_close_transaction()
		return _refuse(code)
	_j_count = 0
	_close_transaction()
	return _ok(NULL_REF, 0)


func abort() -> void:
	"""Discard an open transaction, restoring state exactly as it stood at begin()."""
	if not _tx_open:
		return
	_rollback()
	_close_transaction()


func is_transaction_open() -> bool:
	"""True while an explicit transaction is accepting operations."""
	return _tx_open


func is_transaction_poisoned() -> bool:
	"""True when an operation in the OPEN transaction refused, so commit() will roll back.

	False whenever no transaction is open: the flag is cleared as the transaction closes, so
	this predicate never reports a poisoning that belongs to a sequence already finished.
	"""
	return _tx_poisoned


func _close_transaction() -> void:
	"""Close the open transaction and clear the poison that belonged to it.

	The flag describes the transaction accepting operations right now. Left raised past
	commit(), abort() or the implicit close in _leave(), it would have a caller asking a
	store with no transaction open and being told one of its operations refused -- true of
	the past, false of the object. _open_transaction() lowering it again at the next begin()
	makes the lie short-lived, not correct.
	"""
	_tx_open = false
	_tx_poisoned = false
	_tx_error = REFUSE_NONE
	_tx_cleanup_lot = NULL_REF


func _open_transaction() -> void:
	"""Reset the journal and record the allocator scalars a rollback must restore.

	`_op_cleanup_lot` is cleared HERE and not in `_close_transaction()`: it is the declaration
	the operation now starting may use, and a transaction that opens fresh has none. Clearing
	it is what stops a cleanup declared before this transaction from licensing a disposal
	inside it.
	"""
	_tx_open = true
	_tx_poisoned = false
	_tx_error = REFUSE_NONE
	_op_cleanup_lot = NULL_REF
	_j_count = 0
	_tx_saved_c_free_count = _c_free_count
	_tx_saved_l_free_count = _l_free_count
	_tx_saved_c_live_count = _c_live_count
	_tx_saved_l_live_count = _l_live_count
	_tx_saved_equipped_count = _equipped_lot_count


func _enter() -> bool:
	"""Open an implicit single-operation transaction unless one is already open.

	Returns true when this operation owns the transaction and must close it in _leave().

	This is also where a pending cleanup declaration becomes THIS operation's: it is taken and
	cleared in one step, so `release_all_reservations()` licenses exactly the step that follows
	it and nothing further. An operation that opens its own transaction starts with none, which
	is what stops a release and a disposal in two separate implicit transactions from adding up
	to the atomic cleanup decision 0059 requires.
	"""
	if _tx_open:
		_op_cleanup_lot = _tx_cleanup_lot
		_tx_cleanup_lot = NULL_REF
		return false
	_open_transaction()
	return true


func _leave(owned: bool, code: StringName) -> OpResult:
	"""Close an implicitly opened transaction and build the one OpResult this call returns.

	`code` is REFUSE_NONE when the operation succeeded, in which case the produced ref and
	value are read from _out_ref/_out_value; on any refusal the result carries NULL_REF and 0,
	so a refusal cannot hand back a stale ref from an earlier successful operation.
	"""
	var failed: bool = code != REFUSE_NONE
	if failed:
		_tx_poisoned = true
		if _tx_error == REFUSE_NONE:
			_tx_error = code
	if owned:
		if failed:
			_rollback()
		else:
			_j_count = 0
		_close_transaction()
	if failed:
		return OpResult.new(false, code, NULL_REF, 0)
	return OpResult.new(true, REFUSE_NONE, _out_ref, _out_value)


func _leave_into(owned: bool, code: StringName, out: IntMath.IntResult) -> bool:
	"""Non-allocating `_leave()`: close the transaction and write the outcome into `out`.

	ARCH-SYS-004 touches every stored lot every game hour, so its two mutators cannot each
	allocate an OpResult per lot. This is the same close as `_leave()` -- same poisoning, same
	rollback, same "a refusal carries no value" rule -- writing into a caller-owned IntResult
	instead of a fresh object. `out.value` carries the produced integer and `out.ref` has no
	analogue: an aging caller already holds the lot ref it passed in.
	"""
	var failed: bool = code != REFUSE_NONE
	if failed:
		_tx_poisoned = true
		if _tx_error == REFUSE_NONE:
			_tx_error = code
	if owned:
		if failed:
			_rollback()
		else:
			_j_count = 0
		_close_transaction()
	if failed:
		return out.refuse(String(code))
	return out.succeed(_out_value)


func _succeed(ref: Vector2i, value: int) -> StringName:
	"""Record a completed operation's outputs for _leave() and return the success code."""
	_out_ref = ref
	_out_value = value
	return REFUSE_NONE


func _guard() -> StringName:
	"""Refuse before touching state: attestation re-entry, a poisoned transaction, a full journal.

	The attestation check comes first because it is the only one that can be true while the
	caller is not this module at all -- an authority re-entering from inside `_attests()`.
	"""
	if _attesting:
		return REFUSE_ATTESTATION_REENTRY
	if _tx_poisoned:
		return REFUSE_TRANSACTION_POISONED
	if _j_count + MAX_JOURNAL_PER_OP > JOURNAL_CAPACITY:
		return REFUSE_JOURNAL_FULL
	return REFUSE_NONE


func _rollback() -> void:
	"""Undo every journaled mutation in reverse order, restoring the pre-transaction state.

	Duplicate pre-images for one row need no de-duplication: replaying backwards ends on the
	earliest snapshot, which is the value the row held when the transaction opened.
	"""
	var i: int = _j_count - 1
	while i >= 0:
		var kind: int = _j_kind[i]
		var index: int = _j_index[i]
		var base: int = i * ROW_STRIDE
		if kind == _J_LOT:
			_restore_lot(index, base)
		elif kind == _J_CONTAINER:
			_restore_container(index, base)
		elif kind == _J_LOT_FREE_CELL:
			_l_free[index] = _j_row[base]
		elif kind == _J_CONTAINER_FREE_CELL:
			_c_free[index] = _j_row[base]
		elif kind == _J_SOURCED:
			_sourced_milli[index] = _j_row[base]
		else:
			_sunk_milli[index] = _j_row[base]
		i -= 1
	_c_free_count = _tx_saved_c_free_count
	_l_free_count = _tx_saved_l_free_count
	_c_live_count = _tx_saved_c_live_count
	_l_live_count = _tx_saved_l_live_count
	_equipped_lot_count = _tx_saved_equipped_count
	_j_count = 0


func _journal_lot(slot: int) -> void:
	"""Snapshot lot row `slot` into the undo journal. Call before mutating any of its columns."""
	var base: int = _j_count * ROW_STRIDE
	_j_kind[_j_count] = _J_LOT
	_j_index[_j_count] = slot
	_j_row[base + LOT_F_ITEM] = _l_item_id[slot]
	_j_row[base + LOT_F_QUALITY] = _l_quality[slot]
	_j_row[base + LOT_F_PROVENANCE] = _l_provenance[slot]
	_j_row[base + LOT_F_RECIPE] = _l_recipe_id[slot]
	_j_row[base + LOT_F_CONTAINER_SLOT] = _l_container_slot[slot]
	_j_row[base + LOT_F_CONTAINER_GEN] = _l_container_generation[slot]
	_j_row[base + LOT_F_GENERATION] = _l_generation[slot]
	_j_row[base + LOT_F_LIVE] = _l_live[slot]
	_j_row[base + LOT_F_NEXT] = _l_next[slot]
	_j_row[base + LOT_F_PREV] = _l_prev[slot]
	_j_row[base + LOT_F_QUANTITY] = _l_quantity_milli[slot]
	_j_row[base + LOT_F_RESERVED] = _l_reserved_milli[slot]
	_j_row[base + LOT_F_AGE] = _l_age_milli_hours[slot]
	_j_row[base + LOT_F_AGE_REMAINDER] = _l_age_remainder[slot]
	_j_count += 1


func _restore_lot(slot: int, base: int) -> void:
	"""Write one journaled lot pre-image back into the lot columns."""
	_l_item_id[slot] = _j_row[base + LOT_F_ITEM]
	_l_quality[slot] = _j_row[base + LOT_F_QUALITY]
	_l_provenance[slot] = _j_row[base + LOT_F_PROVENANCE]
	_l_recipe_id[slot] = _j_row[base + LOT_F_RECIPE]
	_l_container_slot[slot] = _j_row[base + LOT_F_CONTAINER_SLOT]
	_l_container_generation[slot] = _j_row[base + LOT_F_CONTAINER_GEN]
	_l_generation[slot] = _j_row[base + LOT_F_GENERATION]
	_l_live[slot] = _j_row[base + LOT_F_LIVE]
	_l_next[slot] = _j_row[base + LOT_F_NEXT]
	_l_prev[slot] = _j_row[base + LOT_F_PREV]
	_l_quantity_milli[slot] = _j_row[base + LOT_F_QUANTITY]
	_l_reserved_milli[slot] = _j_row[base + LOT_F_RESERVED]
	_l_age_milli_hours[slot] = _j_row[base + LOT_F_AGE]
	_l_age_remainder[slot] = _j_row[base + LOT_F_AGE_REMAINDER]


func _journal_container(slot: int) -> void:
	"""Snapshot container row `slot` into the undo journal, before mutating its columns."""
	var base: int = _j_count * ROW_STRIDE
	_j_kind[_j_count] = _J_CONTAINER
	_j_index[_j_count] = slot
	_j_row[base + CON_F_OWNER_SLOT] = _c_owner_slot[slot]
	_j_row[base + CON_F_OWNER_GEN] = _c_owner_generation[slot]
	_j_row[base + CON_F_POLICY] = _c_policy[slot]
	_j_row[base + CON_F_GENERATION] = _c_generation[slot]
	_j_row[base + CON_F_LIVE] = _c_live[slot]
	_j_row[base + CON_F_LOT_COUNT] = _c_lot_count[slot]
	_j_row[base + CON_F_FIRST_LOT] = _c_first_lot[slot]
	_j_row[base + CON_F_MAX_MASS] = _c_max_mass_g[slot]
	_j_row[base + CON_F_FILTERS] = _c_filters[slot]
	_j_row[base + CON_F_RESERVED_MASS] = _c_reserved_mass_g[slot]
	_j_row[base + CON_F_USED_MASS] = _c_used_mass_g[slot]
	_j_row[base + CON_F_REACHABLE] = _c_reachable[slot]
	_j_count += 1


func _restore_container(slot: int, base: int) -> void:
	"""Write one journaled container pre-image back into the container columns."""
	_c_owner_slot[slot] = _j_row[base + CON_F_OWNER_SLOT]
	_c_owner_generation[slot] = _j_row[base + CON_F_OWNER_GEN]
	_c_policy[slot] = _j_row[base + CON_F_POLICY]
	_c_generation[slot] = _j_row[base + CON_F_GENERATION]
	_c_live[slot] = _j_row[base + CON_F_LIVE]
	_c_lot_count[slot] = _j_row[base + CON_F_LOT_COUNT]
	_c_first_lot[slot] = _j_row[base + CON_F_FIRST_LOT]
	_c_max_mass_g[slot] = _j_row[base + CON_F_MAX_MASS]
	_c_filters[slot] = _j_row[base + CON_F_FILTERS]
	_c_reserved_mass_g[slot] = _j_row[base + CON_F_RESERVED_MASS]
	_c_used_mass_g[slot] = _j_row[base + CON_F_USED_MASS]
	_c_reachable[slot] = _j_row[base + CON_F_REACHABLE]


func _journal_scalar(kind: int, index: int, old_value: int) -> void:
	"""Snapshot one free-stack cell or one conservation counter into the undo journal."""
	var base: int = _j_count * ROW_STRIDE
	_j_kind[_j_count] = kind
	_j_index[_j_count] = index
	_j_row[base] = old_value
	_j_count += 1


# --- Slot allocation ----------------------------------------------------------------------

func _alloc_lot_slot() -> int:
	"""Pop the next free lot slot, or NULL_SLOT when the lot store is full.

	The pop writes no authoritative state, so a rollback restores it by resetting the saved
	free count alone; the high-water mark it raises is a scan bound, not state, and a
	rollback deliberately leaves it raised.
	"""
	if _l_free_count == 0:
		return NULL_SLOT
	_l_free_count -= 1
	var slot: int = _l_free[_l_free_count]
	if slot >= _l_slot_high_water:
		_l_slot_high_water = slot + 1
	return slot


func _free_lot_slot(slot: int) -> void:
	"""Return a lot slot to the free stack, journaling the cell the push overwrites.

	A slot whose generation is exhausted is retired instead of reused, so a stale ref can never
	be revalidated by wrap-around.
	"""
	if _l_generation[slot] >= MAX_INT32:
		return
	_l_generation[slot] += 1
	_journal_scalar(_J_LOT_FREE_CELL, _l_free_count, _l_free[_l_free_count])
	_l_free[_l_free_count] = slot
	_l_free_count += 1


func _alloc_container_slot() -> int:
	"""Pop the next free container slot, or NULL_SLOT when the container store is full."""
	if _c_free_count == 0:
		return NULL_SLOT
	_c_free_count -= 1
	var slot: int = _c_free[_c_free_count]
	if slot >= _c_slot_high_water:
		_c_slot_high_water = slot + 1
	return slot


func _free_container_slot(slot: int) -> void:
	"""Return a container slot to the free stack, journaling the cell the push overwrites."""
	if _c_generation[slot] >= MAX_INT32:
		return
	_c_generation[slot] += 1
	_journal_scalar(_J_CONTAINER_FREE_CELL, _c_free_count, _c_free[_c_free_count])
	_c_free[_c_free_count] = slot
	_c_free_count += 1


# --- Container operations -------------------------------------------------------------------

func create_container(owner_ref: Vector2i, max_mass_g: int, filters: int, policy: int, reachable: bool) -> OpResult:
	"""Create an InventoryContainer row and return its `(slot, generation)` ref."""
	var owned: bool = _enter()
	return _leave(owned, _create_container_checked(owner_ref, max_mass_g, filters, policy, reachable))


func _create_container_checked(owner_ref: Vector2i, max_mass_g: int, filters: int, policy: int, reachable: bool) -> StringName:
	"""Validate then allocate one container row. Refuses before writing anything."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	if max_mass_g < 0:
		return REFUSE_INVALID_MASS
	if not IntMath.fits_int32(policy):
		return REFUSE_OVERFLOW
	if _c_free_count == 0:
		return REFUSE_CAPACITY_INVENTORY_CONTAINER
	var slot: int = _alloc_container_slot()
	_journal_container(slot)
	_write_new_container(slot, owner_ref, max_mass_g, filters, policy, reachable)
	_c_live_count += 1
	return _succeed(Vector2i(slot, _c_generation[slot]), 0)


func _write_new_container(slot: int, owner_ref: Vector2i, max_mass_g: int, filters: int, policy: int, reachable: bool) -> void:
	"""Populate a freshly allocated container row. The generation is left untouched."""
	_c_owner_slot[slot] = owner_ref.x
	_c_owner_generation[slot] = owner_ref.y
	_c_policy[slot] = policy
	_c_max_mass_g[slot] = max_mass_g
	_c_filters[slot] = filters
	_c_reserved_mass_g[slot] = 0
	_c_used_mass_g[slot] = 0
	_c_lot_count[slot] = 0
	_c_first_lot[slot] = NULL_SLOT
	_c_reachable[slot] = 1 if reachable else 0
	_c_live[slot] = 1


func destroy_container(container_ref: Vector2i) -> OpResult:
	"""Retire an empty container. A container still holding lots or reserved mass is refused."""
	var owned: bool = _enter()
	return _leave(owned, _destroy_container_checked(container_ref))


func _destroy_container_checked(container_ref: Vector2i) -> StringName:
	"""Validate then free one container row, incrementing its generation to void stale refs."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	if not is_container_valid(container_ref):
		return REFUSE_INVALID_CONTAINER
	var slot: int = container_ref.x
	if _c_lot_count[slot] != 0:
		return REFUSE_CONTAINER_NOT_EMPTY
	if _c_reserved_mass_g[slot] != 0:
		return REFUSE_CONTAINER_HAS_RESERVED_MASS
	if _c_generation[slot] >= MAX_INT32:
		return REFUSE_GENERATION_EXHAUSTED
	_journal_container(slot)
	_c_live[slot] = 0
	_c_live_count -= 1
	_free_container_slot(slot)
	return _succeed(NULL_REF, 0)


func set_container_reachable(container_ref: Vector2i, reachable: bool) -> OpResult:
	"""Set the container's reachability flag.

	Reachability gates job planning and REQ-SET-116 dependency invalidation, not the
	transaction layer, so this module stores it without refusing transfers on it.
	"""
	var owned: bool = _enter()
	return _leave(owned, _set_reachable_checked(container_ref, reachable))


func _set_reachable_checked(container_ref: Vector2i, reachable: bool) -> StringName:
	"""Validate then write the reachable byte."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	if not is_container_valid(container_ref):
		return REFUSE_INVALID_CONTAINER
	_journal_container(container_ref.x)
	_c_reachable[container_ref.x] = 1 if reachable else 0
	return _succeed(NULL_REF, 0)


func reserve_container_mass(container_ref: Vector2i, mass_g: int) -> OpResult:
	"""Commit container headroom for output not yet delivered (REQ-SET-112).

	BAL-SAFE-002 charges `sum(ceil_div(q*m,1000)) + reserved_mass <= max_mass`, so reserved
	mass sits alongside the lots already present rather than inside their total.
	"""
	var owned: bool = _enter()
	if mass_g <= 0:
		return _leave(owned, REFUSE_INVALID_MASS)
	return _leave(owned, _change_reserved_mass(container_ref, mass_g))


func release_container_mass(container_ref: Vector2i, mass_g: int) -> OpResult:
	"""Release previously committed container headroom."""
	var owned: bool = _enter()
	if mass_g <= 0:
		return _leave(owned, REFUSE_INVALID_MASS)
	return _leave(owned, _change_reserved_mass(container_ref, -mass_g))


func _change_reserved_mass(container_ref: Vector2i, delta_g: int) -> StringName:
	"""Validate then apply a signed change to the container's reserved mass.

	The cause is established BEFORE the arithmetic, so the reported code names the real
	reason. Deciding on the sum first reported a commitment the container could not take as
	INVALID_MASS -- an argument the caller had passed correctly. INVALID_MASS now means only
	a delta of zero; over-capacity is CAPACITY_EXCEEDED and releasing more than is held is
	INSUFFICIENT_RESERVED.
	"""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	if not is_container_valid(container_ref):
		return REFUSE_INVALID_CONTAINER
	if delta_g == 0:
		return REFUSE_INVALID_MASS
	var slot: int = container_ref.x
	var held: int = _c_reserved_mass_g[slot]
	if delta_g > 0:
		var fits: StringName = _check_fits(slot, delta_g)
		if fits != REFUSE_NONE:
			return fits
	elif delta_g < -held:
		# `-held` cannot overflow (held >= 0), where negating delta_g could.
		return REFUSE_INSUFFICIENT_RESERVED
	if not IntMath.checked_add_into(held, delta_g, _math):
		return REFUSE_OVERFLOW
	var next: int = _math.value
	_journal_container(slot)
	_c_reserved_mass_g[slot] = next
	return _succeed(NULL_REF, next)


func _check_fits(container_slot: int, delta_g: int) -> StringName:
	"""REFUSE_NONE when `delta_g` more grams still satisfy used + reserved <= max (BAL-SAFE-002).

	Both additions are checked. A raw `+` here would wrap a near-INT64_MAX commitment negative
	and read as fitting, which is exactly the silent success BAL-SAFE-002 forbids, so an
	unrepresentable sum refuses with OVERFLOW rather than being compared at all.

	Produces no value: `_math` is left holding this call's intermediate sum, not an answer.
	"""
	if not IntMath.checked_add_into(_c_used_mass_g[container_slot], _c_reserved_mass_g[container_slot], _math):
		return REFUSE_OVERFLOW
	if not IntMath.checked_add_into(_math.value, delta_g, _math):
		return REFUSE_OVERFLOW
	if _math.value > _c_max_mass_g[container_slot]:
		return REFUSE_CAPACITY_EXCEEDED
	return REFUSE_NONE


# --- Lot list threading -----------------------------------------------------------------------

func _link_lot(slot: int, container_slot: int) -> void:
	"""Insert lot `slot` at the head of a container's intrusive list.

	The caller must already have journaled both the lot row and the container row.
	"""
	var head: int = _c_first_lot[container_slot]
	_l_prev[slot] = NULL_SLOT
	_l_next[slot] = head
	if head != NULL_SLOT:
		_journal_lot(head)
		_l_prev[head] = slot
	_c_first_lot[container_slot] = slot
	_c_lot_count[container_slot] += 1


func _unlink_lot(slot: int) -> void:
	"""Remove lot `slot` from its container's intrusive list.

	The caller must already have journaled both the lot row and its container row.
	"""
	var container_slot: int = _l_container_slot[slot]
	var prev: int = _l_prev[slot]
	var next: int = _l_next[slot]
	if prev != NULL_SLOT:
		_journal_lot(prev)
		_l_next[prev] = next
	else:
		_c_first_lot[container_slot] = next
	if next != NULL_SLOT:
		_journal_lot(next)
		_l_prev[next] = prev
	_l_prev[slot] = NULL_SLOT
	_l_next[slot] = NULL_SLOT
	_c_lot_count[container_slot] -= 1


# --- Lot operations ---------------------------------------------------------------------------

func create_lot(container_ref: Vector2i, item_id: int, quantity_milli: int, quality: int, provenance: int, recipe_id: int, age_milli_hours: int, age_remainder: int) -> OpResult:
	"""Introduce quantity into the world as a new lot. This is a conservation SOURCE.

	Every milli-unit created here is counted in the per-item source ledger, so audit() can
	verify `live + sunk == sourced` without trusting any running total.
	"""
	var owned: bool = _enter()
	var code: StringName = _create_lot_checked(container_ref, item_id, quantity_milli, quality, provenance, recipe_id, age_milli_hours, age_remainder)
	return _leave(owned, code)


func _create_lot_checked(container_ref: Vector2i, item_id: int, quantity_milli: int, quality: int, provenance: int, recipe_id: int, age_milli_hours: int, age_remainder: int) -> StringName:
	"""Validate every precondition, then allocate and link one lot row."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var check: StringName = _check_new_lot(container_ref, item_id, quantity_milli, age_milli_hours, age_remainder)
	if check != REFUSE_NONE:
		return check
	var narrowed: StringName = _check_lot_int32_fields(quality, provenance, recipe_id)
	if narrowed != REFUSE_NONE:
		return narrowed
	if not IntMath.inventory_capacity_debit_g_into(quantity_milli, _item_mass_g[item_id], _math):
		return REFUSE_OVERFLOW
	var debit_g: int = _math.value
	var fits: StringName = _check_fits(container_ref.x, debit_g)
	if fits != REFUSE_NONE:
		return fits
	if not IntMath.checked_add_into(_sourced_milli[item_id], quantity_milli, _math):
		return REFUSE_OVERFLOW
	var sourced: int = _math.value
	var slot: int = _alloc_lot_slot()
	_journal_lot(slot)
	_journal_container(container_ref.x)
	_write_new_lot(slot, container_ref, item_id, quantity_milli, quality, provenance, recipe_id, age_milli_hours, age_remainder)
	_credit_container(container_ref.x, debit_g)
	_journal_scalar(_J_SOURCED, item_id, _sourced_milli[item_id])
	_sourced_milli[item_id] = sourced
	return _succeed(Vector2i(slot, _l_generation[slot]), quantity_milli)


func _check_new_lot(container_ref: Vector2i, item_id: int, quantity_milli: int, age_milli_hours: int, age_remainder: int) -> StringName:
	"""Shared precondition check for introducing a lot. REFUSE_NONE when everything holds."""
	if not is_container_valid(container_ref):
		return REFUSE_INVALID_CONTAINER
	if not is_item_registered(item_id):
		return REFUSE_UNKNOWN_ITEM
	if quantity_milli <= 0 or age_milli_hours < 0 or age_remainder < 0:
		return REFUSE_INVALID_QUANTITY
	if age_milli_hours > MAX_AGE_MILLI_HOURS:
		return REFUSE_OVERFLOW
	if not _accepts_item(container_ref.x, item_id):
		return REFUSE_ITEM_FILTERED
	if _l_free_count == 0:
		return REFUSE_CAPACITY_INVENTORY_LOT
	return REFUSE_NONE


func _check_lot_int32_fields(quality: int, provenance: int, recipe_id: int) -> StringName:
	"""Refuse a lot whose int32 columns would truncate (ARCH-AUTH-003). REFUSE_NONE when all fit.

	`quality`, `provenance` and `recipe_id` are stored in int32 columns, so a value outside int32
	would not merely lose magnitude, it would land on a different, plausible looking member; all
	three refuse instead. Only the verdict is needed here, so fits_int32() is used and nothing is
	narrowed or allocated. Provenance additionally faces the domain check below: the width test
	alone would admit `6` and `-1`, which fit perfectly and name no origin.
	"""
	if not IntMath.fits_int32(quality):
		return REFUSE_OVERFLOW
	if not IntMath.fits_int32(provenance):
		return REFUSE_OVERFLOW
	if not IntMath.fits_int32(recipe_id):
		return REFUSE_OVERFLOW
	return _check_lot_provenance(provenance)


func _check_lot_provenance(provenance: int) -> StringName:
	"""Refuse any value outside PROV-R01's six published InventoryProvenance members.

	THE ITEM-LABEL HALF OF PROV-R01 IS NOT ENFORCED HERE, and that is a boundary, not a gap.
	"COASTAL_BRINE requires the `brine` item" and "all three earth labels require
	`excavated_earth`" are rules about ItemDefinition KEYS; this store holds an item's compiled
	id, mass and category and has never known a key (`register_item()` takes no name). The rules
	themselves are published and tested as `Catalog.check_lot_provenance()` and
	`Catalog.check_salt_brine_input()`, and the producers that hold the key -- the saltpan recipe
	and EH-02's excavation/backfill/spoil transactions -- call them before reaching create_lot().
	A second, id-based copy here could disagree with that one, which is the drift this codebase
	refuses everywhere else; see the reported wiring blocker rather than adding one.
	"""
	if CatalogScript.is_inventory_provenance(provenance):
		return REFUSE_NONE
	return REFUSE_INVALID_PROVENANCE


func _write_new_lot(slot: int, container_ref: Vector2i, item_id: int, quantity_milli: int, quality: int, provenance: int, recipe_id: int, age_milli_hours: int, age_remainder: int) -> void:
	"""Populate a freshly allocated lot row and link it into its container."""
	_l_item_id[slot] = item_id
	_l_quality[slot] = quality
	_l_provenance[slot] = provenance
	_l_recipe_id[slot] = recipe_id
	_l_container_slot[slot] = container_ref.x
	_l_container_generation[slot] = container_ref.y
	_l_quantity_milli[slot] = quantity_milli
	_l_reserved_milli[slot] = 0
	_l_age_milli_hours[slot] = age_milli_hours
	_l_age_remainder[slot] = age_remainder
	_l_live[slot] = 1
	_l_live_count += 1
	_link_lot(slot, container_ref.x)


func _credit_container(container_slot: int, delta_g: int) -> void:
	"""Apply a signed change to a container's used mass. The caller journaled the row."""
	_c_used_mass_g[container_slot] += delta_g


func _accepts_item(container_slot: int, item_id: int) -> bool:
	"""True when the container's 64-bit category filter admits this item (ARCH-STATE-004)."""
	var bit: int = _item_category[item_id]
	return (_c_filters[container_slot] >> bit) & 1 == 1


func sink_lot_quantity(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Consume unreserved quantity out of the world. This is a conservation SINK.

	Consuming a lot to zero retires its row, so an emptied lot cannot hold a row against the
	16384-lot cap (REQ-SET-120).
	"""
	var owned: bool = _enter()
	return _leave(owned, _remove_quantity(lot_ref, quantity_milli, false))


func consume_reserved(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Consume quantity that a reservation had already claimed. This is a conservation SINK.

	Both `reserved_milli` and `quantity_milli` fall by the same amount, so the GDD §4.2
	invariant `reserved <= quantity` holds across the consumption.
	"""
	var owned: bool = _enter()
	return _leave(owned, _remove_quantity(lot_ref, quantity_milli, true))


func _remove_quantity(lot_ref: Vector2i, quantity_milli: int, from_reserved: bool) -> StringName:
	"""Validate then remove quantity from a lot, counting it into the per-item sink ledger."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var check: StringName = _check_removal(lot_ref, quantity_milli, from_reserved)
	if check != REFUSE_NONE:
		return check
	var seed: StringName = _seed_removal_refusal(lot_ref, quantity_milli, from_reserved)
	if seed != REFUSE_NONE:
		return seed
	var slot: int = lot_ref.x
	var item_id: int = _l_item_id[slot]
	if not IntMath.checked_add_into(_sunk_milli[item_id], quantity_milli, _math):
		return REFUSE_OVERFLOW
	var sunk: int = _math.value
	var delta: StringName = _quantity_delta_g(slot, _l_quantity_milli[slot] - quantity_milli)
	if delta != REFUSE_NONE:
		return delta
	var delta_g: int = _math.value
	_journal_scalar(_J_SUNK, item_id, _sunk_milli[item_id])
	_sunk_milli[item_id] = sunk
	_apply_removal(slot, quantity_milli, from_reserved, delta_g)
	return _succeed(NULL_REF, quantity_milli)


func _check_removal(lot_ref: Vector2i, quantity_milli: int, from_reserved: bool) -> StringName:
	"""Precondition check for consuming quantity. REFUSE_NONE when the removal is legal.

	An equipped lot refuses: it is held by a resident and charged to no container, so consuming
	it here would sink quantity while its GearInstance still recorded it. Unequip it first.
	"""
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if _l_container_slot[lot_ref.x] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if quantity_milli <= 0:
		return REFUSE_INVALID_QUANTITY
	var slot: int = lot_ref.x
	if from_reserved:
		if quantity_milli > _l_reserved_milli[slot]:
			return REFUSE_INSUFFICIENT_RESERVED
		return REFUSE_NONE
	if quantity_milli > _l_quantity_milli[slot] - _l_reserved_milli[slot]:
		return REFUSE_INSUFFICIENT_UNRESERVED
	return REFUSE_NONE


func _apply_removal(slot: int, quantity_milli: int, from_reserved: bool, delta_g: int) -> void:
	"""Write the removal: adjust the lot, credit the container, retire an emptied lot."""
	var container_slot: int = _l_container_slot[slot]
	_journal_lot(slot)
	_journal_container(container_slot)
	_l_quantity_milli[slot] -= quantity_milli
	if from_reserved:
		_l_reserved_milli[slot] -= quantity_milli
	_credit_container(container_slot, delta_g)
	if _l_quantity_milli[slot] == 0:
		_retire_lot(slot)


func _retire_lot(slot: int) -> void:
	"""Unlink and free an emptied lot row. The caller journaled the lot and its container."""
	_unlink_lot(slot)
	_l_live[slot] = 0
	_l_live_count -= 1
	_free_lot_slot(slot)


func _quantity_delta_g(slot: int, new_quantity_milli: int) -> StringName:
	"""Signed used-mass change when lot `slot` moves to `new_quantity_milli`, per-lot ceiling.

	On REFUSE_NONE the delta is in `_math.value`; copy it before the next call.
	"""
	var mass_g: int = _item_mass_g[_l_item_id[slot]]
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot], mass_g, _math):
		return REFUSE_OVERFLOW
	var before: int = _math.value
	if not IntMath.inventory_capacity_debit_g_into(new_quantity_milli, mass_g, _math):
		return REFUSE_OVERFLOW
	_math.succeed(_math.value - before)
	return REFUSE_NONE


func lot_debit_g(lot_ref: Vector2i) -> int:
	"""Grams this lot charges against its container: ceil_div(quantity_milli*mass_g, 1000)."""
	if not is_lot_valid(lot_ref):
		return 0
	var slot: int = lot_ref.x
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot], _item_mass_g[_l_item_id[slot]], _math):
		return 0
	return _math.value


# --- Split, merge, move, transfer --------------------------------------------------------------

func split_lot(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Split `quantity_milli` off a lot into a new sibling lot in the same container.

	Quantity is conserved exactly. Charged mass may rise, because BAL-SAFE-016 rounds each
	child up on its own, and a split that would exceed the container is refused rather than
	being allowed to manufacture capacity. Reservations stay attached to the source lot, so
	only unreserved quantity may be split off.
	"""
	var owned: bool = _enter()
	return _leave(owned, _split_lot_checked(lot_ref, quantity_milli))


func _split_lot_checked(lot_ref: Vector2i, quantity_milli: int) -> StringName:
	"""Validate then perform an in-place split. Refuses before writing anything."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var check: StringName = _check_split(lot_ref, quantity_milli)
	if check != REFUSE_NONE:
		return check
	var slot: int = lot_ref.x
	var container_slot: int = _l_container_slot[slot]
	var delta: StringName = _split_delta_g(slot, quantity_milli)
	if delta != REFUSE_NONE:
		return delta
	var delta_g: int = _math.value
	var fits: StringName = _check_fits(container_slot, delta_g)
	if fits != REFUSE_NONE:
		return fits
	return _apply_split(slot, container_slot, quantity_milli, delta_g)


func _check_split(lot_ref: Vector2i, quantity_milli: int) -> StringName:
	"""Precondition check for an in-place split. REFUSE_NONE when the split is legal.

	An equipped lot refuses outright: ARCH-STATE-001 makes a gear lot indivisible, and there is
	no container for a sibling to land in.
	"""
	if is_lot_equipped(lot_ref):
		return REFUSE_LOT_EQUIPPED
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if _l_free_count == 0:
		return REFUSE_CAPACITY_INVENTORY_LOT
	var slot: int = lot_ref.x
	if quantity_milli <= 0 or quantity_milli >= _l_quantity_milli[slot]:
		return REFUSE_INVALID_QUANTITY
	if quantity_milli > _l_quantity_milli[slot] - _l_reserved_milli[slot]:
		return REFUSE_INSUFFICIENT_UNRESERVED
	# STOCK-SEED-R01's "seed selection": separating a portion of a lot is how a sower picks the
	# seed it is about to use, and an over-shelf-life lot may not be picked from.
	return _seed_consumption_refusal(lot_ref)


func _split_delta_g(slot: int, quantity_milli: int) -> StringName:
	"""Used-mass change of splitting: debit(remainder) + debit(part) - debit(whole), per lot.

	On REFUSE_NONE the delta is in `_math.value`; copy it before the next call.
	"""
	var mass_g: int = _item_mass_g[_l_item_id[slot]]
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot], mass_g, _math):
		return REFUSE_OVERFLOW
	var whole: int = _math.value
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot] - quantity_milli, mass_g, _math):
		return REFUSE_OVERFLOW
	var kept: int = _math.value
	if not IntMath.inventory_capacity_debit_g_into(quantity_milli, mass_g, _math):
		return REFUSE_OVERFLOW
	_math.succeed(kept + _math.value - whole)
	return REFUSE_NONE


func _apply_split(slot: int, container_slot: int, quantity_milli: int, delta_g: int) -> StringName:
	"""Write the split: allocate the child, copy attributes, debit the parent."""
	var child: int = _alloc_lot_slot()
	_journal_lot(slot)
	_journal_lot(child)
	_journal_container(container_slot)
	var container_ref: Vector2i = Vector2i(container_slot, _c_generation[container_slot])
	_write_new_lot(child, container_ref, _l_item_id[slot], quantity_milli, _l_quality[slot], _l_provenance[slot], _l_recipe_id[slot], _l_age_milli_hours[slot], _l_age_remainder[slot])
	_l_quantity_milli[slot] -= quantity_milli
	_credit_container(container_slot, delta_g)
	return _succeed(Vector2i(child, _l_generation[child]), quantity_milli)


func merge_lots(dest_ref: Vector2i, source_ref: Vector2i) -> OpResult:
	"""Merge two lots of one container into `dest_ref`, retiring the source row.

	BAL-SAFE-003 requires identical item, quality, recipe, provenance and
	`ceil_div(age_milli_hours, 1000)`; the merged age is that shared rounded age in
	milli-hours and the remainder is the older lot's, never the younger's. Quantity and
	reservations are summed, so nothing is created or destroyed; charged mass may fall,
	which is the rounding slack BAL-SAFE-016 permits a merge to recover.
	"""
	var owned: bool = _enter()
	return _leave(owned, _merge_lots_checked(dest_ref, source_ref))


func _merge_lots_checked(dest_ref: Vector2i, source_ref: Vector2i) -> StringName:
	"""Validate then fold the source lot into the destination lot."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var check: StringName = _check_merge(dest_ref, source_ref)
	if check != REFUSE_NONE:
		return check
	var dest: int = dest_ref.x
	var source: int = source_ref.x
	if not IntMath.checked_add_into(_l_quantity_milli[dest], _l_quantity_milli[source], _math):
		return REFUSE_OVERFLOW
	var total: int = _math.value
	if not IntMath.checked_add_into(_l_reserved_milli[dest], _l_reserved_milli[source], _math):
		return REFUSE_OVERFLOW
	var reserved: int = _math.value
	var delta: StringName = _merge_delta_g(dest, source, total)
	if delta != REFUSE_NONE:
		return delta
	var delta_g: int = _math.value
	if not _merged_age_milli_hours_into(dest, _math):
		return REFUSE_OVERFLOW
	_apply_merge(dest, source, total, reserved, delta_g, _math.value)
	return _succeed(dest_ref, total)


func _check_merge(dest_ref: Vector2i, source_ref: Vector2i) -> StringName:
	"""Precondition check for a merge. REFUSE_NONE when the two lots may be folded together."""
	if not is_lot_valid(dest_ref) or not is_lot_valid(source_ref):
		return REFUSE_INVALID_LOT
	if dest_ref == source_ref:
		return REFUSE_SAME_LOT
	var dest: int = dest_ref.x
	var source: int = source_ref.x
	# "Never clone it, merge it": two equipped lots both carry NULL_SLOT and would otherwise read
	# as sharing a container, so this is checked before the same-container comparison.
	if _l_container_slot[dest] == NULL_SLOT or _l_container_slot[source] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if _l_container_slot[dest] != _l_container_slot[source]:
		return REFUSE_DIFFERENT_CONTAINER
	if not _attributes_match(dest, source):
		return REFUSE_ATTRIBUTE_MISMATCH
	if not _age_hours_ceil_into(dest, _math):
		return REFUSE_OVERFLOW
	var dest_age: int = _math.value
	if not _age_hours_ceil_into(source, _math):
		return REFUSE_OVERFLOW
	if dest_age != _math.value:
		return REFUSE_AGE_MISMATCH
	return REFUSE_NONE


func _attributes_match(a: int, b: int) -> bool:
	"""True when two lots agree on item, quality, provenance and recipe (GDD §4.2)."""
	if _l_item_id[a] != _l_item_id[b] or _l_quality[a] != _l_quality[b]:
		return false
	return _l_provenance[a] == _l_provenance[b] and _l_recipe_id[a] == _l_recipe_id[b]


func _age_hours_ceil_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Effective age of a lot rounded up to the next whole hour (BAL-SAFE-003), checked.

	Returns the refusal as a false bool with a zeroed `out`, never as a sentinel age. A -1 here
	would be compared as a real age -- making two unroundable lots look equally old and
	mergeable -- and then multiplied back into a negative `age_milli_hours` that inverts every
	downstream spoilage test (GDD §5.8). `out` is caller-owned; the age lands in `out.value`.
	"""
	return IntMath.ceil_div_into(_l_age_milli_hours[slot], MILLI_PER_UNIT, out)


func _merged_age_milli_hours_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Age a merged row adopts: ceil_div(age, 1000) * 1000, with both steps checked.

	`out` doubles as the scratch for the intermediate hour count, which is consumed at once.
	"""
	if not _age_hours_ceil_into(slot, out):
		return false
	return IntMath.checked_mul_into(out.value, MILLI_PER_UNIT, out)


func _merge_delta_g(dest: int, source: int, total_milli: int) -> StringName:
	"""Used-mass change of a merge: debit(sum) - debit(dest) - debit(source), per lot.

	On REFUSE_NONE the delta is in `_math.value`; copy it before the next call.
	"""
	var mass_g: int = _item_mass_g[_l_item_id[dest]]
	if not IntMath.inventory_capacity_debit_g_into(total_milli, mass_g, _math):
		return REFUSE_OVERFLOW
	var merged: int = _math.value
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[dest], mass_g, _math):
		return REFUSE_OVERFLOW
	var a: int = _math.value
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[source], mass_g, _math):
		return REFUSE_OVERFLOW
	_math.succeed(merged - a - _math.value)
	return REFUSE_NONE


func _apply_merge(dest: int, source: int, total_milli: int, reserved_milli: int, delta_g: int, merged_age: int) -> void:
	"""Write the merge: sum the quantities, adopt the older age, retire the source row.

	`merged_age` is the caller's already-checked shared rounded age, so this writes nothing it
	could still fail to compute.
	"""
	var container_slot: int = _l_container_slot[dest]
	var older: int = dest if _is_older(dest, source) else source
	_journal_lot(dest)
	_journal_lot(source)
	_journal_container(container_slot)
	_l_quantity_milli[dest] = total_milli
	_l_reserved_milli[dest] = reserved_milli
	_l_age_remainder[dest] = _l_age_remainder[older]
	_l_age_milli_hours[dest] = merged_age
	_l_quantity_milli[source] = 0
	_credit_container(container_slot, delta_g)
	_retire_lot(source)


func _is_older(a: int, b: int) -> bool:
	"""True when lot `a` has the greater effective age, ties broken by the larger remainder."""
	if _l_age_milli_hours[a] != _l_age_milli_hours[b]:
		return _l_age_milli_hours[a] > _l_age_milli_hours[b]
	return _l_age_remainder[a] >= _l_age_remainder[b]


func move_lot(lot_ref: Vector2i, dest_ref: Vector2i) -> OpResult:
	"""Move a whole lot into another container, carrying its reservations with it.

	The lot keeps its identity, so GDD §5.8's "reservations remain attached" is satisfied by
	construction. BAL-SAFE-002 requires the debit and credit to be one atomic step: the lot is
	in exactly one container before and after, never in both and never in neither.
	"""
	var owned: bool = _enter()
	return _leave(owned, _move_lot_checked(lot_ref, dest_ref))


func _move_lot_checked(lot_ref: Vector2i, dest_ref: Vector2i) -> StringName:
	"""Validate then relink a whole lot into the destination container.

	The debit is taken from the checked helper rather than lot_debit_g(), whose 0-on-failure
	return is a query convenience that must never decide a write.
	"""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var check: StringName = _check_move(lot_ref, dest_ref)
	if check != REFUSE_NONE:
		return check
	var slot: int = lot_ref.x
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot], _item_mass_g[_l_item_id[slot]], _math):
		return REFUSE_OVERFLOW
	var debit: int = _math.value
	var fits: StringName = _check_fits(dest_ref.x, debit)
	if fits != REFUSE_NONE:
		return fits
	_apply_move(slot, _l_container_slot[slot], dest_ref, debit)
	return _succeed(lot_ref, _l_quantity_milli[slot])


func _check_move(lot_ref: Vector2i, dest_ref: Vector2i) -> StringName:
	"""Precondition check for a whole-lot move. REFUSE_NONE when the move is legal.

	The seed guard is asked LAST of these and still before anything is costed, so a structural
	refusal keeps its own name and no `_math` value is live across the authority call.
	"""
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if not is_container_valid(dest_ref):
		return REFUSE_INVALID_CONTAINER
	var slot: int = lot_ref.x
	var source_container: int = _l_container_slot[slot]
	if source_container == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if source_container == dest_ref.x:
		return REFUSE_SAME_CONTAINER
	if not _accepts_item(dest_ref.x, _l_item_id[slot]):
		return REFUSE_ITEM_FILTERED
	return _seed_consumption_refusal(lot_ref)


func _apply_move(slot: int, source_container: int, dest_ref: Vector2i, debit_g: int) -> void:
	"""Write the move: unlink, retarget the container ref, relink, and shift the charged mass."""
	_journal_lot(slot)
	_journal_container(source_container)
	_journal_container(dest_ref.x)
	_unlink_lot(slot)
	_credit_container(source_container, -debit_g)
	_l_container_slot[slot] = dest_ref.x
	_l_container_generation[slot] = dest_ref.y
	_link_lot(slot, dest_ref.x)
	_credit_container(dest_ref.x, debit_g)


func transfer(lot_ref: Vector2i, dest_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Move `quantity_milli` from a lot into another container, merging on arrival when legal.

	REQ-SET-111: the quantity is split exactly and the lot is not cloned. The source is debited
	and the destination credited in one step, so the quantity is never in two places nor in
	none. Only unreserved quantity may be transferred, because reservations stay attached to
	the source lot; use move_lot() to carry a reserved lot whole.
	"""
	var owned: bool = _enter()
	return _leave(owned, _transfer_checked(lot_ref, dest_ref, quantity_milli))


func _transfer_checked(lot_ref: Vector2i, dest_ref: Vector2i, quantity_milli: int) -> StringName:
	"""Plan the transfer completely, then apply it. Any refusal happens before the first write."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var planned: StringName = _plan_transfer(lot_ref, dest_ref, quantity_milli)
	if planned != REFUSE_NONE:
		return planned
	return _apply_transfer(dest_ref)


func _plan_transfer(lot_ref: Vector2i, dest_ref: Vector2i, quantity_milli: int) -> StringName:
	"""Validate and cost a transfer into the reused plan. Writes no inventory state."""
	var check: StringName = _check_transfer(lot_ref, dest_ref, quantity_milli)
	if check != REFUSE_NONE:
		return check
	var slot: int = lot_ref.x
	_plan.source_slot = slot
	_plan.dest_container = dest_ref.x
	_plan.quantity_milli = quantity_milli
	_plan.source_emptied = quantity_milli == _l_quantity_milli[slot]
	var target: StringName = _plan_merge_target(dest_ref.x, slot)
	if target != REFUSE_NONE:
		return target
	# A whole-lot transfer frees the source row before the destination row is taken, so it
	# needs no spare slot; a partial transfer into a fresh lot does.
	if _plan.target_slot == NULL_SLOT and _l_free_count == 0 and not _plan.source_emptied:
		return REFUSE_CAPACITY_INVENTORY_LOT
	return _plan_transfer_masses(lot_ref, dest_ref, quantity_milli)


func _plan_merge_target(dest_container: int, slot: int) -> StringName:
	"""Record the destination's merge target and the already-checked age it would adopt."""
	var target: StringName = _find_merge_target(dest_container, slot)
	if target != REFUSE_NONE:
		return target
	_plan.target_slot = _math.value
	_plan.target_age_milli_hours = 0
	if _plan.target_slot == NULL_SLOT:
		return REFUSE_NONE
	if not _merged_age_milli_hours_into(_plan.target_slot, _math):
		return REFUSE_OVERFLOW
	_plan.target_age_milli_hours = _math.value
	return REFUSE_NONE


func _plan_transfer_masses(lot_ref: Vector2i, dest_ref: Vector2i, quantity_milli: int) -> StringName:
	"""Cost both sides of the planned transfer and check the destination against its capacity."""
	var slot: int = lot_ref.x
	var source_delta: StringName = _quantity_delta_g(slot, _l_quantity_milli[slot] - quantity_milli)
	if source_delta != REFUSE_NONE:
		return source_delta
	_plan.source_delta_g = _math.value
	var dest_delta: StringName = _transfer_dest_delta_g(slot, _plan.target_slot, quantity_milli)
	if dest_delta != REFUSE_NONE:
		return dest_delta
	_plan.dest_delta_g = _math.value
	return _check_fits(dest_ref.x, _plan.dest_delta_g)


func _check_transfer(lot_ref: Vector2i, dest_ref: Vector2i, quantity_milli: int) -> StringName:
	"""Precondition check for a transfer. REFUSE_NONE when the transfer is legal."""
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if not is_container_valid(dest_ref):
		return REFUSE_INVALID_CONTAINER
	var slot: int = lot_ref.x
	if _l_container_slot[slot] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if _l_container_slot[slot] == dest_ref.x:
		return REFUSE_SAME_CONTAINER
	if quantity_milli <= 0 or quantity_milli > _l_quantity_milli[slot] - _l_reserved_milli[slot]:
		return REFUSE_INSUFFICIENT_UNRESERVED
	if not _accepts_item(dest_ref.x, _l_item_id[slot]):
		return REFUSE_ITEM_FILTERED
	# STOCK-SEED-R01's "transfer into production". This store cannot tell a workshop's input
	# container from a larder, so an expired seed moves into NEITHER; the declared expiry
	# converts it where it stands and needs no transfer.
	return _seed_consumption_refusal(lot_ref)


func _transfer_dest_delta_g(slot: int, target_slot: int, quantity_milli: int) -> StringName:
	"""Grams the destination gains: a fresh lot's own ceil debit, or a merge target's increase.

	On REFUSE_NONE the delta is in `_math.value`; copy it before the next call.
	"""
	var mass_g: int = _item_mass_g[_l_item_id[slot]]
	if target_slot == NULL_SLOT:
		if not IntMath.inventory_capacity_debit_g_into(quantity_milli, mass_g, _math):
			return REFUSE_OVERFLOW
		return REFUSE_NONE
	if not IntMath.checked_add_into(_l_quantity_milli[target_slot], quantity_milli, _math):
		return REFUSE_OVERFLOW
	return _quantity_delta_g(target_slot, _math.value)


func _find_merge_target(container_slot: int, lot_slot: int) -> StringName:
	"""First lot the incoming quantity may merge into, left in `_math.value`, else NULL_SLOT.

	Walking the intrusive list head-first makes the choice deterministic for a given history.
	An age that cannot be rounded up refuses outright rather than being read as a match or
	quietly skipped, because either reading would decide a merge on a number that does not exist.
	`own_age` is copied out of the scratch before the loop reuses it for each candidate.
	"""
	if not _age_hours_ceil_into(lot_slot, _math):
		return REFUSE_OVERFLOW
	var own_age: int = _math.value
	var candidate: int = _c_first_lot[container_slot]
	while candidate != NULL_SLOT:
		if candidate != lot_slot and _attributes_match(candidate, lot_slot):
			if not _age_hours_ceil_into(candidate, _math):
				return REFUSE_OVERFLOW
			if _math.value == own_age:
				_math.succeed(candidate)
				return REFUSE_NONE
		candidate = _l_next[candidate]
	_math.succeed(NULL_SLOT)
	return REFUSE_NONE


func _apply_transfer(dest_ref: Vector2i) -> StringName:
	"""Write the planned transfer: debit the source, then credit the destination."""
	var slot: int = _plan.source_slot
	var source_container: int = _l_container_slot[slot]
	_journal_lot(slot)
	_journal_container(source_container)
	_journal_container(_plan.dest_container)
	_l_quantity_milli[slot] -= _plan.quantity_milli
	_credit_container(source_container, _plan.source_delta_g)
	var older_remainder: int = _l_age_remainder[slot]
	var age: int = _l_age_milli_hours[slot]
	if _plan.source_emptied:
		_retire_lot(slot)
	_credit_container(_plan.dest_container, _plan.dest_delta_g)
	if _plan.target_slot != NULL_SLOT:
		return _credit_merge_target(age, older_remainder)
	return _credit_new_lot(dest_ref, slot, age, older_remainder)


func _credit_merge_target(age_milli_hours: int, age_remainder: int) -> StringName:
	"""Fold the transferred quantity into the destination's existing compatible lot."""
	var target: int = _plan.target_slot
	var incoming_is_older: bool = age_milli_hours > _l_age_milli_hours[target] or (age_milli_hours == _l_age_milli_hours[target] and age_remainder > _l_age_remainder[target])
	_journal_lot(target)
	_l_quantity_milli[target] += _plan.quantity_milli
	if incoming_is_older:
		_l_age_remainder[target] = age_remainder
	_l_age_milli_hours[target] = _plan.target_age_milli_hours
	return _succeed(Vector2i(target, _l_generation[target]), _l_quantity_milli[target])


func _credit_new_lot(dest_ref: Vector2i, source_slot: int, age_milli_hours: int, age_remainder: int) -> StringName:
	"""Create the destination lot carrying the source lot's attributes and elapsed age.

	The freed source slot may be reallocated here, which is why the attribute reads happen as
	call arguments, before the new row is written.
	"""
	var child: int = _alloc_lot_slot()
	_journal_lot(child)
	_write_new_lot(child, dest_ref, _l_item_id[source_slot], _plan.quantity_milli, _l_quality[source_slot], _l_provenance[source_slot], _l_recipe_id[source_slot], age_milli_hours, age_remainder)
	return _succeed(Vector2i(child, _l_generation[child]), _plan.quantity_milli)


# --- Reservations (partial: per-lot reserved_milli only; see U4/U5) ----------------------------

func reserve_lot(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Claim quantity on a lot, enforcing GDD §4.2's `total per lot <= quantity`.

	BLOCKED, U4/U5: the Reservation row store (job, lot, quantity_milli, expiry, purpose; at
	most 32768 rows) attaches HERE, once its indexing is specified. 32768 rows against 8192
	Job rows implies an owner-major `job*4+i` layout that neither document states and that
	would cap a recipe at four input lots, and U5 budgets no allocator storage for it. So this
	release keeps only the per-lot total, which IS specified, and the owner-side rows that
	would let a lease expire (BAL-SAFE-004) or a job release its claims in job-ID order
	(REQ-SET-116) are deliberately absent rather than guessed.
	"""
	var owned: bool = _enter()
	if quantity_milli <= 0:
		return _leave(owned, REFUSE_INVALID_QUANTITY)
	return _leave(owned, _change_reservation(lot_ref, quantity_milli))


func release_reservation(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Cancel part of a lot's claim, restoring exactly that much available quantity."""
	var owned: bool = _enter()
	if quantity_milli <= 0:
		return _leave(owned, REFUSE_INVALID_QUANTITY)
	return _leave(owned, _change_reservation(lot_ref, -quantity_milli))


func release_all_reservations(lot_ref: Vector2i) -> OpResult:
	"""Cancel every claim on a lot, as a lease expiry or job invalidation would.

	STOCK-SEED-R01: this also DECLARES the lot's cleanup for the next step of an open explicit
	transaction, which is what lets the declared expiry retire or transform an over-shelf-life
	seed the guard below refuses to every consumer. The declaration is recorded even when the
	lot held no claim -- the ruling's invalidation is unconditional, and a seed that expired
	with nobody holding a claim must still be disposable. The declaration is made BEFORE
	`_leave()` on purpose: a release that owns its own implicit transaction has that close
	discard it, so only a release inside an explicit transaction can license the step after it.
	A disposal in a LATER transaction would not be the atomic release-and-dispose that decision
	0059 and the ruling both require.
	"""
	var owned: bool = _enter()
	if not is_lot_valid(lot_ref):
		return _leave(owned, REFUSE_INVALID_LOT)
	var reserved: int = _l_reserved_milli[lot_ref.x]
	var code: StringName = _succeed(lot_ref, 0)
	if reserved != 0:
		code = _change_reservation(lot_ref, -reserved)
	if code == REFUSE_NONE:
		_tx_cleanup_lot = lot_ref
	return _leave(owned, code)


func _change_reservation(lot_ref: Vector2i, delta_milli: int) -> StringName:
	"""Validate then apply a signed change to a lot's reserved quantity.

	Each bound is tested against the delta itself rather than against the sum, for the same
	reason as _change_reserved_mass(): `held + delta` wraps for a delta near INT64_MAX, and a
	wrapped sum reads as negative, so a claim far larger than the lot holds was reported as
	INSUFFICIENT_RESERVED -- the opposite of what happened. Neither comparison below can
	overflow: `held` and `quantity` are non-negative with `held <= quantity`.
	"""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if _l_container_slot[lot_ref.x] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if delta_milli == 0:
		return REFUSE_INVALID_QUANTITY
	var slot: int = lot_ref.x
	var held: int = _l_reserved_milli[slot]
	if delta_milli > _l_quantity_milli[slot] - held:
		return REFUSE_RESERVED_EXCEEDS_QUANTITY
	if delta_milli < -held:
		return REFUSE_INSUFFICIENT_RESERVED
	if delta_milli > 0:
		var seed: StringName = _seed_consumption_refusal(lot_ref)
		if seed != REFUSE_NONE:
			return seed
	var next: int = held + delta_milli
	_journal_lot(slot)
	_l_reserved_milli[slot] = next
	return _succeed(lot_ref, next)


# --- STOCK-SEED-R01: the seed-consumer eligibility guard --------------------------------------
#
# The ruling gives ENFORCEMENT for quantity admission to this module and the PREDICATE to
# ARCH-SYS-004: "every seed-consuming eligibility path (new reservation, withdrawal, transfer
# into production, seed selection and sowing/work commit, including existing reservations) MUST
# reject a seed lot whose existing age has reached its catalog shelf threshold. Revalidate at
# commit."
#
# NO SHELF-LIFE ARITHMETIC LIVES HERE, AND NO SEED FLAG EITHER. This store knows an item's mass
# and category and nothing else; shelf hours and the §4.3 `seed` flag belong to the item
# catalog, and the age comparison belongs to `stock_age.gd`'s `refuses_seed_consumption()`. A
# second copy of that comparison in this file could disagree with the first, so there is one.
#
# REVALIDATION AT COMMIT IS STRUCTURAL, NOT REMEMBERED. No verdict is cached anywhere: every
# guarded call asks the authority again, against the age persisted in `_l_age_milli_hours` at
# that instant. A reservation taken while the lot was fresh therefore carries no permission with
# it -- `consume_reserved()` re-asks, and refuses a lot that aged out in between. There is no
# code path on which an earlier "yes" can be replayed, because there is nowhere to store one.
#
# WHY THE CLEANUP DECLARATION EXISTS. The same ruling says "Release/cancellation and declared
# expiry transform/sink operations remain permitted, so the guard cannot prevent its own
# cleanup". Cleanup and consumption reach this store through the SAME two methods, so the guard
# must be able to tell them apart. `release_all_reservations()` is the ruling's own invalidation
# step and every declared-expiry sequence begins with it, so it declares the lot; the single
# following step in that same explicit transaction may retire the whole row or transform it.
# Nothing partial is ever exempt: a sink that leaves quantity behind is a consumer taking a
# helping, whoever asked for it.
#
# FAIL-CLOSED, AND NOT SOFTENED HERE. An authority that cannot evaluate a lot -- unbound store,
# unloaded catalog, invalid ref -- answers true, and this module treats that answer as a
# refusal exactly like any other. It does not second-guess it, and it never converts "cannot
# tell" into an admission.
#
# WITH NO AUTHORITY BOUND, NOTHING IS REFUSED, and that is a wiring gap rather than a policy:
# this store cannot identify a seed on its own, so an unbound guard has no lots to refuse
# rather than every lot. `has_seed_expiry_authority()` reports it. The binding call belongs to
# whoever constructs both collaborators -- ARCH-SYS-001 / `settlement_system.gd` -- and is NOT
# made in this file, which constructs nothing.

func set_seed_expiry_authority(authority: Object) -> OpResult:
	"""Bind -- or with null, unbind -- STOCK-SEED-R01's seed-consumer eligibility predicate.

	Refused while a transaction is open, and refused for an object that does not publish
	`refuses_seed_consumption(lot_ref) -> bool`: a guard that is bound but cannot be called
	would be enforcement in name only. The binding is wiring, not simulation state: it is not
	journaled, not part of state_bytes(), and survives clear().
	"""
	if _tx_open:
		return _refuse(REFUSE_TRANSACTION_OPEN)
	if authority != null and not authority.has_method(SEED_EXPIRY_ATTESTATION_METHOD):
		return _refuse(REFUSE_INVALID_SEED_EXPIRY_AUTHORITY)
	# An explicit unbind and a released binding are DIFFERENT states and stay different: null
	# enforces nothing, while a dead WeakRef refuses every consumer in the guard below.
	if authority == null:
		_seed_expiry_authority = null
	else:
		_seed_expiry_authority = weakref(authority)
	return _ok(NULL_REF, 0)


func has_seed_expiry_authority() -> bool:
	"""True when a LIVE seed-expiry authority is bound and seed consumption is enforced.

	False for never bound, for explicitly unbound, AND for a binding whose object has been
	released -- but only the first two admit anything. The third still REFUSES consumption.
	"""
	if _seed_expiry_authority == null:
		return false
	return _seed_expiry_authority.get_ref() != null


func _seed_consumption_refusal(lot_ref: Vector2i) -> StringName:
	"""REFUSE_SEED_PAST_SHELF_LIFE when the bound authority rejects this lot, else REFUSE_NONE.

	The one place this module asks about seed age. `_attesting` is raised across the call so
	`_guard()` refuses every mutator an authority might re-enter with, and no `_math` or `_plan`
	value may be held across it -- which is why every caller asks before it costs anything.

	STOCK-C4-LIFETIME-R01: the binding is borrowed, so a PREVIOUSLY BOUND authority that has been
	released fails CLOSED with INVALID_SEED_EXPIRY_AUTHORITY. It never degrades into the unbound
	case, which enforces nothing. The strong local below holds a live predicate for the call only.
	"""
	if _seed_expiry_authority == null:
		return REFUSE_NONE
	var authority: Object = _seed_expiry_authority.get_ref()
	if authority == null:
		return REFUSE_INVALID_SEED_EXPIRY_AUTHORITY
	_attesting = true
	var refuses: bool = bool(authority.call(SEED_EXPIRY_ATTESTATION_METHOD, lot_ref))
	_attesting = false
	if refuses:
		return REFUSE_SEED_PAST_SHELF_LIFE
	return REFUSE_NONE


func _is_declared_cleanup(lot_ref: Vector2i) -> bool:
	"""True when the previous step of this transaction declared THIS lot's cleanup.

	The comparison includes the generation, and it is the INVENTORY LOT generation
	(`_l_generation`) -- never the container generation, which indexes a different store and
	whose value for the same slot number is unrelated.
	"""
	return lot_ref != NULL_REF and _op_cleanup_lot == lot_ref


func _seed_removal_refusal(lot_ref: Vector2i, quantity_milli: int,
		from_reserved: bool) -> StringName:
	"""Seed guard for the two removal paths: the sowing/work commit, and a plain withdrawal.

	`from_reserved` is the COMMIT of an existing claim, and it is revalidated with no exemption
	at all: a claim taken while the seed was fresh buys nothing once the lot has aged out. The
	unreserved path is a withdrawal, exempt only as the declared expiry retirement -- the
	previous step released every claim on this same lot inside this transaction and the sink
	takes the row's ENTIRE remaining quantity, which destroys it instead of feeding anyone.
	"""
	if from_reserved:
		return _seed_consumption_refusal(lot_ref)
	var slot: int = lot_ref.x
	if _is_declared_cleanup(lot_ref) and quantity_milli == _l_quantity_milli[slot] \
			and _l_reserved_milli[slot] == 0:
		return REFUSE_NONE
	return _seed_consumption_refusal(lot_ref)


func _seed_transform_refusal(lot_ref: Vector2i) -> StringName:
	"""Seed guard for an in-place item change: the declared expiry conversion, or production.

	`stock_age.gd` turns an expired seed lot into compost through the same method a workshop
	would use to turn seed into something a resident wanted, so the declaration is the whole
	difference. `_check_transform()` has already refused any lot still carrying a claim.
	"""
	if _is_declared_cleanup(lot_ref):
		return REFUSE_NONE
	return _seed_consumption_refusal(lot_ref)


# --- ARCH-SYS-004 StockAge: effective storage age and the expiry transformation ---------------
#
# GDD §5.8 owns both rules and this module owns neither of their INPUTS. The store factor, the
# seasonal temperature factor and an item's shelf life all live outside an inventory, so nothing
# here decides when a lot ages or what it becomes: `stock_age.gd` (ARCH-SYS-004) supplies the
# already-chosen factors and the already-resolved outcome item, and these two mutators write
# them under the same all-or-nothing, journaled, generation-validated rules as every other
# operation on this store.

func advance_lot_age_hour(lot_ref: Vector2i, store_factor: int,
		temperature_factor: int) -> OpResult:
	"""One game hour of GDD §5.8 effective storage age. See advance_lot_age_hour_into().

	This form allocates the one OpResult every public operation here allocates; the `_into` form
	below is the one ARCH-SYS-004's hourly sweep uses.
	"""
	var owned: bool = _enter()
	var code: StringName = _advance_age_checked(lot_ref, store_factor, temperature_factor)
	return _leave(owned, code)


func advance_lot_age_hour_into(lot_ref: Vector2i, store_factor: int, temperature_factor: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating advance_lot_age_hour(): the lot's new total age lands in `out.value`.

	GDD §5.8: "Effective age per hour=floor(store_factor*temperature_factor/1000), retaining
	tick fractions". The fraction is RETAINED in `age_remainder` rather than floored away, using
	the same fold `farming.gd` uses for REQ-SET-072 growth: the whole numerator joins the carried
	remainder, the whole milli-hours it releases are added to the age, and `total % 1000` is kept
	for the next hour. Both factors come from §5.8's four store classes and four seasons, whose
	products are all multiples of 1000, so the retained remainder is 0 under the shipped tables
	and the carry exists for a factor that is not.

	Changing stores never resets age (§5.8), which is true here by omission: nothing in
	`move_lot()`, `transfer()`, `split_lot()` or the equip/unequip pair touches either column.
	"""
	var owned: bool = _enter()
	var code: StringName = _advance_age_checked(lot_ref, store_factor, temperature_factor)
	return _leave_into(owned, code, out)


func _advance_age_checked(lot_ref: Vector2i, store_factor: int,
		temperature_factor: int) -> StringName:
	"""Validate completely, then fold one hour of effective age into the lot's two age columns."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if store_factor < 0 or temperature_factor < 0:
		return REFUSE_INVALID_AGE_FACTOR
	var slot: int = lot_ref.x
	if _l_container_slot[slot] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	var released: StringName = _hour_age_numerator(slot, store_factor, temperature_factor)
	if released != REFUSE_NONE:
		return released
	var total: int = _math.value
	if not IntMath.checked_add_into(_l_age_milli_hours[slot],
			total / AGE_FACTOR_DENOMINATOR, _math):
		return REFUSE_OVERFLOW
	var aged: int = _math.value
	if aged > MAX_AGE_MILLI_HOURS:
		return REFUSE_AGE_LIMIT_REACHED
	_journal_lot(slot)
	_l_age_milli_hours[slot] = aged
	_l_age_remainder[slot] = total % AGE_FACTOR_DENOMINATOR
	return _succeed(lot_ref, aged)


func _hour_age_numerator(slot: int, store_factor: int, temperature_factor: int) -> StringName:
	"""This hour's numerator plus the lot's carried remainder, left in `_math.value`.

	Kept separate so the caller stays inside the thirty-line rule and so the overflow refusal
	names the multiplication rather than the addition that follows it.
	"""
	if not IntMath.checked_mul_into(store_factor, temperature_factor, _math):
		return REFUSE_OVERFLOW
	if not IntMath.checked_add_into(_l_age_remainder[slot], _math.value, _math):
		return REFUSE_OVERFLOW
	return REFUSE_NONE


func transform_lot_item(lot_ref: Vector2i, new_item_id: int,
		new_quantity_milli: int) -> OpResult:
	"""Turn THE SAME lot row into a different item: GDD §5.8's spoilage conversion, in place.

	"When age reaches shelf_hours x 1000, food becomes spoiled_food at identical mass" is a
	TRANSFORMATION, not a placement, so the destination container's category filter is NOT
	consulted: food rots where it stands, and a pantry whose filter admits no WASTE cannot veto
	that. `create_lot()` still enforces the filter for everything that is actually placed.

	The caller supplies `new_quantity_milli` because the mass identity depends on both items'
	catalog masses and on which conversion §5.8 names; deciding it here would make this store
	hold an opinion about food. The row's quality, provenance and recipe are CARRIED, because
	§5.8 names no replacement for them and this module may not invent a catalog member.

	Age and its remainder ARE reset, and only here: spoiled_food "lasts 240h" from the moment it
	becomes spoiled_food, so a carried age would expire it in the same hour it was created.

	Conservation is kept as two declared ledger movements, not as a silent relabel: the old
	item is SUNK for its whole quantity and the new item SOURCED for its whole quantity, so
	`audit()`'s per-item `live + sunk == sourced` identity still closes on both.
	"""
	var owned: bool = _enter()
	var code: StringName = _transform_checked(lot_ref, new_item_id, new_quantity_milli)
	return _leave(owned, code)


func transform_lot_item_into(lot_ref: Vector2i, new_item_id: int, new_quantity_milli: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating transform_lot_item(): the new quantity lands in `out.value`."""
	var owned: bool = _enter()
	var code: StringName = _transform_checked(lot_ref, new_item_id, new_quantity_milli)
	return _leave_into(owned, code, out)


func _transform_checked(lot_ref: Vector2i, new_item_id: int,
		new_quantity_milli: int) -> StringName:
	"""Validate completely, cost the mass change, then rewrite the row and both ledgers."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var check: StringName = _check_transform(lot_ref, new_item_id, new_quantity_milli)
	if check != REFUSE_NONE:
		return check
	var seed: StringName = _seed_transform_refusal(lot_ref)
	if seed != REFUSE_NONE:
		return seed
	var slot: int = lot_ref.x
	var costed: StringName = _transform_delta_g(slot, new_item_id, new_quantity_milli)
	if costed != REFUSE_NONE:
		return costed
	var delta_g: int = _math.value
	var fits: StringName = _check_fits(_l_container_slot[slot], delta_g)
	if fits != REFUSE_NONE:
		return fits
	var ledger: StringName = _transform_ledger(slot, new_item_id, new_quantity_milli)
	if ledger != REFUSE_NONE:
		return ledger
	_apply_transform(slot, new_item_id, new_quantity_milli, delta_g)
	return _succeed(lot_ref, new_quantity_milli)


func _check_transform(lot_ref: Vector2i, new_item_id: int,
		new_quantity_milli: int) -> StringName:
	"""Every precondition for rewriting a lot's item. REFUSE_NONE when the rewrite is legal.

	A RESERVED lot refuses: a claim is held against a quantity of a particular item, and
	REQ-SET-108 requires those claims to be INVALIDATED before the conversion, not carried
	across it. `release_all_reservations()` is the caller's step, inside the same transaction.
	"""
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if _l_container_slot[lot_ref.x] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if _l_reserved_milli[lot_ref.x] != 0:
		return REFUSE_LOT_HAS_RESERVATION
	if new_item_id < 0 or new_item_id >= ITEM_CAPACITY or _item_registered[new_item_id] == 0:
		return REFUSE_UNKNOWN_ITEM
	if new_item_id == _l_item_id[lot_ref.x]:
		return REFUSE_SAME_ITEM
	if new_quantity_milli <= 0:
		return REFUSE_INVALID_QUANTITY
	return REFUSE_NONE


func _transform_delta_g(slot: int, new_item_id: int, new_quantity_milli: int) -> StringName:
	"""Signed used-mass change when the row becomes a different item at a different quantity.

	Both debits take BAL-NUM-001's per-lot ceiling, so an equal-mass conversion between two
	items whose grams divide exactly moves the container's charged mass by zero. On REFUSE_NONE
	the delta is in `_math.value`; copy it before the next call.
	"""
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot],
			_item_mass_g[_l_item_id[slot]], _math):
		return REFUSE_OVERFLOW
	var before: int = _math.value
	if not IntMath.inventory_capacity_debit_g_into(new_quantity_milli,
			_item_mass_g[new_item_id], _math):
		return REFUSE_OVERFLOW
	_math.succeed(_math.value - before)
	return REFUSE_NONE


func _transform_ledger(slot: int, new_item_id: int, new_quantity_milli: int) -> StringName:
	"""Journal and write both halves of the declared conversion into the conservation ledgers.

	Checked before either write, so a ledger that cannot represent the movement refuses with
	nothing applied rather than sinking one item and failing to source the other.
	"""
	var old_item: int = _l_item_id[slot]
	if not IntMath.checked_add_into(_sunk_milli[old_item], _l_quantity_milli[slot], _math):
		return REFUSE_OVERFLOW
	var sunk: int = _math.value
	if not IntMath.checked_add_into(_sourced_milli[new_item_id], new_quantity_milli, _math):
		return REFUSE_OVERFLOW
	var sourced: int = _math.value
	_journal_scalar(_J_SUNK, old_item, _sunk_milli[old_item])
	_sunk_milli[old_item] = sunk
	_journal_scalar(_J_SOURCED, new_item_id, _sourced_milli[new_item_id])
	_sourced_milli[new_item_id] = sourced
	return REFUSE_NONE


func _apply_transform(slot: int, new_item_id: int, new_quantity_milli: int,
		delta_g: int) -> void:
	"""Write the conversion: new item, new quantity, a fresh age, and the container's mass."""
	var container_slot: int = _l_container_slot[slot]
	_journal_lot(slot)
	_journal_container(container_slot)
	_l_item_id[slot] = new_item_id
	_l_quantity_milli[slot] = new_quantity_milli
	_l_age_milli_hours[slot] = 0
	_l_age_remainder[slot] = 0
	_credit_container(container_slot, delta_g)


# --- Equipped lots (ruling §4; READY_07 §7.2 step 5; decision 0061) ---------------------------

func set_equipment_authority(authority: Object) -> OpResult:
	"""Bind -- or with null, unbind -- the store that can prove a lot is an equipped record.

	Refused while a transaction is open; refused for an object that does not publish the
	attestation method; and refused for an unbind while equipped lots are live, because
	unbinding then would strand exactly the orphan null-container lots this mechanism exists to
	make impossible. The binding is wiring, not simulation state: it is not journaled, not part
	of state_bytes(), and survives clear() the way a collaborator reference does.
	"""
	if _tx_open:
		return _refuse(REFUSE_TRANSACTION_OPEN)
	if authority != null and not authority.has_method(EQUIPMENT_ATTESTATION_METHOD):
		return _refuse(REFUSE_INVALID_EQUIPMENT_AUTHORITY)
	if authority == null and _equipped_lot_count > 0:
		return _refuse(REFUSE_EQUIPPED_LOTS_LIVE)
	_equipment_authority = authority
	return _ok(NULL_REF, _equipped_lot_count)


func has_equipment_authority() -> bool:
	"""True when an equipment authority is bound and a lot may therefore be proved equipped."""
	return _equipment_authority != null


func _attests(lot_ref: Vector2i) -> bool:
	"""Ask the bound authority to prove this lot is an equipped record with a live owner.

	The ONE place this module calls out to another object. `_attesting` is raised across the
	call so `_guard()` refuses every mutator while it runs: an authority that re-entered and
	mutated would otherwise land inside an operation this module is still validating. No `_math`
	or `_plan` value may be held across this call, and nothing on a tick path calls it -- equip,
	unequip and audit() only.
	"""
	if _equipment_authority == null:
		return false
	_attesting = true
	var attested: bool = bool(_equipment_authority.call(EQUIPMENT_ATTESTATION_METHOD, lot_ref))
	_attesting = false
	return attested


func is_lot_equipped(lot_ref: Vector2i) -> bool:
	"""True when this live lot is held as equipment and therefore sits in no container.

	The single field `container_slot` decides this, and it is the same field that decides which
	container list the lot is threaded into -- which is why a lot cannot be both.
	"""
	return is_lot_valid(lot_ref) and _l_container_slot[lot_ref.x] == NULL_SLOT


func equipped_lot_count() -> int:
	"""Number of live lots currently held as equipment rather than in a container."""
	return _equipped_lot_count


func preflight_detach_to_equipment(lot_ref: Vector2i) -> OpResult:
	"""Answer "could this lot be equipped?" without writing a byte. `.value` is the grams freed.

	The allocate-before-consume half: `gear.equip()` asks this before it writes the owner, the
	equipped flag or the resident's Equipment mirror, so a refusal costs nothing. It therefore
	runs BEFORE the record could possibly attest, and does not demand the proof -- which is
	exactly why `detach_lot_to_equipment()` demands it again for itself.
	"""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return _refuse(guard)
	var code: StringName = _check_detach(lot_ref, false)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _ok(lot_ref, lot_debit_g(lot_ref))


func detach_lot_to_equipment(lot_ref: Vector2i) -> OpResult:
	"""Take a proved equipped lot out of its container, keeping the very same lot row alive.

	`.value` is the mass the container gives back. The lot is not cloned, not split, not merged
	and not re-aged: exactly one column changes meaning -- its container becomes the null ref --
	and the quantity, quality, age, provenance, recipe and generation are untouched, which is
	what "preserve one item identity and durability" requires of this side.
	"""
	var owned: bool = _enter()
	return _leave(owned, _detach_checked(lot_ref))


func _detach_checked(lot_ref: Vector2i) -> StringName:
	"""Validate completely, then unlink the lot and give its mass back to the container."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var code: StringName = _check_detach(lot_ref, true)
	if code != REFUSE_NONE:
		return code
	var slot: int = lot_ref.x
	var container_slot: int = _l_container_slot[slot]
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot],
			_item_mass_g[_l_item_id[slot]], _math):
		return REFUSE_OVERFLOW
	var debit_g: int = _math.value
	_journal_lot(slot)
	_journal_container(container_slot)
	_unlink_lot(slot)
	_credit_container(container_slot, -debit_g)
	_l_container_slot[slot] = NULL_SLOT
	_l_container_generation[slot] = NULL_GENERATION
	_equipped_lot_count += 1
	return _succeed(lot_ref, debit_g)


func _check_detach(lot_ref: Vector2i, require_attestation: bool) -> StringName:
	"""Every precondition for nulling a container. REFUSE_NONE only when it is PROVED equipped.

	The attestation is last and is the one that matters: without a bound authority, or for a lot
	the authority does not recognise as an equipped record with a live owner, this refuses. That
	is the whole difference between this amendment and permission for orphan lots.

	`require_attestation` is false only for the preflight, which by construction runs before
	`gear.gd` has written the equipped flag and so cannot see the proof yet. Every path that
	actually writes passes true; a bound authority is required either way.
	"""
	if _equipment_authority == null:
		return REFUSE_NO_EQUIPMENT_AUTHORITY
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if _l_container_slot[lot_ref.x] == NULL_SLOT:
		return REFUSE_LOT_EQUIPPED
	if _l_reserved_milli[lot_ref.x] != 0:
		return REFUSE_LOT_HAS_RESERVATION
	if require_attestation and not _attests(lot_ref):
		return REFUSE_NOT_AN_EQUIPPED_RECORD
	return REFUSE_NONE


func preflight_attach_equipped_lot(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> OpResult:
	"""Answer "could this equipped lot be shelved here?" without writing a byte.

	`.value` is the grams the destination would take. `gear.unequip()` asks this before it
	clears the equipped flag, so a destination that cannot hold the lot costs nothing.
	"""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return _refuse(guard)
	var code: StringName = _check_attach(lot_ref, dest_ref, from_reserved_mass, true)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _ok(lot_ref, lot_debit_g(lot_ref))


func attach_equipped_lot(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> OpResult:
	"""Put THE SAME equipped lot back into a valid destination container. `.value` is its mass.

	`from_reserved_mass` spends grams the destination already reserved for this lot, which is
	what the ruling's "valid reserved destination" buys: used and reserved move by the same
	amount in one step, so a reserved unequip cannot lose the space it was promised between the
	reservation and its arrival. With false, the destination is checked against its free mass.
	Durability, age, quantity and the lot's generation are not touched by either path.
	"""
	var owned: bool = _enter()
	return _leave(owned, _attach_checked(lot_ref, dest_ref, from_reserved_mass))


func _attach_checked(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> StringName:
	"""Validate completely, then relink the lot and charge the destination."""
	var guard: StringName = _guard()
	if guard != REFUSE_NONE:
		return guard
	var code: StringName = _check_attach(lot_ref, dest_ref, from_reserved_mass, false)
	if code != REFUSE_NONE:
		return code
	var slot: int = lot_ref.x
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot],
			_item_mass_g[_l_item_id[slot]], _math):
		return REFUSE_OVERFLOW
	var debit_g: int = _math.value
	_apply_attach(slot, dest_ref, debit_g, from_reserved_mass)
	return _succeed(lot_ref, debit_g)


func _check_attach(lot_ref: Vector2i, dest_ref: Vector2i, from_reserved_mass: bool,
		attesting_allowed: bool) -> StringName:
	"""Every precondition for restoring an equipped lot to a container.

	`attesting_allowed` is true only for the preflight, which runs BEFORE `gear.gd` clears the
	equipped flag and so must still see the record attest. The real operation demands the
	opposite: a lot the authority still calls equipped may not be shelved, because that is
	precisely the state in which it would charge a container AND count as equipped.
	"""
	if _equipment_authority == null:
		return REFUSE_NO_EQUIPMENT_AUTHORITY
	if not is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if _l_container_slot[lot_ref.x] != NULL_SLOT:
		return REFUSE_LOT_NOT_EQUIPPED
	if not is_container_valid(dest_ref):
		return REFUSE_INVALID_CONTAINER
	if not _accepts_item(dest_ref.x, _l_item_id[lot_ref.x]):
		return REFUSE_ITEM_FILTERED
	if _attests(lot_ref) and not attesting_allowed:
		return REFUSE_STILL_AN_EQUIPPED_RECORD
	return _check_attach_mass(lot_ref, dest_ref, from_reserved_mass)


func _check_attach_mass(lot_ref: Vector2i, dest_ref: Vector2i,
		from_reserved_mass: bool) -> StringName:
	"""Check the destination can take the lot, by reserved grams or by free capacity.

	Leaves nothing usable in `_math`: the caller recomputes the debit after this returns, because
	`_check_fits()` overwrites the scratch with its own running sum.
	"""
	var slot: int = lot_ref.x
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot],
			_item_mass_g[_l_item_id[slot]], _math):
		return REFUSE_OVERFLOW
	var debit_g: int = _math.value
	if from_reserved_mass:
		if _c_reserved_mass_g[dest_ref.x] < debit_g:
			return REFUSE_INSUFFICIENT_RESERVED_MASS
		return REFUSE_NONE
	return _check_fits(dest_ref.x, debit_g)


func _apply_attach(slot: int, dest_ref: Vector2i, debit_g: int,
		from_reserved_mass: bool) -> void:
	"""Write the attach: spend reserved grams when asked, relink the lot, charge the used mass."""
	_journal_lot(slot)
	_journal_container(dest_ref.x)
	if from_reserved_mass:
		_c_reserved_mass_g[dest_ref.x] -= debit_g
	_l_container_slot[slot] = dest_ref.x
	_l_container_generation[slot] = dest_ref.y
	_link_lot(slot, dest_ref.x)
	_credit_container(dest_ref.x, debit_g)
	_equipped_lot_count -= 1


# --- Queries ----------------------------------------------------------------------------------

func is_lot_valid(lot_ref: Vector2i) -> bool:
	"""True when the ref names a live lot at the generation it was issued for."""
	var slot: int = lot_ref.x
	if slot < 0 or slot >= _l_capacity:
		return false
	return _l_live[slot] == 1 and _l_generation[slot] == lot_ref.y


func is_container_valid(container_ref: Vector2i) -> bool:
	"""True when the ref names a live container at the generation it was issued for."""
	var slot: int = container_ref.x
	if slot < 0 or slot >= _c_capacity:
		return false
	return _c_live[slot] == 1 and _c_generation[slot] == container_ref.y


func lot_quantity_milli(lot_ref: Vector2i) -> int:
	"""Total quantity on a lot in milli-units, or 0 for an invalid ref."""
	return _l_quantity_milli[lot_ref.x] if is_lot_valid(lot_ref) else 0


func lot_reserved_milli(lot_ref: Vector2i) -> int:
	"""Claimed quantity on a lot in milli-units, or 0 for an invalid ref."""
	return _l_reserved_milli[lot_ref.x] if is_lot_valid(lot_ref) else 0


func lot_available_milli(lot_ref: Vector2i) -> int:
	"""Unclaimed quantity on a lot: quantity_milli - reserved_milli."""
	if not is_lot_valid(lot_ref):
		return 0
	return _l_quantity_milli[lot_ref.x] - _l_reserved_milli[lot_ref.x]


func lot_item_id(lot_ref: Vector2i) -> int:
	"""Item id carried by a lot, or -1 for an invalid ref."""
	return _l_item_id[lot_ref.x] if is_lot_valid(lot_ref) else -1


func lot_quality(lot_ref: Vector2i) -> int:
	"""Quality grade of a lot, or -1 for an invalid ref."""
	return _l_quality[lot_ref.x] if is_lot_valid(lot_ref) else -1


func lot_provenance(lot_ref: Vector2i) -> int:
	"""Provenance member of a lot, or -1 for an invalid ref.

	-1 IS NOT A PROVENANCE. PROV-R01 publishes exactly 0..5 and `_check_lot_provenance()` is the
	only door into the column, so no live lot can carry -1 and a caller cannot mistake the
	invalid-ref answer for an origin. `lot_provenance_into()` is the refusal-carrying form for a
	caller that must distinguish the two without allocating.
	"""
	return _l_provenance[lot_ref.x] if is_lot_valid(lot_ref) else -1


func lot_provenance_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Write a lot's provenance member into `out`, or refuse with a zeroed value channel.

	The `_into` form allocates nothing: `out` is the caller's reused IntResult. A refusal zeroes
	the value, so an ignored `false` cannot surface 0 -- ORDINARY -- as if it were an answer,
	which is precisely the confusion a default-is-a-real-member domain would otherwise invite.
	"""
	if not is_lot_valid(lot_ref):
		return out.refuse("no live lot at (%d, %d)" % [lot_ref.x, lot_ref.y])
	return out.succeed(_l_provenance[lot_ref.x])


func lot_recipe_id(lot_ref: Vector2i) -> int:
	"""Recipe id recorded on a lot, or -1 for an invalid ref."""
	return _l_recipe_id[lot_ref.x] if is_lot_valid(lot_ref) else -1


func lot_age_milli_hours(lot_ref: Vector2i) -> int:
	"""Effective storage age of a lot in milli-hours, or -1 for an invalid ref."""
	return _l_age_milli_hours[lot_ref.x] if is_lot_valid(lot_ref) else -1


func lot_age_remainder(lot_ref: Vector2i) -> int:
	"""Retained sub-milli-hour aging remainder of a lot, or -1 for an invalid ref."""
	return _l_age_remainder[lot_ref.x] if is_lot_valid(lot_ref) else -1


func lot_container(lot_ref: Vector2i) -> Vector2i:
	"""Container ref holding a lot, or the null ref for an invalid lot ref."""
	if not is_lot_valid(lot_ref):
		return NULL_REF
	return Vector2i(_l_container_slot[lot_ref.x], _l_container_generation[lot_ref.x])


func container_used_mass_g(container_ref: Vector2i) -> int:
	"""Charged mass currently held: sum over lots of ceil_div(quantity_milli*mass_g, 1000)."""
	return _c_used_mass_g[container_ref.x] if is_container_valid(container_ref) else 0


func container_reserved_mass_g(container_ref: Vector2i) -> int:
	"""Mass committed to undelivered output, counted against capacity beside the held mass."""
	return _c_reserved_mass_g[container_ref.x] if is_container_valid(container_ref) else 0


func container_max_mass_g(container_ref: Vector2i) -> int:
	"""Capacity limit of a container in grams, or 0 for an invalid ref."""
	return _c_max_mass_g[container_ref.x] if is_container_valid(container_ref) else 0


func container_free_mass_g(container_ref: Vector2i) -> int:
	"""Grams still admissible: max_mass_g - used_mass_g - reserved_mass_g, never below 0."""
	if not is_container_valid(container_ref):
		return 0
	var slot: int = container_ref.x
	return maxi(0, _c_max_mass_g[slot] - _c_used_mass_g[slot] - _c_reserved_mass_g[slot])


func container_lot_count(container_ref: Vector2i) -> int:
	"""Number of live lots in a container, or 0 for an invalid ref."""
	return _c_lot_count[container_ref.x] if is_container_valid(container_ref) else 0


func container_filters(container_ref: Vector2i) -> int:
	"""64-bit category admission mask of a container, or 0 for an invalid ref."""
	return _c_filters[container_ref.x] if is_container_valid(container_ref) else 0


func container_policy(container_ref: Vector2i) -> int:
	"""Stored policy enum of a container. Interpretation belongs to the logistics layer."""
	return _c_policy[container_ref.x] if is_container_valid(container_ref) else -1


func container_owner(container_ref: Vector2i) -> Vector2i:
	"""Owner ref of a container, or the null ref for an invalid ref."""
	if not is_container_valid(container_ref):
		return NULL_REF
	return Vector2i(_c_owner_slot[container_ref.x], _c_owner_generation[container_ref.x])


func owner_query_cells() -> int:
	"""How many int32 cells a caller must own to hold this store's largest owner-query result.

	Two per container row, because the query writes complete `(slot, generation)` pairs and one
	owner could in principle key every live container. A caller sizes its scratch from THIS
	rather than from a number of its own choosing: a hand-picked buffer is a cap on how much
	stranded stock a demolition gate can see, and INV-GOODS-R01 requires the query to account
	for the caller's scratch instead of truncating into it.
	"""
	return _c_capacity * 2


func containers_by_owner_into(owner_ref: Vector2i, out_pairs: PackedInt32Array,
		out: IntMath.IntResult) -> bool:
	"""Write every live container whose stored owner equals `owner_ref` into the caller's buffer.

	INV-GOODS-R01's bounded owner scan, and the whole of it. `owner_ref` is a DIRECTORY ref; the
	pairs written are INVENTORY-CONTAINER refs, flat as `slot, generation, slot, generation, ...`
	in ascending container-slot order, which is deterministic because it is the row order itself
	and not a hash or an insertion order. `out.value` is the number of PAIRS, so the cells
	written are `2 * out.value`; anything past that in the buffer is the caller's own residue and
	is neither read nor cleared here.

	IT REFUSES RATHER THAN MISLEADS. A malformed owner -- the null ref, a negative slot, a
	generation of 0 -- refuses INVALID_OWNER_REF instead of matching the unvalidated owner
	residue of rows nobody owns. A buffer too small for the COMPLETE result refuses
	OWNER_OUTPUT_TOO_SMALL and writes nothing at all, which is why the count is taken in a first
	pass before a single cell is written. Both zero `out.value`.

	Read-only: no column is returned, no live view escapes, no row is touched, and no reverse
	index is built or kept. Costs one pass over the occupied part of the container store per
	pass, which is why it belongs on a cold destructive path and not on a tick.
	"""
	if owner_ref.x < 0 or owner_ref.y <= 0:
		return out.refuse(String(REFUSE_INVALID_OWNER_REF))
	var found: int = _count_containers_of_owner(owner_ref)
	if out_pairs.size() < found * 2:
		return out.refuse(String(REFUSE_OWNER_OUTPUT_TOO_SMALL))
	_write_containers_of_owner(owner_ref, out_pairs)
	return out.succeed(found)


func _owns_container(slot: int, owner_ref: Vector2i) -> bool:
	"""Whether one LIVE container row carries exactly this COMPLETE owner pair.

	Both fields, always. A dead row keeps the owner it had -- `destroy_container()` clears only
	`_c_live` -- so the liveness test is what stops a retired container being reported as
	stranded stock, and comparing the slot alone would match an owner whose directory slot has
	since been reused by an unrelated entity at a later generation.
	"""
	if _c_live[slot] != 1:
		return false
	return _c_owner_slot[slot] == owner_ref.x and _c_owner_generation[slot] == owner_ref.y


func _count_containers_of_owner(owner_ref: Vector2i) -> int:
	"""Count the live containers of one owner, bounded by the highest slot ever handed out."""
	var found: int = 0
	for slot: int in range(_c_slot_high_water):
		if _owns_container(slot, owner_ref):
			found += 1
	return found


func _write_containers_of_owner(owner_ref: Vector2i, out_pairs: PackedInt32Array) -> void:
	"""Write the owner's container refs as flat ascending pairs. Capacity is checked by then."""
	var cell: int = 0
	for slot: int in range(_c_slot_high_water):
		if not _owns_container(slot, owner_ref):
			continue
		out_pairs[cell] = slot
		out_pairs[cell + 1] = _c_generation[slot]
		cell += 2


func container_reachable(container_ref: Vector2i) -> bool:
	"""True when a container is currently reachable for hauling."""
	return _c_reachable[container_ref.x] == 1 if is_container_valid(container_ref) else false


func container_first_lot(container_ref: Vector2i) -> Vector2i:
	"""Head of a container's lot list, for deterministic iteration with container_next_lot()."""
	if not is_container_valid(container_ref):
		return NULL_REF
	return _lot_ref_of(_c_first_lot[container_ref.x])


func container_next_lot(lot_ref: Vector2i) -> Vector2i:
	"""Next lot after `lot_ref` in its container's list, or the null ref at the end."""
	if not is_lot_valid(lot_ref):
		return NULL_REF
	return _lot_ref_of(_l_next[lot_ref.x])


func _lot_ref_of(slot: int) -> Vector2i:
	"""Wrap a raw lot slot as a ref, mapping NULL_SLOT to the null ref."""
	if slot == NULL_SLOT:
		return NULL_REF
	return Vector2i(slot, _l_generation[slot])


func live_lot_count() -> int:
	"""Number of live lot rows across every container."""
	return _l_live_count


func live_container_count() -> int:
	"""Number of live container rows."""
	return _c_live_count


func total_sourced_milli(item_id: int) -> int:
	"""Total quantity of an item ever introduced by create_lot()."""
	if item_id < 0 or item_id >= ITEM_CAPACITY:
		return 0
	return _sourced_milli[item_id]


func total_sunk_milli(item_id: int) -> int:
	"""Total quantity of an item ever consumed by a sink."""
	if item_id < 0 or item_id >= ITEM_CAPACITY:
		return 0
	return _sunk_milli[item_id]


func total_live_milli(item_id: int) -> int:
	"""Quantity of an item currently held across every container, re-derived from the rows.

	DIAGNOSTIC, not a per-tick query: it walks the lot column rather than reading a
	maintained total. The walk is bounded by the highest slot ever allocated, so it costs
	occupancy and not the 16384-row capacity, but it is still a linear scan.
	"""
	var total: int = 0
	for slot: int in range(_l_slot_high_water):
		if _l_live[slot] == 1 and _l_item_id[slot] == item_id:
			total += _l_quantity_milli[slot]
	return total


func total_equipped_milli(item_id: int) -> int:
	"""Quantity of an item currently held as equipment, charged to no container at all.

	DIAGNOSTIC, like total_live_milli(): a bounded walk of the lot column, not a tick query.
	"""
	var total: int = 0
	for slot: int in range(_l_slot_high_water):
		if _l_live[slot] != 1 or _l_item_id[slot] != item_id:
			continue
		if _l_container_slot[slot] == NULL_SLOT:
			total += _l_quantity_milli[slot]
	return total


func total_loose_milli(item_id: int) -> int:
	"""Loose stock: the quantity of an item sitting in containers and available to be claimed.

	DERIVED BY SUBTRACTION ON PURPOSE. `loose + equipped == live` then holds by construction
	rather than by two walks agreeing, so no arrangement of the columns can count one lot as
	both loose stock and equipment. That double count is the defect ruling §4 names, and this is
	what makes it unrepresentable instead of merely tested.
	"""
	return total_live_milli(item_id) - total_equipped_milli(item_id)


# --- Audit ------------------------------------------------------------------------------------

func audit() -> OpResult:
	"""Re-derive every invariant from the row columns and refuse on the first violation.

	NOT A PRODUCTION CALL. This is a verification tool for tests, save/load checks and debug
	builds. Do NOT call it from a simulation tick, a UI refresh, or any per-frame path: it
	re-derives conservation per item, `reserved <= quantity` per lot, and every container's
	used mass, lot count and capacity bound from a fresh walk, trusting no running total.
	That is the whole point of it, and it is why it costs a full pass over the occupied part
	of both stores. Measured at spec capacity, it costs 2.1 ms with 2000 containers and 2000
	lots live -- past the 2 ms economy-tick budget on its own, at a fraction of full.

	The passes are bounded by the highest slot each store has ever handed out rather than by
	capacity, so an audit of a lightly occupied store is proportional to what it holds. The
	invariants checked are exactly the same; only the range that cannot contain a live row is
	skipped.
	"""
	var code: StringName = _audit_lots()
	if code == REFUSE_NONE:
		code = _audit_containers()
	if code == REFUSE_NONE:
		code = _audit_conservation()
	return _ok(NULL_REF, 0) if code == REFUSE_NONE else _refuse(code)


func _audit_lots() -> StringName:
	"""Verify the reservation bound and the container/equipped placement of every live lot."""
	var equipped: int = 0
	for slot: int in range(_l_slot_high_water):
		if _l_live[slot] != 1:
			continue
		if _l_reserved_milli[slot] > _l_quantity_milli[slot] or _l_reserved_milli[slot] < 0:
			return REFUSE_AUDIT_RESERVED
		var placement: StringName = _audit_lot_placement(slot)
		if placement != REFUSE_NONE:
			return placement
		if _l_container_slot[slot] == NULL_SLOT:
			equipped += 1
	if equipped != _equipped_lot_count:
		return REFUSE_AUDIT_EQUIPPED_COUNT
	return REFUSE_NONE


func _audit_lot_placement(slot: int) -> StringName:
	"""Re-derive the biconditional: a lot has no container IF AND ONLY IF it is proved equipped.

	Both directions are checked, and the second is the double-count guard: a lot that the
	authority still calls equipped while it sits in a container would charge that container's
	mass and be equipment at the same time. Costs one attestation per live lot, which is why
	audit() is documented as a diagnostic and never runs on a tick. With no authority bound
	`_attests()` is false for every lot, so a detached lot fails the biconditional there rather
	than needing a second unbound-store branch.
	"""
	var detached: bool = _l_container_slot[slot] == NULL_SLOT
	if detached and (_l_next[slot] != NULL_SLOT or _l_prev[slot] != NULL_SLOT):
		return REFUSE_AUDIT_ORPHAN_LOT
	if detached and _l_reserved_milli[slot] != 0:
		return REFUSE_AUDIT_ORPHAN_LOT
	if _attests(_lot_ref_of(slot)) != detached:
		return REFUSE_AUDIT_ORPHAN_LOT
	return REFUSE_NONE


func _audit_containers() -> StringName:
	"""Verify every live container's cached mass, lot count and capacity bound from its rows."""
	for slot: int in range(_c_slot_high_water):
		if _c_live[slot] != 1:
			continue
		var row: StringName = _audit_container_row(slot)
		if row != REFUSE_NONE:
			return row
	return REFUSE_NONE


func _audit_container_row(slot: int) -> StringName:
	"""Re-walk one container's lot list and compare the derived mass and count to the cache.

	THE WALK IS BOUNDED. A container cannot legally hold more lots than the store has rows, so a
	walk that passes that bound has found a cycle in the intrusive list and says so. Without the
	bound this loop is the one place in the module that can hang instead of refusing -- a
	corrupted `_l_next` turns a diagnostic into an unkillable process, which is exactly how a
	runaway was produced while mutation-testing this change.
	"""
	var mass: int = 0
	var count: int = 0
	var lot: int = _c_first_lot[slot]
	while lot != NULL_SLOT:
		if count > _l_capacity:
			return REFUSE_AUDIT_LOT_CYCLE
		if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[lot], _item_mass_g[_l_item_id[lot]], _math):
			return REFUSE_OVERFLOW
		if not IntMath.checked_add_into(mass, _math.value, _math):
			return REFUSE_OVERFLOW
		mass = _math.value
		count += 1
		lot = _l_next[lot]
	if count != _c_lot_count[slot]:
		return REFUSE_AUDIT_LOT_COUNT
	if mass != _c_used_mass_g[slot]:
		return REFUSE_AUDIT_MASS
	return _audit_container_capacity(slot)


func _audit_container_capacity(slot: int) -> StringName:
	"""Re-derive BAL-SAFE-002's own bound: `used + reserved <= max`, with a checked sum.

	Matching the cached used mass to a lot walk says nothing about whether the container is
	over its limit, so the invariant the specification actually states is re-checked here
	rather than assumed to follow from the operations that maintained it.
	"""
	if _c_used_mass_g[slot] < 0 or _c_reserved_mass_g[slot] < 0:
		return REFUSE_AUDIT_CAPACITY
	if not IntMath.checked_add_into(_c_used_mass_g[slot], _c_reserved_mass_g[slot], _math):
		return REFUSE_AUDIT_CAPACITY
	if _math.value > _c_max_mass_g[slot]:
		return REFUSE_AUDIT_CAPACITY
	return REFUSE_NONE


func _audit_conservation() -> StringName:
	"""Verify `live + sunk == sourced` for every item, from one pass over the lot columns.

	The per-item tally is the column allocated in _init() and refilled here, never a fresh
	array resized per call (ARCH-MEM-005 allocates once).
	"""
	_audit_live_milli.fill(0)
	for slot: int in range(_l_slot_high_water):
		if _l_live[slot] == 1:
			_audit_live_milli[_l_item_id[slot]] += _l_quantity_milli[slot]
	for item_id: int in range(ITEM_CAPACITY):
		if _item_registered[item_id] != 1:
			continue
		if _audit_live_milli[item_id] + _sunk_milli[item_id] != _sourced_milli[item_id]:
			return REFUSE_AUDIT_CONSERVATION
	return REFUSE_NONE


func state_bytes() -> PackedByteArray:
	"""Exact serialization of all authoritative state, for byte-identical rollback checks.

	NOT A PRODUCTION CALL, and the most expensive method on this class. It builds a fresh
	buffer holding every column at its FULL allocated length -- roughly 7.5 MB at spec
	capacity, in milliseconds -- so that two images can be compared byte for byte. Use it in
	tests and verification harnesses only; never on a tick, a frame, or a UI refresh.

	Unlike audit(), this one cannot be bounded to occupancy: the comparison it exists for
	requires the image to depend on authoritative state alone. Trimming it to the highest
	slot allocated so far would make two images of identical state differ in length whenever
	an allocation happened and was rolled back between them, which is precisely the case the
	rollback checks are testing.

	The journal arena is excluded: it is scratch that both commit() and rollback() reset, and
	its residue is not part of the simulation. The high-water scan bounds are excluded for
	the same reason -- they are not state.
	"""
	var out: PackedByteArray = PackedByteArray()
	_append_lot_state(out)
	_append_container_state(out)
	out.append_array(var_to_bytes(_sourced_milli))
	out.append_array(var_to_bytes(_sunk_milli))
	out.append_array(var_to_bytes(_item_mass_g))
	out.append_array(var_to_bytes(_item_category))
	out.append_array(var_to_bytes(_item_registered))
	out.append_array(var_to_bytes(PackedInt64Array([_c_free_count, _l_free_count, _c_live_count,
		_l_live_count, _equipped_lot_count])))
	return out


func _append_lot_state(out: PackedByteArray) -> void:
	"""Append every lot column and the lot free stack to a state serialization."""
	out.append_array(var_to_bytes(_l_item_id))
	out.append_array(var_to_bytes(_l_quality))
	out.append_array(var_to_bytes(_l_provenance))
	out.append_array(var_to_bytes(_l_recipe_id))
	out.append_array(var_to_bytes(_l_container_slot))
	out.append_array(var_to_bytes(_l_container_generation))
	out.append_array(var_to_bytes(_l_generation))
	out.append_array(var_to_bytes(_l_next))
	out.append_array(var_to_bytes(_l_prev))
	out.append_array(var_to_bytes(_l_quantity_milli))
	out.append_array(var_to_bytes(_l_reserved_milli))
	out.append_array(var_to_bytes(_l_age_milli_hours))
	out.append_array(var_to_bytes(_l_age_remainder))
	out.append_array(var_to_bytes(_l_live))
	out.append_array(var_to_bytes(_l_free))


func _append_container_state(out: PackedByteArray) -> void:
	"""Append every container column and the container free stack to a state serialization."""
	out.append_array(var_to_bytes(_c_owner_slot))
	out.append_array(var_to_bytes(_c_owner_generation))
	out.append_array(var_to_bytes(_c_policy))
	out.append_array(var_to_bytes(_c_generation))
	out.append_array(var_to_bytes(_c_lot_count))
	out.append_array(var_to_bytes(_c_first_lot))
	out.append_array(var_to_bytes(_c_max_mass_g))
	out.append_array(var_to_bytes(_c_filters))
	out.append_array(var_to_bytes(_c_reserved_mass_g))
	out.append_array(var_to_bytes(_c_used_mass_g))
	out.append_array(var_to_bytes(_c_live))
	out.append_array(var_to_bytes(_c_reachable))
	out.append_array(var_to_bytes(_c_free))


func _ok(ref: Vector2i, value: int) -> OpResult:
	"""Build a successful result."""
	return OpResult.new(true, REFUSE_NONE, ref, value)


func _refuse(code: StringName) -> OpResult:
	"""Build an explicit refusal carrying no partially applied effect."""
	return OpResult.new(false, code, NULL_REF, 0)


# --- INV-CANON-R01: the quiescent canonical save/hash projection -------------------------------
#
# WHY THIS IS NOT A CHANGE TO RETIREMENT.
#
# `_retire_lot()` unlinks a lot, clears its occupancy byte and advances its generation. It
# deliberately LEAVES the attributes behind, and that is load-bearing: `_apply_transfer()`
# retires the source BEFORE `_credit_new_lot()` reads its item, quality, provenance and recipe,
# and with one free lot slot the allocator hands back the SAME physical slot under a new
# generation. A "tidy" blanking clear inside `_retire_lot()` would therefore destroy the
# attributes the very next statement reads. INV-CANON-R01 answers that by putting normalization
# where it costs nothing and breaks nothing: in a caller-owned copy taken at a completed,
# quiescent boundary. Nothing below writes a single byte of the live columns.
#
# WHAT THE COPY CHANGES, AND WHAT IT MUST NOT.
#
# A row whose `_c_live`/`_l_live` is 1 is copied EXACTLY. Liveness is decided by the occupancy
# byte alone -- never by container nullness (decision 0061's equipped record is live and has a
# null container), never by quantity, reachability or membership in any list.
#
# A row whose occupancy is 0 is emitted at the ruling's unused-value table, which is this
# module's own clear-state spelling: NULL_SLOT for a slot, NULL_GENERATION for a reference
# generation, UNSET_POLICY, UNSET_PROVENANCE (which is ORDINARY, a real member and not an
# unknown wildcard) and 0 for every count, mass, quantity and age.
#
# THE ROW'S OWN GENERATION IS NEVER MASKED. `_c_generation`/`_l_generation` are copied unchanged
# for live and inactive rows alike, and both free stacks keep their exact used prefix in pop
# order. That is what preserves the three distinct states INT32_MAX can be in: a slot freed from
# INT32_MAX-1 is pushed AT INT32_MAX and is still available for one final allocation (free-MAX);
# a live row may sit at INT32_MAX (live-MAX); an inactive row off the prefix at INT32_MAX is
# retired (retired-MAX). Prefix membership and occupancy are what tell them apart. Collapsing
# any two of the three -- by rebuilding the stack, by filtering MAX rows out of it, or by
# zeroing an inactive generation -- is a defect, not a simplification.
#
# WHY THIS IS NOT `state_bytes()`. That remains the full rollback/debug image and deliberately
# keeps stale payload; a failed transaction must restore it byte for byte. This projection is
# the CANONICAL representation and nothing else consumes it.
#
# THE RESERVED-MERGE RESIDUE. `_apply_merge()` moves the source's reserved quantity onto the
# destination and leaves the number behind in the dead source, so a reachable state is dead
# quantity 0 / dead reserved 250 beside a live destination correctly holding reserved 250. The
# live audit passes, and a raw serialization followed by an unconditional `reserved <= quantity`
# check would reject it. The projection writes the dead row's reserved as 0 and retains the live
# claim, which is one claim and not two: occupancy is decisive. External Reservation rows are a
# different store and still need their own retargeting and cross-store validation.

## INV-CANON-R01 adopts `(section 7, inventory)` owner schema 3. Declared here, beside the
## projection it describes, and READ by `save_section_inventories.gd` rather than restated there.
const CANONICAL_OWNER_SCHEMA_VERSION: int = 3

## Every instantiated inventory generation is in 1..INT32_MAX: `_init()` calls `clear()`, which
## steps each column from 0 to 1. A zero-generation inactive row passed the older loose codec
## check and is REFUSED here. A virgin zero-generation scheme would need its own allocator
## contract; this one has none.
const CANONICAL_GENERATION_MIN: int = 1

const REFUSE_CANONICAL_NOT_QUIESCENT: StringName = &"CANONICAL_NOT_QUIESCENT"
const REFUSE_CANONICAL_EXTENT: StringName = &"CANONICAL_EXTENT"
const REFUSE_CANONICAL_OCCUPANCY: StringName = &"CANONICAL_OCCUPANCY"
const REFUSE_CANONICAL_GENERATION: StringName = &"CANONICAL_GENERATION"
const REFUSE_CANONICAL_FREE_STACK: StringName = &"CANONICAL_FREE_STACK"
const REFUSE_CANONICAL_SLOT_UNACCOUNTED: StringName = &"CANONICAL_SLOT_UNACCOUNTED"
const REFUSE_CANONICAL_INACTIVE_PAYLOAD: StringName = &"CANONICAL_INACTIVE_PAYLOAD"
const REFUSE_CANONICAL_LIVE_ROW: StringName = &"CANONICAL_LIVE_ROW"
const REFUSE_CANONICAL_AUDIT: StringName = &"CANONICAL_AUDIT"


class CanonicalColumns:
	"""One caller-owned, bounded, normalized inventory projection. Never a second world.

	Every column is allocated once here at the store's declared capacity and is never resized.
	This is the SAME declared projection the section 7 encoder and the section 15 canonical
	adapter both read, so a save and a hash cannot implement competing masks.

	The two free stacks are held at full backing capacity with a `NULL_SLOT` tail; only
	`c_free_count` / `l_free_count` entries are logical, and the tail is excluded from the saved
	field count. It exists so two projections of the same state compare equal byte for byte.
	"""
	var container_capacity: int = 0
	var lot_capacity: int = 0
	var c_free_count: int = 0
	var l_free_count: int = 0
	var c_live: PackedByteArray = PackedByteArray()
	var c_reachable: PackedByteArray = PackedByteArray()
	var c_generation: PackedInt32Array = PackedInt32Array()
	var c_owner_slot: PackedInt32Array = PackedInt32Array()
	var c_owner_generation: PackedInt32Array = PackedInt32Array()
	var c_policy: PackedInt32Array = PackedInt32Array()
	var c_lot_count: PackedInt32Array = PackedInt32Array()
	var c_first_lot: PackedInt32Array = PackedInt32Array()
	var c_free: PackedInt32Array = PackedInt32Array()
	var c_max_mass_g: PackedInt64Array = PackedInt64Array()
	var c_filters: PackedInt64Array = PackedInt64Array()
	var c_reserved_mass_g: PackedInt64Array = PackedInt64Array()
	var c_used_mass_g: PackedInt64Array = PackedInt64Array()
	var l_live: PackedByteArray = PackedByteArray()
	var l_generation: PackedInt32Array = PackedInt32Array()
	var l_item_id: PackedInt32Array = PackedInt32Array()
	var l_quality: PackedInt32Array = PackedInt32Array()
	var l_provenance: PackedInt32Array = PackedInt32Array()
	var l_recipe_id: PackedInt32Array = PackedInt32Array()
	var l_container_slot: PackedInt32Array = PackedInt32Array()
	var l_container_generation: PackedInt32Array = PackedInt32Array()
	var l_next: PackedInt32Array = PackedInt32Array()
	var l_prev: PackedInt32Array = PackedInt32Array()
	var l_free: PackedInt32Array = PackedInt32Array()
	var l_quantity_milli: PackedInt64Array = PackedInt64Array()
	var l_reserved_milli: PackedInt64Array = PackedInt64Array()
	var l_age_milli_hours: PackedInt64Array = PackedInt64Array()
	var l_age_remainder: PackedInt64Array = PackedInt64Array()

	func _init(p_container_capacity: int, p_lot_capacity: int) -> void:
		"""Allocate all 28 columns at the two declared capacities. The only resize here."""
		container_capacity = p_container_capacity
		lot_capacity = p_lot_capacity
		_allocate_container_columns()
		_allocate_lot_columns()

	func _allocate_container_columns() -> void:
		"""Size the thirteen container columns to the container capacity, once."""
		c_live.resize(container_capacity)
		c_reachable.resize(container_capacity)
		c_generation.resize(container_capacity)
		c_owner_slot.resize(container_capacity)
		c_owner_generation.resize(container_capacity)
		c_policy.resize(container_capacity)
		c_lot_count.resize(container_capacity)
		c_first_lot.resize(container_capacity)
		c_free.resize(container_capacity)
		c_max_mass_g.resize(container_capacity)
		c_filters.resize(container_capacity)
		c_reserved_mass_g.resize(container_capacity)
		c_used_mass_g.resize(container_capacity)

	func _allocate_lot_columns() -> void:
		"""Size the fifteen lot columns to the lot capacity, once."""
		l_live.resize(lot_capacity)
		l_generation.resize(lot_capacity)
		l_item_id.resize(lot_capacity)
		l_quality.resize(lot_capacity)
		l_provenance.resize(lot_capacity)
		l_recipe_id.resize(lot_capacity)
		l_container_slot.resize(lot_capacity)
		l_container_generation.resize(lot_capacity)
		l_next.resize(lot_capacity)
		l_prev.resize(lot_capacity)
		l_free.resize(lot_capacity)
		l_quantity_milli.resize(lot_capacity)
		l_reserved_milli.resize(lot_capacity)
		l_age_milli_hours.resize(lot_capacity)
		l_age_remainder.resize(lot_capacity)


func canonical_capacities() -> Vector2i:
	"""This store's `(container_capacity, lot_capacity)`, so a caller can size a buffer."""
	return Vector2i(_c_capacity, _l_capacity)


func canonical_detail() -> String:
	"""Why the last canonical copy or restore refused, or an empty string after a success."""
	return _canonical_detail


func copy_canonical_columns_into(out: CanonicalColumns) -> bool:
	"""Fill `out` with this store's normalized projection. Refuses rather than capturing midway.

	ARCH-SAVE-003 saves at a completed boundary, so this refuses an open or poisoned
	transaction, a non-empty undo journal and a re-entrant attestation rather than photographing
	a half-applied transfer. It then re-derives occupancy, generations, the allocator partition
	and every live structural/accounting relationship BEFORE it copies anything, and it writes
	only into the caller's buffer -- the live columns are not touched, in this call or any other.
	"""
	_canonical_detail = ""
	var quiescent: StringName = _canonical_quiescent_refusal()
	if quiescent != REFUSE_NONE:
		return false
	if out.container_capacity != _c_capacity or out.lot_capacity != _l_capacity:
		_canonical_detail = "buffer declares %d containers and %d lots, not %d and %d" \
			% [out.container_capacity, out.lot_capacity, _c_capacity, _l_capacity]
		return false
	if _canonical_source_refusal() != REFUSE_NONE:
		return false
	_project_containers_into(out)
	_project_lots_into(out)
	_project_stacks_into(out)
	return true


func _canonical_quiescent_refusal() -> StringName:
	"""Refuse anything but a completed, non-reentrant boundary with an empty undo journal."""
	if _tx_open:
		_canonical_detail = "an inventory transaction is open"
		return REFUSE_CANONICAL_NOT_QUIESCENT
	if _tx_poisoned:
		_canonical_detail = "the last transaction is poisoned and has not been rolled back"
		return REFUSE_CANONICAL_NOT_QUIESCENT
	if _j_count != 0:
		_canonical_detail = "the undo journal holds %d entries" % _j_count
		return REFUSE_CANONICAL_NOT_QUIESCENT
	if _attesting:
		_canonical_detail = "an equipment attestation is in progress"
		return REFUSE_CANONICAL_NOT_QUIESCENT
	return REFUSE_NONE


func _canonical_source_refusal() -> StringName:
	"""Validate the live store's occupancy, generations, allocator partitions and live rows."""
	var containers: StringName = _canonical_partition_refusal(_c_live, _c_generation, _c_free,
		_c_free_count, _c_capacity, "container")
	if containers != REFUSE_NONE:
		return containers
	var lots: StringName = _canonical_partition_refusal(_l_live, _l_generation, _l_free,
		_l_free_count, _l_capacity, "lot")
	if lots != REFUSE_NONE:
		return lots
	if not audit().ok:
		_canonical_detail = "the live inventory audit refuses this state"
		return REFUSE_CANONICAL_AUDIT
	return REFUSE_NONE


func _canonical_partition_refusal(live: PackedByteArray, generation: PackedInt32Array,
		free: PackedInt32Array, free_count: int, capacity: int, label: String) -> StringName:
	"""One allocator's complete partition: every slot is live, on the used prefix, or retired.

	COLD PATH. The `seen` mask is allocated per call because this runs at a save boundary and
	never on a tick; ARCH-MEM-001's allocate-once rule governs the per-tick columns above.
	"""
	if free_count < 0 or free_count > capacity:
		_canonical_detail = "%s free count %d is outside 0..%d" % [label, free_count, capacity]
		return REFUSE_CANONICAL_FREE_STACK
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(capacity)
	seen.fill(0)
	var occupancy: StringName = _canonical_occupancy_refusal(live, generation, capacity, label)
	if occupancy != REFUSE_NONE:
		return occupancy
	var prefix: StringName = _canonical_prefix_refusal(live, free, free_count, seen, label)
	if prefix != REFUSE_NONE:
		return prefix
	return _canonical_unaccounted_refusal(live, generation, seen, label)


func _canonical_occupancy_refusal(live: PackedByteArray, generation: PackedInt32Array,
		capacity: int, label: String) -> StringName:
	"""Occupancy is exactly 0 or 1, and every generation -- live or not -- is in 1..INT32_MAX."""
	for slot: int in range(capacity):
		if live[slot] > 1:
			_canonical_detail = "%s %d holds occupancy %d, not 0 or 1" % [label, slot, live[slot]]
			return REFUSE_CANONICAL_OCCUPANCY
		if generation[slot] < CANONICAL_GENERATION_MIN or generation[slot] > MAX_INT32:
			_canonical_detail = "%s %d holds generation %d, outside %d..%d" \
				% [label, slot, generation[slot], CANONICAL_GENERATION_MIN, MAX_INT32]
			return REFUSE_CANONICAL_GENERATION
	return REFUSE_NONE


func _canonical_prefix_refusal(live: PackedByteArray, free: PackedInt32Array, free_count: int,
		seen: PackedByteArray, label: String) -> StringName:
	"""The used free prefix names distinct, in-range, non-live slots. Order is state, not sorted."""
	for index: int in range(free_count):
		var slot: int = free[index]
		if slot < 0 or slot >= seen.size():
			_canonical_detail = "%s free entry %d names slot %d, outside 0..%d" \
				% [label, index, slot, seen.size() - 1]
			return REFUSE_CANONICAL_FREE_STACK
		if seen[slot] == 1:
			_canonical_detail = "%s free stack names slot %d twice" % [label, slot]
			return REFUSE_CANONICAL_FREE_STACK
		if live[slot] == 1:
			_canonical_detail = "%s free entry %d names live slot %d" % [label, index, slot]
			return REFUSE_CANONICAL_FREE_STACK
		seen[slot] = 1
	return REFUSE_NONE


func _canonical_unaccounted_refusal(live: PackedByteArray, generation: PackedInt32Array,
		seen: PackedByteArray, label: String) -> StringName:
	"""An inactive slot OFF the prefix is retired, so its generation must be INT32_MAX.

	INT32_MAX alone does NOT mean retired. `_free_lot_slot()` increments INT32_MAX-1 to
	INT32_MAX and pushes that slot, so a free-MAX slot is on the prefix and still allocatable;
	a live-MAX row is live. Only prefix membership and occupancy separate the three.
	"""
	for slot: int in range(seen.size()):
		if live[slot] == 1 or seen[slot] == 1:
			continue
		if generation[slot] != MAX_INT32:
			_canonical_detail = ("%s %d is neither live nor on the free prefix, and its "
				+ "generation %d is not the exhausted %d retirement leaves behind") \
				% [label, slot, generation[slot], MAX_INT32]
			return REFUSE_CANONICAL_SLOT_UNACCOUNTED
	return REFUSE_NONE


func _project_containers_into(out: CanonicalColumns) -> void:
	"""Project every physical container row. No row is omitted and none is reordered."""
	for slot: int in range(_c_capacity):
		_project_container_row(out, slot)


func _project_container_row(out: CanonicalColumns, slot: int) -> void:
	"""Copy one live container exactly, or write INV-CANON-R01's unused container payload."""
	out.c_live[slot] = _c_live[slot]
	out.c_generation[slot] = _c_generation[slot]
	if _c_live[slot] == 1:
		out.c_owner_slot[slot] = _c_owner_slot[slot]
		out.c_owner_generation[slot] = _c_owner_generation[slot]
		out.c_policy[slot] = _c_policy[slot]
		out.c_lot_count[slot] = _c_lot_count[slot]
		out.c_first_lot[slot] = _c_first_lot[slot]
		out.c_max_mass_g[slot] = _c_max_mass_g[slot]
		out.c_filters[slot] = _c_filters[slot]
		out.c_reserved_mass_g[slot] = _c_reserved_mass_g[slot]
		out.c_used_mass_g[slot] = _c_used_mass_g[slot]
		out.c_reachable[slot] = _c_reachable[slot]
		return
	out.c_owner_slot[slot] = NULL_SLOT
	out.c_owner_generation[slot] = NULL_GENERATION
	out.c_policy[slot] = UNSET_POLICY
	out.c_lot_count[slot] = 0
	out.c_first_lot[slot] = NULL_SLOT
	out.c_max_mass_g[slot] = 0
	out.c_filters[slot] = 0
	out.c_reserved_mass_g[slot] = 0
	out.c_used_mass_g[slot] = 0
	out.c_reachable[slot] = 0


func _project_lots_into(out: CanonicalColumns) -> void:
	"""Project every physical lot row. No row is omitted and none is reordered."""
	for slot: int in range(_l_capacity):
		_project_lot_row(out, slot)


func _project_lot_row(out: CanonicalColumns, slot: int) -> void:
	"""Copy one live lot exactly, or write INV-CANON-R01's unused lot payload.

	A live lot's `_l_container_slot` of NULL_SLOT is decision 0061's EQUIPPED record and is
	copied as it stands; the mask is never applied on container nullness.
	"""
	out.l_live[slot] = _l_live[slot]
	out.l_generation[slot] = _l_generation[slot]
	if _l_live[slot] == 1:
		out.l_item_id[slot] = _l_item_id[slot]
		out.l_quality[slot] = _l_quality[slot]
		out.l_provenance[slot] = _l_provenance[slot]
		out.l_recipe_id[slot] = _l_recipe_id[slot]
		out.l_container_slot[slot] = _l_container_slot[slot]
		out.l_container_generation[slot] = _l_container_generation[slot]
		out.l_next[slot] = _l_next[slot]
		out.l_prev[slot] = _l_prev[slot]
		out.l_quantity_milli[slot] = _l_quantity_milli[slot]
		out.l_reserved_milli[slot] = _l_reserved_milli[slot]
		out.l_age_milli_hours[slot] = _l_age_milli_hours[slot]
		out.l_age_remainder[slot] = _l_age_remainder[slot]
		return
	_write_unused_lot_payload(out, slot)


func _write_unused_lot_payload(out: CanonicalColumns, slot: int) -> void:
	"""INV-CANON-R01's twelve unused lot values, spelled in this module's own clear sentinels.

	`_l_reserved_milli` becoming 0 is the reserved-merge residue case: `_apply_merge()` moved
	the claim to the destination and left the number on the dead source.
	"""
	out.l_item_id[slot] = 0
	out.l_quality[slot] = 0
	out.l_provenance[slot] = UNSET_PROVENANCE
	out.l_recipe_id[slot] = 0
	out.l_container_slot[slot] = NULL_SLOT
	out.l_container_generation[slot] = NULL_GENERATION
	out.l_next[slot] = NULL_SLOT
	out.l_prev[slot] = NULL_SLOT
	out.l_quantity_milli[slot] = 0
	out.l_reserved_milli[slot] = 0
	out.l_age_milli_hours[slot] = 0
	out.l_age_remainder[slot] = 0


func _project_stacks_into(out: CanonicalColumns) -> void:
	"""Copy both free stacks' used prefixes IN ORDER and canonicalise the excluded tails to -1.

	Pop order is the array permutation -- `_alloc_lot_slot()` takes `_l_free[count - 1]` -- so
	the prefix is state and is never sorted. The tail beyond the count is stale garbage two
	observably identical worlds can disagree about, and is not part of the saved field count.
	"""
	out.c_free_count = _c_free_count
	out.l_free_count = _l_free_count
	for index: int in range(_c_capacity):
		out.c_free[index] = _c_free[index] if index < _c_free_count else NULL_SLOT
	for index: int in range(_l_capacity):
		out.l_free[index] = _l_free[index] if index < _l_free_count else NULL_SLOT


func restore_canonical_columns(cols: CanonicalColumns) -> bool:
	"""Publish a decoded normalized projection into this store, without allocating anything.

	No `clear()`, no gameplay create/destroy and no generation increment: all three would change
	the pool the save recorded. Occupancy, generations and both free-stack prefixes are restored
	exactly as decoded, and only derived scan bounds and counts are rebuilt.

	EQUIPMENT ATTESTATION IS NOT RE-CHECKED HERE. `audit()`'s equipped biconditional needs a
	bound `gear.gd` authority, which the load orchestrator rebinds after the six section 7
	owners are published; running it now would refuse every legitimate equipped lot.
	"""
	_canonical_detail = ""
	if _tx_open or _j_count != 0 or _attesting:
		_canonical_detail = "the store is not quiescent"
		return false
	if cols.container_capacity != _c_capacity or cols.lot_capacity != _l_capacity:
		_canonical_detail = "projection declares %d containers and %d lots, not %d and %d" \
			% [cols.container_capacity, cols.lot_capacity, _c_capacity, _l_capacity]
		return false
	if _canonical_columns_refusal(cols) != REFUSE_NONE:
		return false
	_restore_container_columns(cols)
	_restore_lot_columns(cols)
	_rebuild_derived_state()
	return true


func _canonical_columns_refusal(cols: CanonicalColumns) -> StringName:
	"""Validate an incoming projection: the same partition rules, plus the canonical unused mask.

	STRICTER THAN CAPTURE. A noncanonical unused byte is REFUSED rather than replaced by the
	safe value it could have been; an inactive provenance 6 does not quietly become ORDINARY.
	"""
	var containers: StringName = _canonical_partition_refusal(cols.c_live, cols.c_generation,
		cols.c_free, cols.c_free_count, cols.container_capacity, "container")
	if containers != REFUSE_NONE:
		return containers
	var lots: StringName = _canonical_partition_refusal(cols.l_live, cols.l_generation,
		cols.l_free, cols.l_free_count, cols.lot_capacity, "lot")
	if lots != REFUSE_NONE:
		return lots
	var tails: StringName = _canonical_tail_refusal(cols)
	if tails != REFUSE_NONE:
		return tails
	var inactive: StringName = _canonical_inactive_refusal(cols)
	if inactive != REFUSE_NONE:
		return inactive
	return _canonical_live_refusal(cols)


func _canonical_tail_refusal(cols: CanonicalColumns) -> StringName:
	"""Both excluded free-stack tails must be the rebuilt `NULL_SLOT`, never leftover values."""
	for index: int in range(cols.c_free_count, cols.container_capacity):
		if cols.c_free[index] != NULL_SLOT:
			_canonical_detail = "container free tail %d holds %d, not %d" \
				% [index, cols.c_free[index], NULL_SLOT]
			return REFUSE_CANONICAL_FREE_STACK
	for index: int in range(cols.l_free_count, cols.lot_capacity):
		if cols.l_free[index] != NULL_SLOT:
			_canonical_detail = "lot free tail %d holds %d, not %d" \
				% [index, cols.l_free[index], NULL_SLOT]
			return REFUSE_CANONICAL_FREE_STACK
	return REFUSE_NONE


func _canonical_inactive_refusal(cols: CanonicalColumns) -> StringName:
	"""Every inactive row carries exactly the unused payload, checked value by value."""
	for slot: int in range(cols.container_capacity):
		if cols.c_live[slot] == 1:
			continue
		if cols.c_owner_slot[slot] != NULL_SLOT or cols.c_lot_count[slot] != 0 \
				or cols.c_owner_generation[slot] != NULL_GENERATION \
				or cols.c_policy[slot] != UNSET_POLICY \
				or cols.c_first_lot[slot] != NULL_SLOT or cols.c_max_mass_g[slot] != 0 \
				or cols.c_filters[slot] != 0 or cols.c_reserved_mass_g[slot] != 0 \
				or cols.c_used_mass_g[slot] != 0 or cols.c_reachable[slot] != 0:
			_canonical_detail = "inactive container %d carries a noncanonical payload" % slot
			return REFUSE_CANONICAL_INACTIVE_PAYLOAD
	for slot: int in range(cols.lot_capacity):
		if cols.l_live[slot] == 1:
			continue
		if _canonical_lot_is_masked(cols, slot):
			continue
		_canonical_detail = "inactive lot %d carries a noncanonical payload" % slot
		return REFUSE_CANONICAL_INACTIVE_PAYLOAD
	return REFUSE_NONE


func _canonical_lot_is_masked(cols: CanonicalColumns, slot: int) -> bool:
	"""True when an inactive lot row holds all twelve unused values and nothing else."""
	return cols.l_item_id[slot] == 0 and cols.l_quality[slot] == 0 \
		and cols.l_provenance[slot] == UNSET_PROVENANCE and cols.l_recipe_id[slot] == 0 \
		and cols.l_container_slot[slot] == NULL_SLOT \
		and cols.l_container_generation[slot] == NULL_GENERATION \
		and cols.l_next[slot] == NULL_SLOT and cols.l_prev[slot] == NULL_SLOT \
		and cols.l_quantity_milli[slot] == 0 and cols.l_reserved_milli[slot] == 0 \
		and cols.l_age_milli_hours[slot] == 0 and cols.l_age_remainder[slot] == 0


func _canonical_live_refusal(cols: CanonicalColumns) -> StringName:
	"""Live rows keep GDD §4.2's own domains: a bounded item, provenance, quantity and age."""
	for slot: int in range(cols.lot_capacity):
		if cols.l_live[slot] != 1:
			continue
		if cols.l_item_id[slot] < 0 or cols.l_item_id[slot] >= ITEM_CAPACITY:
			_canonical_detail = "live lot %d names item %d" % [slot, cols.l_item_id[slot]]
			return REFUSE_CANONICAL_LIVE_ROW
		if cols.l_provenance[slot] < CatalogScript.PROVENANCE_ORDINARY \
				or cols.l_provenance[slot] > CatalogScript.PROVENANCE_SPOIL_RECLAIM:
			_canonical_detail = "live lot %d carries provenance %d" \
				% [slot, cols.l_provenance[slot]]
			return REFUSE_CANONICAL_LIVE_ROW
		if cols.l_quantity_milli[slot] < 0 or cols.l_reserved_milli[slot] < 0 \
				or cols.l_reserved_milli[slot] > cols.l_quantity_milli[slot] \
				or cols.l_age_milli_hours[slot] < 0 or cols.l_age_remainder[slot] < 0:
			_canonical_detail = "live lot %d holds an out-of-domain quantity or age" % slot
			return REFUSE_CANONICAL_LIVE_ROW
	return REFUSE_NONE


func _restore_container_columns(cols: CanonicalColumns) -> void:
	"""Adopt the thirteen decoded container columns verbatim, generations and prefix included."""
	_c_live = cols.c_live.duplicate()
	_c_reachable = cols.c_reachable.duplicate()
	_c_generation = cols.c_generation.duplicate()
	_c_owner_slot = cols.c_owner_slot.duplicate()
	_c_owner_generation = cols.c_owner_generation.duplicate()
	_c_policy = cols.c_policy.duplicate()
	_c_lot_count = cols.c_lot_count.duplicate()
	_c_first_lot = cols.c_first_lot.duplicate()
	_c_free = cols.c_free.duplicate()
	_c_max_mass_g = cols.c_max_mass_g.duplicate()
	_c_filters = cols.c_filters.duplicate()
	_c_reserved_mass_g = cols.c_reserved_mass_g.duplicate()
	_c_used_mass_g = cols.c_used_mass_g.duplicate()
	_c_free_count = cols.c_free_count


func _restore_lot_columns(cols: CanonicalColumns) -> void:
	"""Adopt the fifteen decoded lot columns verbatim, generations and prefix included."""
	_l_live = cols.l_live.duplicate()
	_l_generation = cols.l_generation.duplicate()
	_l_item_id = cols.l_item_id.duplicate()
	_l_quality = cols.l_quality.duplicate()
	_l_provenance = cols.l_provenance.duplicate()
	_l_recipe_id = cols.l_recipe_id.duplicate()
	_l_container_slot = cols.l_container_slot.duplicate()
	_l_container_generation = cols.l_container_generation.duplicate()
	_l_next = cols.l_next.duplicate()
	_l_prev = cols.l_prev.duplicate()
	_l_free = cols.l_free.duplicate()
	_l_quantity_milli = cols.l_quantity_milli.duplicate()
	_l_reserved_milli = cols.l_reserved_milli.duplicate()
	_l_age_milli_hours = cols.l_age_milli_hours.duplicate()
	_l_age_remainder = cols.l_age_remainder.duplicate()
	_l_free_count = cols.l_free_count


func _rebuild_derived_state() -> void:
	"""Recompute the scan bounds, the live counts and the conservation ledger from the rows.

	THE LEDGER IS NOT A SAVED FIELD AND IS NOT PROMOTED INTO ONE. `_sourced_milli`/`_sunk_milli`
	are lifetime debug tallies classified category 3, so a reloaded world has no sink history to
	restore. Re-seeding `sourced` with the restored live quantity and `sunk` with zero is the
	only rebuild that leaves `audit()`'s `live + sunk == sourced` identity true without inventing
	a history the save never carried; it records no new fact.
	"""
	_c_live_count = 0
	_c_slot_high_water = 0
	for slot: int in range(_c_capacity):
		if _c_live[slot] == 1:
			_c_live_count += 1
			_c_slot_high_water = slot + 1
	_sourced_milli.fill(0)
	_sunk_milli.fill(0)
	_l_live_count = 0
	_l_slot_high_water = 0
	_equipped_lot_count = 0
	for slot: int in range(_l_capacity):
		if _l_live[slot] != 1:
			continue
		_l_live_count += 1
		_l_slot_high_water = slot + 1
		if _l_container_slot[slot] == NULL_SLOT:
			_equipped_lot_count += 1
		_sourced_milli[_l_item_id[slot]] += _l_quantity_milli[slot]
