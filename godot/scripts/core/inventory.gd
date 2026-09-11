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
## This module invokes no caller-supplied callback and no signal anywhere, so no public
## operation can re-enter while one of them holds a live value, and a caller can never hold two
## of these at once because the only object that escapes is the freshly built OpResult. Within
## the module the rule is: copy `_math.value` into a local before the next call.
##
## Container refs use the GDD §4.1 `(slot, generation)` pair carried as Vector2i with the null
## ref `(-1, 0)`, matching entity_directory.gd, but this module allocates its own slots. Wiring
## lots and containers into the global directory (ARCH-ID-001 gives both a directory entry) is
## a separate integration step and is not part of task 2.5.

const IntMath := preload("res://scripts/core/int_math.gd")

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

## Category bits available in the 64-bit `filters` mask (ARCH-STATE-004).
const CATEGORY_COUNT: int = 64
## Filters value admitting every category. Arithmetic shift keeps every bit set.
const FILTERS_ACCEPT_ALL: int = -1

## Provenance and container policy are OPAQUE int32 catalog enum values. GDD §4.3 numbers
## neither enumeration, so under BAL-CAT-001 their concrete members are compiled by catalog.gd
## from sorted ASCII keys and this module must not assert what any of them equal. Inventory
## therefore only ever stores these two columns and compares them for equality; it never
## branches on a particular member and never publishes one.
##
## The two names below are LOCAL SENTINELS for a field a caller left unset -- the value a
## freshly cleared column holds. They are NOT catalog IDs: no compiled member is guaranteed to
## carry these numbers, and nothing may read them as meaning "unknown" or "default".
const UNSET_PROVENANCE: int = 0
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

## The single method name an equipment authority must publish. Duck typed on purpose: `gear.gd`
## preloads this module, so this module must not preload `gear.gd` back.
const EQUIPMENT_ATTESTATION_METHOD: StringName = &"is_equipped_record"


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
## True only while the authority's attestation is running. `_guard()` refuses every mutator while
## it is set, so an authority that tries to re-enter this module cannot half-apply an operation.
var _attesting: bool = false

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


func _open_transaction() -> void:
	"""Reset the journal and record the allocator scalars a rollback must restore."""
	_tx_open = true
	_tx_poisoned = false
	_tx_error = REFUSE_NONE
	_j_count = 0
	_tx_saved_c_free_count = _c_free_count
	_tx_saved_l_free_count = _l_free_count
	_tx_saved_c_live_count = _c_live_count
	_tx_saved_l_live_count = _l_live_count
	_tx_saved_equipped_count = _equipped_lot_count


func _enter() -> bool:
	"""Open an implicit single-operation transaction unless one is already open.

	Returns true when this operation owns the transaction and must close it in _leave().
	"""
	if _tx_open:
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

	`quality`, `provenance` and `recipe_id` are stored in int32 columns. `provenance` is an
	opaque catalog enum value, so a value outside int32 would not merely lose magnitude, it
	would land on a different, plausible looking member; all three refuse instead. Only the
	verdict is needed here, so fits_int32() is used and nothing is narrowed or allocated.
	"""
	if not IntMath.fits_int32(quality):
		return REFUSE_OVERFLOW
	if not IntMath.fits_int32(provenance):
		return REFUSE_OVERFLOW
	if not IntMath.fits_int32(recipe_id):
		return REFUSE_OVERFLOW
	return REFUSE_NONE


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
	return REFUSE_NONE


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
	if not IntMath.inventory_capacity_debit_g_into(_l_quantity_milli[slot], _item_mass_g[_l_item_id[slot]], _math):
		return REFUSE_OVERFLOW
	var debit: int = _math.value
	var fits: StringName = _check_fits(dest_ref.x, debit)
	if fits != REFUSE_NONE:
		return fits
	_apply_move(slot, source_container, dest_ref, debit)
	return _succeed(lot_ref, _l_quantity_milli[slot])


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
	return REFUSE_NONE


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
	"""Cancel every claim on a lot, as a lease expiry or job invalidation would."""
	var owned: bool = _enter()
	if not is_lot_valid(lot_ref):
		return _leave(owned, REFUSE_INVALID_LOT)
	var reserved: int = _l_reserved_milli[lot_ref.x]
	if reserved == 0:
		return _leave(owned, _succeed(lot_ref, 0))
	return _leave(owned, _change_reservation(lot_ref, -reserved))


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
	var next: int = held + delta_milli
	_journal_lot(slot)
	_l_reserved_milli[slot] = next
	return _succeed(lot_ref, next)


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
	"""Provenance enum value of a lot, or -1 for an invalid ref."""
	return _l_provenance[lot_ref.x] if is_lot_valid(lot_ref) else -1


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
	"""Re-walk one container's lot list and compare the derived mass and count to the cache."""
	var mass: int = 0
	var count: int = 0
	var lot: int = _c_first_lot[slot]
	while lot != NULL_SLOT:
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
