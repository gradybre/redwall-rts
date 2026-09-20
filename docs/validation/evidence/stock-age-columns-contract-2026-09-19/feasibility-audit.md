# StockAge columns boundary: feasibility audit

Read-only. This is evidence for the exact contract Astra will author next, not an
authorization to edit source. No claim is made here about section 7 completeness
or about a whole-world save: `inventory` is the only section 7 owner publishing
columns today, closing StockAge makes two of six, and `fishing`, `forage`, `gear`
and `reservations` still publish nothing, so `Walker.digest_into()` keeps refusing
`CANONICAL_NO_ADAPTER` and no `capture_into(record)` for the section exists.

## 1. The future-affecting state, exactly

`stock_age.gd` allocates four packed columns once in `_init()`, each sized from
`InventoryScript.CONTAINER_CAPACITY` = 101376, plus two native scalars:

| Member | Type | Extent | Bytes | Domain | Unused value |
|---|---|---:|---:|---|---|
| `_c_storage_class` | `PackedByteArray` | 101376 | 101376 | 0..4 (`STORAGE_CLASS_COUNT` - 1); 0 is `STORAGE_UNDECLARED` | 0 |
| `_c_heated_interior` | `PackedByteArray` | 101376 | 101376 | 0 or 1 | 0 |
| `_c_declared_generation` | `PackedInt32Array` | 101376 | 405504 | 0..`MAX_INT32`; nonzero iff the row is declared | 0 |
| `_declared_slots` | `PackedInt32Array` | 101376 | 405504 | prefix `[0, count)` in 0..101375; tail `NULL_SLOT` | -1 |
| `_declared_count` | `int` | scalar | -- | 0..101376 | 0 |
| `_last_hour_tick` | `int` | scalar | -- | `NO_HOUR_RUN` (-1) or a nonnegative hour-crossing tick | -1 |

Resident packed total **1013760 B**, unchanged by this work.

Everything else the module holds is category 3: `_inventory` and `_definitions`
(wiring), `_calendar` and `_math` (reusable scratch), `_store_factor` and
`_temperature_factor` (per-container scratch, read only after a true
`_resolve_hour_factors()`), `_last_refusal` (declaration diagnostics), and
`_spoiled_food_id` / `_compost_id` (compiled-catalog lookups re-resolved by
`_preflight()` whenever they are negative).

## 2. Stale declarations are natural and must survive verbatim

`declared_container_count()` documents that stale declarations are counted "until
swept". `_sweep_declared_containers()` retires one by testing
`_inventory.is_container_valid(ref)` and calling `_drop_declaration(index)`
without advancing the index, so the entry swapped into the hole is visited in the
same iteration. A restore must therefore **not** validate declarations against
the currently bound Inventory. Two consequences worth recording:

* A declared slot at or above the bound Inventory's runtime `_c_capacity` is not
  a corruption case. `is_container_valid()` refuses it and the ordinary hourly
  sweep retires it, so exact restoration is self-healing and needs no new rule.
  This is why the local adapter can bound declared slots by the compiled 101376
  only and leave any runtime-capacity cross-check to the load orchestrator.
* Retirement order is observable through Inventory. A waste or zero-yield seed
  lot that expires retires its row, pushing that lot slot onto Inventory's
  last-freed-first free stack. Two sweep orders hand the next `create_lot()`
  different slots, which is the concrete reason the dense list's prefix order is
  category 1 and cannot be rebuilt ascending.

## 3. The dense list tail is already canonical

Unlike Inventory's free stacks, StockAge's `_declared_slots` tail is `NULL_SLOT`
by construction at every quiescent point: `clear()` fills the whole array with
`NULL_SLOT`, `declare_storage_class()` writes only at index `_declared_count`,
and `_drop_declaration()` writes `NULL_SLOT` into the vacated tail cell after
decrementing. So the section 7 header's HAZARD 1 "stale garbage tail" does not
arise for this owner: capture and restore are exactly symmetric, and
`set_stack_column()`'s rebuild is a no-op for a healthy store. The restore side
must still **require** the `-1` tail, because a forged record can carry junk
there and admitting it would make two logically identical worlds re-encode
differently.

## 4. The latch

`run_hour_into()` refuses `INVALID_TICK` below 0, `NOT_AN_HOUR_BOUNDARY` off the
offset crossing `(tick + 4500) mod 750 == 0`, and `STOCK_AGE_HOUR_ALREADY_RUN`
for `tick <= _last_hour_tick`, consuming the latch **before** any lot is touched.
The latch is therefore the only thing preventing a double or skipped hour across
a save taken at an exact crossing, and `NO_HOUR_RUN` is read from
`crop_weather.gd` rather than restated.

The existing wire validator `_stock_age_refusal()` checks only
`tick >= NO_HOUR_RUN`. It admits 0, 751 and other values the runtime can never
produce. Recommendation: the **adapter** requires
`last_hour_tick == NO_HOUR_RUN or (last_hour_tick >= 0 and StockAge.is_hour_boundary(last_hour_tick))`.
That is strictly narrower than the codec's rule, so it changes no accepted byte
stream and needs no schema bump; `_stock_age_refusal()` stays untouched in this
packet.

## 5. Section 7 shape, measured

Owner ordinal 5, key `stock_age`, `owner_schema_version` 1, `PRIMARY_COUNT_IS_FIXED`
true at 101376, zero child extents. Declared ordinals: 0 `_declared_count` (u32,
scalar), 1 `_last_hour_tick` (i64, scalar), 2 `_c_storage_class` (u8, primary),
3 `_c_heated_interior` (u8, primary), 4 `_c_declared_generation` (i32, primary),
5 `_declared_slots` (i32, primary, count field 0).

Payload = 4 (child-extent count) + 6 x 8 (element counts) + 4 + 8 + 101376 +
101376 + 405504 + 4 x count = **608320 + 4 x count**. Wrapper = 4 + 9 + 4 + 8 + 8
= 33. Block = **608353** with no declarations, **1013857** at 101376. The 608353
figure agrees with the registry's section 7 row, so nothing here moves the
section length arithmetic when no container is declared.

Only `_declared_count` is u32, and `set_scalar()` already gates it with
`fits_u32`; the latch is i64 and narrows nowhere. The capture path must still
bound the count to 0..101376 before the scalar write, because `set_scalar()`
refuses a negative but accepts any nonnegative u32.

## 6. Recommended API shape

`save_section_inventories.gd` already `preload`s `stock_age.gd`. A capture hook
inside stock_age.gd that reached for the codec would close a cycle, so:

**Owner-nested, in `stock_age.gd`**, mirroring `Inventory.CanonicalColumns`:

```
class CanonicalColumns:
    var container_capacity: int          # must equal CONTAINER_CAPACITY
    var c_storage_class: PackedByteArray      # [101376]
    var c_heated_interior: PackedByteArray    # [101376]
    var c_declared_generation: PackedInt32Array  # [101376]
    var declared_slots: PackedInt32Array      # [101376], -1 tail
    var declared_count: int
    var last_hour_tick: int
```

with `copy_canonical_columns_into(columns) -> bool`,
`restore_canonical_columns(columns) -> bool` and `canonical_detail() -> StringName`,
reusing the method names section 7 already resolves through `CAPTURE_METHOD`,
`RESTORE_METHOD` and `DETAIL_METHOD` so a future coordinator dispatches uniformly.
Independent arrays, allocated once by the caller and reusable across saves.

**Separate adapter module** (for example `save_stock_age_restore.gd`) preloading
both codec and store, exposing
`capture(block: OwnerRecord, store, columns) -> Refusal` and
`apply(block: OwnerRecord, store, columns) -> Refusal`. Taking an `OwnerRecord`
rather than a `Record` is what keeps a test from allocating all six blocks
(~10.8 MB); a single stock_age block is **1013776 B**.

## 7. Refusal order

Quiescence first, because a non-quiescent store must refuse whatever the payload
says, then payload domains in declared ordinal order:

1. `block == null` or `block.owner != OWNER_STOCK_AGE` -> owner mismatch.
2. `primary_count_refusal(OWNER_STOCK_AGE, block.primary_count)`.
3. Local shape: `child_extents.size() == 0`, and every one of the six columns at
   its declared backing extent. **This must run before `owner_refusal()`** (see
   gap G1).
4. `columns.container_capacity` equals the block's `primary_count` and the
   store's `CONTAINER_CAPACITY`.
5. Store bound: `inventory() != null` and `item_definitions() != null`.
6. `inventory().is_transaction_open()` -> refuse; `is_transaction_poisoned()` ->
   refuse. Both are pure queries.
7. `declared_count` in 0..101376.
8. `last_hour_tick` per section 4.
9. `c_storage_class[slot] < STORAGE_CLASS_COUNT` for every row.
10. `c_heated_interior[slot]` in {0, 1}.
11. `c_declared_generation[slot]` in 0..`MAX_INT32`, nonzero iff declared.
12. Undeclared rows carry heated 0 and generation 0.
13. Prefix `[0, count)` entries in range, pairwise distinct, each naming a
    declared row; every declared row appears exactly once.
14. Tail `[count, 101376)` all `NULL_SLOT`.

The adapter reports through a **separate** `_last_column_refusal` namespace with
`COLUMN_`-prefixed codes and `canonical_detail()`, following
`entity_directory.gd`, `jobs.gd`, `needs.gd`, `residents.gd` and
`job_planner.gd`. It must not clobber `_last_refusal`, which `last_refusal()`
publishes for declaration calls and which a caller may not yet have read.

## 8. Success and failure behaviour

**Order.** `bind_stores()` to a different Inventory calls `clear()`, dropping
every declaration and the latch, so the coordinator binds first and installs
second. The adapter refuses when unbound rather than binding on the caller's
behalf.

**Success scratch/cache policy.** Set `_last_column_refusal` to none. Reset
`_spoiled_food_id` and `_compost_id` to -1 so `_preflight()` re-resolves them
against the catalog the header pins -- cheapest correct policy, one dictionary
lookup on the next hour. Leave `_last_refusal`, `_calendar`, `_math`,
`_store_factor` and `_temperature_factor` alone: the first is a diagnostic the
caller owns, and the last two are never read after a false
`_resolve_hour_factors()`.

**Failure atomicity.** Validate wholly into locals, then assign. Packed arrays
are copy-on-write values, so four `duplicate()` assignments plus two scalars
after the last check leave a refused restore byte-identical. StockAge has no
`state_bytes()`, so the proof vehicle for a test is a capture taken before the
refused restore compared against a capture taken after (gap G3).

**Cold memory.** One `CanonicalColumns` 1013760 B plus scalars, one
`OwnerRecord` 1013776 B; peak ~2.03 MB of bounded cold-path scratch, neither
resident between a save and a load, neither a second world.

## 9. Tests

* **T1** Round trip: capture, restore into a fresh bound StockAge, re-capture,
  compare all six members.
* **T2** Lot free-stack order: declare A, B, C; withdraw B so the list is
  `[A, C]` with C swapped into index 1; capture; restore into a second world;
  give A and C one zero-yield seed lot each at the expiry boundary; run the same
  hour in both; assert the next two `create_lot()` calls return the same lot
  slots in the same order. Sorting the list ascending breaks this.
* **T3** Latch continuation: restore with `last_hour_tick = T`; `run_hour(T)`
  refuses `STOCK_AGE_HOUR_ALREADY_RUN`; `run_hour(T + 750)` ages by exactly one
  hour.
* **T4** Stale declaration: destroy a declared container, capture, restore,
  assert `declared_container_count()` unchanged, then one hour drops it and
  `containers_aged` excludes it.
* **T5** Refusal atomicity, one forged record per code in section 7, each proved
  by the capture-compare of section 8.
* **T6** Bind order: restore into an unbound StockAge refuses; binding a
  different Inventory after a successful restore drops the declarations, which
  documents the coordinator's obligation.
* **T7** Malformed owner arrays: a block with a short column or a nonzero child
  extent count refuses with a shape code and never reaches `owner_refusal()`.
* **T8** Framing: `payload_bytes_of(block)` equals `608320 + 4 * count` and
  `block_bytes_of(block)` adds 33, at count 0, 1 and 101376.

## 10. Gaps and defects to settle before authoring

* **G1 (source defect).** `owner_refusal()` is public and documented as usable on
  one store alone, but it is not total: `_stock_age_refusal()` indexes
  `i64_column(1)[0]` and walks columns whose lengths only the private
  `_block_shape_refusal()` checks. A malformed `OwnerRecord` faults instead of
  refusing. Close by adding a public per-owner shape validator, or by having
  `owner_refusal()` call the shape check itself. Until then the adapter must gate.
* **G2.** Latch domain: adapter requires hour-boundary alignment; codec is left
  laxer. Decide explicitly and record that this is deliberately asymmetric.
* **G3.** No `state_bytes()` on StockAge; the Columns copy-out is the atomicity
  proof vehicle, so capture must be usable on an unrestored store.
* **G4.** Refusal namespace separation from `_last_refusal`.
* **G5.** Method-name uniformity with the Inventory trio.
* **G6.** StockAge's primary count is the compiled 101376 while `inventory`'s is
  runtime; the mismatch is safe locally (section 2) and stays the orchestrator's.
* **G7.** No wire change: owner schema stays 1, section schema stays 3. State
  this, so no version bump is implied by a new capture path.

Fault, retry and hold policy for a blocking integrity pause remains the full save
coordinator's and is untouched here.
