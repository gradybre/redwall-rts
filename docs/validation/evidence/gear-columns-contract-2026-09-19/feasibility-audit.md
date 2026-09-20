# Gear owner boundary — feasibility audit

2026-09-19 · read-only. No source was edited and nothing was run. The parent
planning memo (`astra-source-notes.md`) is **provisional**; where this audit
disagrees with it, this document states the disagreement rather than quietly
replacing it. Nothing here authorises an implementation packet.

## 1. The twelve canonical arrays, exactly

`save_section_inventories.gd`'s `KEYS_GEAR` declares twelve fields in wire
ordinal order. Ten are `i32`, two are `u8`:

| # | Field | Type | Blank value |
|--:|---|---|---|
| 0 | `_occupied` | u8 | 0 |
| 1 | `_lot_slot` | i32 | -1 |
| 2 | `_lot_generation` | i32 | 0 |
| 3 | `_item_id` | i32 | -1 |
| 4 | `_durability` | i32 | 0 |
| 5 | `_durability_cap` | i32 | 0 |
| 6 | `_owner_slot` | i32 | -1 |
| 7 | `_owner_generation` | i32 | 0 |
| 8 | `_manufacture_recipe` | i32 | 0 (`MANUFACTURE_BASIC`) |
| 9 | `_equipped` | u8 | 0 |
| 10 | `_claim_job_slot` | i32 | -1 |
| 11 | `_claim_job_generation` | i32 | 0 |

That is **42 bytes per row**. `R = _row_capacity <= ROW_CAPACITY = 16384`.
Payload = `4` (zero child extents) + `12 * 8` (element counts) + `42R` =
**688228** at full capacity; the wrapper adds 28, giving the **688256** the
persistence registry already quotes. The blank-value column above matches
`gear._blank_row()` and `canonical_fill_of()` cell for cell; that part of the
wire is healthy and must be preserved unchanged.

**Row identity is the bare index.** `gear.gd` has no generation of its own and
says so; `_lot_generation` is an *inventory lot* generation and
`_owner_generation` / `_claim_job_generation` are *directory* generations. Three
namespaces, none of them the row's. Rows must be written and read in row order
and must never be compacted.

**The lot slot is the uniqueness key.** `_check_lot_slot_free()` and
`audit()`'s `AUDIT_DUPLICATE_LOT` both hold "at most one gear record per
Inventory lot slot, at any generation", including stale records whose lot has
retired. A stale record is legal state; two records on one slot is not.

## 2. What is derived and must be rebuilt, not carried

`_free_heap`, `_free_count`, `_active_count` and `_equipped_count` are functions
of `_occupied` and `_equipped`. The heap is a min-heap over free rows, so only
its *set* matters and `_refill_heap_ascending()` reproduces it exactly — this is
why "lowest free row" survives a restore. The owner boundary must recompute all
four during publication and must not accept them from the wire.

## 3. Why the existing restore path cannot be the bulk API

Three independent reasons, any one sufficient:

1. **`restore_row()` loses `_equipped`.** It delegates to `_write_new_row()`,
   which sets `_equipped[row] = 0`. There is no equipped parameter. A world with
   twelve equipped starter tools restores as twelve stowed ones, and the
   Inventory biconditional (a null-container lot iff gear attests) breaks
   silently — `inventory.audit()` then reports `AUDIT_ORPHAN_LOT` for lots that
   were never orphaned.
2. **`begin_restore()` calls `clear()`**, which zeroes `_equipped_count` and
   `_seed_count` and drops `_restoring`. It cannot preserve scratch, and it
   requires loaded definitions before the caller has validated anything.
3. **Publication is per row.** Each `restore_row()` publishes immediately, so a
   record that fails on its last row leaves the store holding every earlier row.
   That is the opposite of the atomic validate-then-publish the boundary needs.

Replaying `restore_row()` behind a wrapper would hide (1) rather than fix it.
The path stays where it is; the new boundary is additive.

## 4. Proposed owner API (exact)

On `gear.gd`, mirroring the shape `inventory.gd` already publishes:

```
const CANONICAL_OWNER_SCHEMA_VERSION: int = 1

class CanonicalColumns:
    var row_capacity: int
    var occupied: PackedByteArray          # ordinal 0
    var lot_slot: PackedInt32Array         # 1
    var lot_generation: PackedInt32Array   # 2
    var item_id: PackedInt32Array          # 3
    var durability: PackedInt32Array       # 4
    var durability_cap: PackedInt32Array   # 5
    var owner_slot: PackedInt32Array       # 6
    var owner_generation: PackedInt32Array # 7
    var manufacture_recipe: PackedInt32Array # 8
    var equipped: PackedByteArray          # 9
    var claim_job_slot: PackedInt32Array   # 10
    var claim_job_generation: PackedInt32Array # 11

func copy_canonical_columns_into(columns: CanonicalColumns) -> bool
func restore_canonical_columns(columns: CanonicalColumns,
        definitions: ItemDefinitions) -> bool
func canonical_detail() -> StringName
```

The projection is caller-owned, allocated once at `row_capacity`, reused across
saves. It carries **no** derived member and **no** scratch.

### Capture preconditions and refusals

| Precondition | Refusal |
|---|---|
| `columns.row_capacity == _row_capacity` | `GEAR_COLUMN_SHAPE` |
| `not _restoring` | `GEAR_COLUMN_RESTORE_OPEN` |
| if bound, `not _inventory.is_transaction_open()` | `GEAR_COLUMN_INVENTORY_TRANSACTION_OPEN` |
| `audit().ok` (occupancy/heap/duplicate lot/durability/claim pairing) | the audit's own code, re-surfaced |
| `_equipped_count` equals the recount of `_equipped` over live rows | `GEAR_COLUMN_EQUIPPED_COUNT` |

A refused capture writes nothing to `columns`.

### Restore preconditions and refusals

Validation runs to completion against the incoming projection **before any
column, any id and any counter is assigned**:

| Check | Refusal |
|---|---|
| shape as above | `GEAR_COLUMN_SHAPE` |
| `not _restoring` (the legacy window must not overlap) | `GEAR_COLUMN_RESTORE_OPEN` |
| `definitions != null and definitions.is_loaded()` | `GEAR_COLUMN_DEFINITIONS_NOT_LOADED` |
| every `occupied` / `equipped` byte in `{0,1}` | `GEAR_COLUMN_OCCUPANCY_BYTE` |
| free row exactly at the §1 blank values | `GEAR_COLUMN_BLANK_ROW` |
| live row: `lot_slot ∈ [0, LOT_CAPACITY)`, `lot_generation ∈ [1, INT32_MAX]` | `GEAR_COLUMN_LOT_REF` |
| lot slot unique across live rows | `GEAR_COLUMN_DUPLICATE_LOT` |
| live row: `item_id ∈ [0, ITEM_CAPACITY)` | `GEAR_COLUMN_ITEM_ID` |
| `item_id` resolves to one of the five ids this catalog *does* bind | `GEAR_COLUMN_ITEM_UNBOUND` |
| `0 <= durability <= durability_cap`, and `durability_cap` equals the canonical cap for that item and manufacture | `GEAR_COLUMN_DURABILITY` |
| `manufacture_recipe ∈ {BASIC, IRON}` and valid for that item | `GEAR_COLUMN_MANUFACTURE` |
| owner pair paired: `(slot == -1) == (generation == 0)`; slot `< DIRECTORY_CAPACITY` | `GEAR_COLUMN_OWNER_REF` |
| claim pair paired; slot `< JOB_CAPACITY`; generation `> 0` when slot set | `GEAR_COLUMN_CLAIM_REF` |
| `equipped == 1` implies occupied, an owner pair present, and `item_id == tool id` | `GEAR_COLUMN_EQUIPPED_ROW` |

Only then does publication run: copy twelve arrays, assign the five ids from
locals, set `_active_count` / `_equipped_count`, `_refill_heap_ascending()`.
Every step after the first assignment is unconditional, so there is no
failure-path mutation and no half-published store.

### What the boundary deliberately does not do

It does not bind or rebind collaborators. `bind_equipment()` refuses while any
row is equipped, so the target **must already be bound before restore**, and a
reused world's `Inventory`/`EntityDirectory`/`Residents` objects may be the same
instances whose arrays are being restored in the same pass — rebinding would
re-register an authority that is already registered and would re-answer a proof
`inventory.gd` has accepted. Ordering is the coordinator's.

## 5. The five cached ids: not a StockAge-style invalidation

`stock_age.gd` may invalidate its two compiled-id caches and let the next sweep
re-resolve them. Gear cannot. `_check_equip()` compares `_item_id[row]` against
`_id_tool`, `_wear_model_of_row()` resolves the wear model from all five, and
`inventory.audit()` may call `is_equipped_record()` the instant publication
returns. An unbound cache turns every restored net into `WEAR_MODEL_NONE` —
unclaimable and unrepairable — without any refusal.

So the ids are a **publication-phase input**: read into locals during
validation, assigned with the arrays. `capture_item_ids()` legally leaves
unresolved keys at -1, and this audit does **not** invent an all-five-positive
requirement. What it does require is that every live row's `item_id` matches an
id this catalog actually bound; an occupied row naming a key the catalog does
not define is a refusal, not a silent `NONE`.

## 6. Reachable incompatibilities in the current section-7 codec

These are flagged, not hidden. Each is a payload the codec accepts today and the
live store would refuse or could never produce:

1. **No duplicate-lot-slot check.** `_gear_refusal()` never builds a seen-set,
   so two occupied rows on one lot slot decode cleanly and then fail
   `gear.audit()` with `AUDIT_DUPLICATE_LOT`.
2. **Claim slot bounded by `DIRECTORY_CAPACITY` (352418), not `JOB_CAPACITY`
   (8192).** `_check_job_ref()` uses the latter. Slots 8192–352417 are
   decodable and unproducible.
3. **Unpaired references accepted.** `_generation_refusal(v, live=false)` only
   range-checks, so `(_owner_slot = -1, _owner_generation = 7)` and the same
   shape on the claim pair pass decode and then fail `AUDIT_CLAIM_MALFORMED`.
4. **`_item_id` unbounded above.** Only `>= 0` is checked; `ITEM_CAPACITY` is
   not applied to gear as it is to lots.
5. **Cap/model disagreement accepted.** `cap = 1234` on a net passes; the
   canonical caps are 0/1000/1500 and are a function of item and manufacture.
6. **`MANUFACTURE_IRON` accepted for any item.** `is_manufacture_valid_for_item()`
   restricts iron to `tool`.

(2), (4), (5) and (6) need the verified catalog or a compiled bound and so sit
naturally in the owner boundary rather than in the codec's structural pass. (1)
and (3) are pure structure and could be tightened in either place; doing so is a
wire-validation change, not a wire-format change, and the 42-byte layout, the
blank-value table and the ordinal order all stay exactly as they are.

## 7. `_seed_count`: stale 24, not a busy gate

The registry says `_seed_count` is 0 outside seeding. It is not.
`seed_starter_tools()` zeroes it on entry and increments once per created lot;
on the **success** path it returns with **24**. Only `_rollback_seed()` walks it
back to 0. So a nonzero value after a completed call is ordinary residue.

Consequences for the boundary: it must **not** treat `_seed_count != 0` as
"seeding in progress". Seeding is synchronous and a save is taken at a completed
tick, so no save can observe a half-seeded store — the caller's obligation is to
exclude reentry and half-seed callbacks, which is a coordinator concern. The
buffer stays category 3, is not captured, and is **preserved** across restore
unless a later ruling gives an explicit reason to reset it.

Registry corrections owed alongside any contract: the `_seed_count` description
(0 → "0 during and after rollback, 24 after a successful seed"), and the "Gear
scalars" row, which today omits `_equipped_count`, the three collaborator
bindings and `_wear_math`.

## 8. Adapter shape, memory and algorithm

A **separate, stateless** module — `save_gear_restore.gd` — mirroring
`save_stock_age_restore.gd` and `save_reservations_restore.gd`:

```
static func capture_gear_into(block: OwnerRecord, store: Object,
        columns: GearCanonicalColumns) -> SaveHeader.Refusal
static func apply_gear(block: OwnerRecord, store: Object,
        columns: GearCanonicalColumns, definitions) -> SaveHeader.Refusal
static func register_gear_adapter(walker, block) -> Digest.Refusal
```

It takes **one** `OwnerRecord`, never the six-owner `Record` (≈10.8 MB of
staging for one owner's 0.69 MB), and it constructs **no** `Inventory`.

Bounds: one `CanonicalColumns` at `42R` = **688128 bytes** at R = 16384, plus
one reusable `LOT_CAPACITY`-byte seen bitmap (**16384 bytes**) for uniqueness —
**≈704 KB** of cold-path staging, caller-owned and reused. Algorithm:
O(R) validation in a single pass, O(LOT_CAPACITY) bitmap fill, O(R) ascending
heap refill with no sift. No per-row allocation, no dictionary, no sort.

## 9. Reconciliation that stays outside this boundary

Catalog membership beyond the five bound ids; owner liveness and the
`residents.gd` Equipment mirror; the equipped-lot ⇄ null-container biconditional;
`gear._lot_slot` against Inventory's *runtime* `_l_capacity` rather than the
compiled `LOT_CAPACITY`; `audit_equipment_mirror()`. All of these need two or
more owners restored at once and belong to the load coordinator, which
`inventory.restore_canonical_columns()` already defers to by skipping gear
attestation. This boundary validates gear against itself and against compiled
maxima, and says so.

## 10. Tests the contract must earn (future, real operations)

* **Equip after restore.** Restore a stowed tool; bind; equip onto a live
  resident; assert the same lot, the same durability, mirror agreement and a
  clean `inventory.audit()`.
* **Unequip after restore.** Restore an equipped row with its null-container
  lot; unequip into a reserved destination; assert durability unchanged and the
  container charged exactly once.
* **Wear across restore.** Restore a partly worn claimed tool; `accrue` then
  `apply` general wear; assert the debit continues from the restored durability
  and the remainder carried by `work.gd` is untouched by the restore.
* **Claim survives restore.** Restore a row with a live claim pair;
  `complete_cycle` debits the restored per-cycle wear exactly once; a repeat
  refuses `GEAR_NOT_CLAIMED`.
* **Lowest-free allocation.** Restore rows 2 and 5 occupied; assert the next
  three creations take 0, 1, 3.
* **Refused restore is byte-identical.** Compare `state_bytes()` around each
  refusal class, including a full-length payload carrying a duplicate lot slot
  and one carrying an unpaired claim generation.

Until those exist and pass, no gear owner boundary should be declared complete.
