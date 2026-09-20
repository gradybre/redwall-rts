# Independent source acceptance — SAVE-AGE-R01v2

Reviewer: independent (not the implementing author, not the test author) · 2026-09-19

Scope reviewed: the accepted contract `docs/planning/stock_age_columns_contract.md`
(v2), decision 0162, the SAVE-AGE append fragment in `godot/scripts/core/stock_age.gd`,
`godot/scripts/core/save_stock_age_restore.gd`, the existing section-7 codec
`godot/scripts/core/save_section_inventories.gd`, the bound-API excerpts, the parent's
`godot/test/test_stock_age_columns.gd`, `focus-second.log` and `wire-baseline.json`.
Everything below is by reading and hand-derivation. No tool was run, no source edited,
nothing applied.

**Verdict: ACCEPT. No blocking source defect found.** Eight non-blocking gaps follow,
ordered correctness-first.

## What I checked and confirmed

**Total block shape gate.** `block_shape_refusal()` is total and ordered before any
indexing: null; `owner == 5`; `primary_count == 101376`; `child_extents` empty; then all
three group sizes; only then per-column lengths. `Codec.owner_refusal()` is never reached
before it on either entry point, which matters because `_stock_age_refusal` indexes
`u8_column(3)`, `i64_column(1)[0]` and `scalar(0)` unguarded.

**Owner gate orders.** Capture: output null/shape → binding → busy → live array shapes →
native scalar domains → payload → publication. Restore: input null/shape → binding → busy
→ input scalar domains → payload → installation. Both match the contract verbatim.
Binding precedes busy, so `_column_store_busy()` can never dereference a null `_inventory`.
`_live_columns_shape_ok()` precedes `_column_payload_ok()`, so a short private array
refuses RECORD without indexing.

**Source/target failure atomicity.** Every refusal path returns through `_refuse_column()`,
which writes one scalar and nothing else; the four `.duplicate()` installs and the two
scalar writes are all after the last gate. Capture replaces output fields only after the
payload check. The adapter's failure paths return before touching `out`'s three groups.

**Untouched noncanonical state.** `_last_refusal`, `_calendar`, `_math`, `_store_factor`,
`_temperature_factor`, `_inventory`, `_definitions` are written on neither path; only
`_spoiled_food_id`/`_compost_id` are reset, and only on a successful restore. The parent's
`_owner_image()` helper excludes exactly `_last_column_refusal` and folds `_math`/`_calendar`
in separately, so a stray write to any of the above would fail the reject helpers.

**Native scalar domain before narrowing.** Ordinal 0 is `TYPE_U32` but lives in the i64
storage group (`storage_kind_of_type` sends U32 to kind 2), so `storage_index_of(5,0)=0`
and `storage_index_of(5,1)=1`. The adapter writes `PackedInt64Array([count])` directly
rather than through `set_scalar()`, and the 0..101376 bound is applied by the owner (and
again by `_declared_list_refusal`) before any four-byte write. A 2^32 count refuses.

**Latch.** `_column_scalars_in_domain` is exactly `latch >= NO_HOUR_RUN`, identical to
`_stock_age_refusal`'s `tick < NO_HOUR_RUN`. 0 and 751 are accepted and preserved; no
`is_hour_boundary`, calendar or aging call appears anywhere in either new surface.

**Dense order and stale generations.** Nothing sorts, renumbers, repairs, marks, replays
or calls `clear()`. `_column_payload_ok` validates the prefix as a set and the tail as
all -1, and is order-blind by construction. Stale declarations pass because no current
container validity, item meaning or `storage_class_of` query occurs.

**Unique owner APIs / no codec cycle.** `stock_age.gd` preloads no save module; the codec
is preloaded only in the adapter. The owner's method names
(`copy_stock_age_columns_into` / `restore_stock_age_columns`) do not collide with the
codec's duck-typed `CAPTURE_METHOD = copy_canonical_columns_into` /
`RESTORE_METHOD = restore_canonical_columns`, so `capture_inventory_into()` cannot mistake
StockAge for Inventory.

**Local scratch / array independence.** The membership byte array is a function-local in a
`static func`, allocated only after the row loop passes, and never indexed before the slot
range check. Capture installs `.duplicate()`s; restore installs `.duplicate()`s; the
adapter's borrowed view never escapes and is never written.

**Ordinals and wire stability.** I re-derived the layout independently: wrapper
`4 + 9 + 4 + 8 + 8 = 33`; payload `4 (child count) + 6*8 (element counts) + 4 (u32 count)
+ 8 (i64 latch) + 2*101376 (u8) + 101376*4 (i32 generation) + 4*count = 608320 + 4*count`;
block `608353 + 4*count`; full `1013857`. This matches `wire-baseline.json` and the test's
size assertion exactly. The count=2 golden case uses slots `[2,1]`, so the hash is
order-sensitive and a sorted list would not reproduce it.

**Follow-on aging and lot allocation.** The order counterexample is an actual witness:
declare A,B,C then withdraw A leaves `[C,B]` via the swap in `_drop_declaration`; the sweep
retires C's waste lot before B's, so the free lot stack pops B's slot first and the next
two IDs are `[0,1]`; the reflection-sorted world yields `[1,0]`. The second world is built
by replaying the same public operations, and only StockAge is restored into it.

**Clock/barrier precedence.** `apply()` orders null block → null store → null clock →
barrier not held → block shape → codec → owner. The clock is only queried
(`is_load_barrier_held()` is pure per the excerpt); nothing acquires, releases, pauses,
ticks or binds. `capture_into()` correctly takes no clock.

## Findings (non-blocking), correctness-first

**F1 — capture-side payload validation is untested.** `test_short_source_array_...` covers
`_live_columns_shape_ok`, and `test_native_scalar_domains_...` covers
`_column_scalars_in_domain` on capture, but no test injects a *well-shaped but semantically
corrupt* private source (e.g. `_c_heated_interior[0] = 1` with class 0, or a duplicated
prefix entry). A mutation deleting the `_column_payload_ok(...)` call from the capture path
only would survive the focus suite and would publish an invalid record whose defect is then
caught, if at all, by the staged codec gate — which the contract explicitly calls defensive
rather than load-bearing. *Remedy:* add one reflection-injected row corruption and one list
corruption to the capture path, asserting `COLUMN_STOCK_AGE_RECORD`, an unchanged owner
image and an unchanged output record.

**F2 — cross-world association is the largest residual hazard.** `apply()` will install
declarations whose `_c_declared_generation` values were minted by a *different* Inventory.
The result is not a refusal anywhere: a recycled slot silently reads as declared and is
aged under the wrong store factor. The contract correctly excludes this and assigns it to
the coordinator, and `bind_stores` ordering is a stated caller obligation — I am not asking
for a stronger guarantee here. *Remedy (parent, not this packet):* record in the queue that
the load orchestrator owes a cross-owner reconciliation between `stock_age`
`_c_declared_generation[slot]` and `inventory` `_c_generation[slot]`, and that it must be a
diagnostic/reconciliation rather than a refusal, because a mismatch is exactly the legitimate
stale declaration this contract preserves until the next sweep.

**F3 — no static check locks the duck-typed gate or the no-cycle rule.** Both hold today by
naming and by preload placement, and both are one careless edit from breaking silently.
*Remedy:* mirror the existing `test_source_holds_no_float` precedent — assert
`not age.has_method("copy_canonical_columns_into")`,
`not age.has_method("restore_canonical_columns")`, and grep `stock_age.gd` for
`save_section_inventories`.

**F4 — successful capture never asserts block metadata preservation.** `_fields(block)` is
compared only on failure paths. *Remedy:* after a successful `capture_into`, assert
`block.owner == 5`, `block.primary_count == 101376`, `block.child_extents.is_empty()`.

**F5 — the golden probe hard-codes owner schema version 1.** `writer.write_u32(1)` will keep
passing if REG-R01 ever moves `stock_age` to schema 2 while the real encoder changes, turning
a regression witness into a stale fixture. *Remedy:* pair it with
`assert_equal(Codec.OWNER_SCHEMA_VERSIONS[Codec.OWNER_STOCK_AGE], 1, ...)`.

**F6 — `COLUMNS_PER_GROUP`/`SCALAR_CELLS` are restated, not derived.** If a seventh field
is ever declared, the shape gate stays at 2/2 and `storage_index_of` shifts underneath it.
The test's `Codec.KEYS_STOCK_AGE` equality assertion is the only guard. *Remedy:* add
`assert_equal(Codec.field_count_of(Codec.OWNER_STOCK_AGE), 6, ...)` beside it, or derive the
group counts from the codec tables in the adapter.

**F7 — one `range()` loop is inconsistent with the rest of the fragment.** Every other loop
uses non-allocating int iteration; the tail check is
`for index: int in range(count, CONTAINER_CAPACITY)`. *Remedy:* confirm in evidence that this
compiles to the counted-loop form and allocates no 101,376-element Array; if not, rewrite as
a `while` or as `for offset: int in CONTAINER_CAPACITY - count`.

**F8 — memory evidence must not understate the peaks.** Hand-derived: `CanonicalColumns`
1,013,760 B; `OwnerRecord` 1,013,776 B (both scalar columns i64-backed). Capture transiently
holds the live owner's four arrays, the local record's four duplicates, the staged record's
*throwaway* constructor arrays (all six are replaced immediately) and the caller's prior
target buffers — roughly 4.06 MB before collection, not 2.03 MB. Apply is comparable: the
caller's block, the view's discarded constructor arrays, the owner's new duplicates and its
old arrays, plus 101,376 B of membership scratch. Both allocations that are pure waste (the
staged `OwnerRecord.new` columns and the `CanonicalColumns.new` columns in `apply`) are
explicitly permitted by the contract, so they are an accounting item, not a defect; removing
them would need a contract amendment. State the figure, and do not claim an RSS result.

## Smaller observations

- Restore under a *poisoned* (as opposed to open) transaction is not exercised; only capture
  is. One extra line closes it.
- `_reject_restore`/`_reject_block` do not assert borrowed-collaborator identity; a path that
  swapped `_inventory` would pass. Add `assert_true(_age.inventory() == _inv, ...)`.
- `block_shape_refusal()` is public but only exercised transitively. A direct
  `assert_true(Adapter.block_shape_refusal(_block()).is_ok())` documents the accepting case.
- The contract's acknowledged race — a successful owner capture clears
  `_last_column_refusal` even when the staged codec gate then refuses — is faithfully
  implemented and correctly documented as authoritative-return-value. The test asserts the
  complementary case (a codec-stage rejection on apply leaves the older owner diagnostic
  alone). I agree this is the right split and would not change it.
- A restored latch of `INT64_MAX` is accepted by design and permanently refuses `run_hour`.
  That is the contract's explicit structural-only position; the coordinator owns clock/latch
  consistency. Flagged only so the queue item stays visible.
