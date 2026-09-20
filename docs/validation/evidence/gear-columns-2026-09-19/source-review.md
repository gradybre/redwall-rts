# SAVE-GEAR-R01 v2 — independent source review

Date: 2026-09-19 · Reviewer: independent, not the author of the fragment, the
adapter, the tests or the registry edits.

Scope of this document: a **read-only audit** of `godot/scripts/core/gear.gd`
(append-only v2 fragment), `godot/scripts/core/save_gear_restore.gd`,
`godot/test/test_gear_columns.gd` and the `docs/persistence_state_registry.md`
edits, against `docs/planning/gear_columns_contract.md` (version 2, accepted)
and decision 0165.

**What this review cannot claim.** Nothing here was executed. No test ran, no
import, no static or editor pass, no mutant run, no CI. Every statement below
is derived from reading the supplied text. Parent-side execution of the full
suite, import/static/editor checks, the three named mutants and exact-head CI
remains independently required and is *not* discharged by this document.
Existing header comments and docstrings were read as authorial intent, never as
gameplay or runtime evidence.

---

## A. Conformances verified by reading

**A1 — Total shapes, native extents first.** `_gear_columns_shape_refusal()`
rejects null, `row_capacity` outside 1..16384, mismatch against `_row_capacity`,
and each of the twelve extents, before any indexing. `_gear_live_shape_refusal()`
then re-checks native `R` and all twelve live columns **plus `_free_heap`**.
Both run before any per-row read and before any derived staging is allocated;
both yield `COLUMN_GEAR_SHAPE`, so first-failing-gate determinism holds at code
granularity regardless of which fires. Restore reaches the same two gates, so
"ignores the old payload but still requires valid construction metadata and
extents" is implemented as written.

**A2 — Flag / ref / blank / payload order, including duplicate SLOT.**
`_gear_column_payload_refusal()` runs a **separate whole-extent pass** over
`occupied` and `equipped` (`> 1` → `OCCUPANCY`) before any row is interpreted,
then the ascending per-row pass (exact canonical blank for inactive rows;
`REF`/`ITEM`/`DURABILITY`/`MANUFACTURE` for active rows in that order), then
`_gear_duplicate_lot_refusal()` **after** every per-row field has passed. The
16384-byte bitmap is allocated only at that point, and its index is provably in
range because active rows already passed `0 <= lot_slot < LOT_CAPACITY`. One
ascending pass, no quadratic scan, no Dictionary, no sort. `equipped == 1` with
an exactly-null owner is refused `REF`; half-null owner and claim pairs are
refused; stale generations are preserved.

**A3 — The two deliberately stronger gates.** Owner slot is bounded by
`EntityDirectory.DIRECTORY_CAPACITY` (352418) and claim slot by `JOB_CAPACITY`
(8192), with exact `(-1, 0)` null pairs required. Neither bound is widened,
clamped, masked, normalised or remapped anywhere in either file; the adapter
forwards `COLUMN_GEAR_REF` verbatim.

**A4 — Cache read on capture, five-ID publication on restore.**
`copy_gear_columns_into()` reads the five compiled IDs into locals and compares
them in `_gear_source_cache_refusal()`; `capture_item_ids()` is not called and
no `_id_*` field is assigned on any capture path. The empty-source allowance
(all five `-1`) is gated on `active_rows == 0`; a mixed stale cache refuses.
`restore_gear_columns()` performs no cache gate (correct — capture-only) and
publishes all five staged IDs unconditionally, including all-`-1` for a loaded
catalog with unresolved gear keys.

**A5 — Source heap and count verification.** `_gear_source_derived_refusal()`
compares `_active_count`, `_equipped_count` and `_free_count` against the tally,
range-checks free/active before allocating the R-byte bitmap, proves the live
prefix is exactly the free set with no duplicate and no occupied row, and then
checks the min-heap property over that prefix. Any valid permutation is
admitted; the tail beyond `_free_count` is ignored. Ranges precede all heap
indexing.

**A6 — Equipped binding scope.** Both operations refuse `COLUMN_GEAR_BINDING`
when `tally.equipped_rows > 0` and `is_equipment_bound()` is false. Neither
operation calls `is_equipped_record()`, `audit()`, `audit_equipment_mirror()`,
Inventory, Directory or Residents. No blind post-install rebind exists.

**A7 — No old hot-mutator change; no partial publication.** The fragment is
additive: it introduces new constants, two nested classes, one new field and
new functions only, and redefines nothing above it. `_refill_heap_ascending()`
is not reachable from any new function. `_publish_gear_restore()` builds the
ascending heap with `-1` tail and all twelve duplicates into locals **before**
the first live assignment, and every subsequent statement is an unconditional
assignment, so no window exposes half an image. It publishes exactly the twelve
arrays, the heap, `_active_count`, `_free_count`, `_equipped_count` and the five
IDs — and nothing else. `_publish_gear_capture()` duplicates all twelve columns
independently. `_refuse_gear_columns()` writes only `_last_column_refusal`.
`_restoring`, the seed buffers, `_seed_count`, `_wear_math` and the three
borrowed references are untouched on every path. Input aliasing is safe because
the heap is derived by reading and the twelve columns are duplicated before any
assignment.

**A8 — Adapter ordinals and group mapping.** `save_gear_restore.gd` preloads the
codec (no owner→save edge), speaks for a single `OwnerRecord` (never a
six-owner `Record`), declares `2/10/0` group widths, validates null, owner id,
`primary_count` range, zero child extents, the three **group counts** and only
then each column length, and routes **every** storage access through
`Codec.storage_index_of(OWNER, ordinal)`. No ordinal is used as a group index.
Gate order on both paths matches the contract exactly, including `null block →
BLOCK_SHAPE`, the R-match against `store.row_capacity()`, the pure
Inventory triple (null → identity → open/poisoned), the codec gate, and
`definitions` never gating ahead of the owner gate. `apply()` only *queries*
`is_load_barrier_held()`; it never acquires or releases. No collaborator write,
callback, reflection or yield appears in either file.

**A9 — Registry conformance.** The registry now records seed count 24 as
residue that clear/rollback may reset; classifies `_equipped_count` and
`_row_capacity` with the derived scalars; describes the five IDs as
reconstructed from the verified catalog; classifies `_restoring`,
`_last_column_refusal`, `_wear_math` and the three bindings as category 3; keeps
the canonical twelve-field set unchanged; marks the claim-generation reading as
an integration obligation without widening 8192; registers the stateless
adapter; and narrows §7 coverage to leave only Fishing/Forage and whole-section
assembly incomplete. Owner schema stays 1 — no codec or schema change is made.

---

## B. Correctness blockers

**None found in the accepted structural domain.** To make that negative
meaningful, these specific failure modes were each checked and are absent:
publication before a fallible step; a live-array write on any refusal path;
indexing before the extent gate; bitmap indexing with an unvalidated slot;
cache mutation during capture; a missing `_equipped` publication; a missing or
mis-ordered duplicate-lot pass; heap indexing before range validation; an
Inventory/Directory/Residents mutation; a widened or clamped reference domain;
an input array retained by the store after restore; an output array aliasing a
live column after capture; reachability of `_refill_heap_ascending()`; and a
codec↔owner preload cycle.

---

## C. Acceptance gaps, with bounded fixes

These are test/evidence gaps, not code defects. Each is small and local.

**C1 (non-vacuity, highest value).** No test asserts that a **successful** owner
operation clears `_last_column_refusal`, nor that `canonical_detail()` then
returns `""`. A mutant that records a code and never clears it survives. *Fix:*
in `_capture()` and after each successful `restore_gear_columns()` that follows
a refusal, assert `last_column_refusal() == &""` and `canonical_detail() == ""`.

**C2 (ordering not pinned).** The contract requires both flag columns validated
across the whole extent **before** any row is interpreted, but no fixture pairs a
later-row flag byte of 2 with an earlier-row blank/ref defect. An interleaved
per-row implementation would pass today. *Fix:* one case setting `equipped[7] = 2`
(a blank row) together with `lot_generation[0] = 0`, asserting
`COLUMN_GEAR_OCCUPANCY` wins.

**C3 (ordering not pinned).** Duplicate-lot-after-per-row is likewise unpinned
against a coexisting defect. *Fix:* one case with duplicate lot slots on rows
0/1 **and** `durability[1] > durability_cap[1]`, asserting
`COLUMN_GEAR_DURABILITY` wins.

**C4 (snapshot breadth).** The contract asks for all three collaborators to be
snapshotted through every refusal. `_reject_restore()` snapshots Inventory only;
`_reject_capture()` snapshots neither Inventory nor the other two. *Fix:* fold a
null-guarded Directory/Residents/Inventory byte snapshot into both helpers.

**C5 (detail forwarding).** Adapter tests assert `.code` but never the forwarded
`.detail`. *Fix:* assert `detail == String(code)` on one forwarded owner refusal.

**C6 (defaults).** `Gear.new()` and `Gear.GearColumns.new()` at their defaults
are never constructed; the R=16384 golden variants pass the value explicitly.
*Fix:* one assertion that both defaults equal `ROW_CAPACITY` and that a default
record's extents are 16384.

---

## D. Cold-memory accounting — re-derived independently

Re-deriving from the code rather than from the contract, counting disjoint
constructor allocations even when reclaimed, in packed bytes:

- **Owner capture** = 42R (caller record) + 42R (live columns) + 4R (live heap)
  + R (heap bitmap in `_gear_source_derived_refusal`) + 42R (publication
  duplicates) + 16384 (lot bitmap) = **131R + 16384**. ✔
- **Owner restore** = 42R (input record) + 42R (live) + 4R (old heap) + 4R
  (private new heap) + 42R (duplicates) + 16384 = **134R + 16384**. ✔
- **Adapter capture** = 131R + 16384 (owner envelope, which already counts the
  private `GearColumns`) + 42R (staged `OwnerRecord` constructor buffers) + 42R
  (target block) = **215R + 16384**. ✔
- **Adapter apply** = 42R (block) + 42R (local `GearColumns` constructor buffers,
  then replaced by borrowed block arrays) + 42R (live) + 4R (old heap) + 4R
  (private heap) + 42R (duplicates) + 16384 = **176R + 16384**. ✔

Plus the existing 192-byte seed buffers (24 × 4 × 2). No extra full
`GearColumns` is allocated for source validation: the shared validator takes
twelve typed arrays and returns a three-int `GearColumnTally` with no
reflection, Dictionary or per-row object. Wire arithmetic is self-consistent:
payload 100 + 42R (12 × 8 count prefixes + 4 child count), wrapper 28 (4 + 4 key
+ 4 version + 8 primary + 8 payload length), full block 128 + 42R = **688256**
at R = 16384, which is exactly what the golden test asserts. These are
allocation-accounting bounds, **not** measured peak memory or RSS.

One optional, non-required refinement: `apply()` allocates 42R of constructor
buffers it immediately discards. A private zero-length constructor would remove
them, but that would move the published envelope and therefore requires an
accounting revision before acceptance — out of scope here.

---

## E. Descriptor ordinals — what the tests do and do not kill

An adapter-side mis-wiring (e.g. swapping the `ORDINAL_DURABILITY` and
`ORDINAL_DURABILITY_CAP` assignments) **is** killed:
`test_adapter_success_uses_exact_ordinals_and_independent_arrays` compares each
ordinal's column against `_store.get("_" + FIELDS[ordinal])` from a literal field
list, and the golden fixture gives durability and cap different values.
`Codec.KEYS_GEAR` is pinned literally, and the four framed SHA-256 probes pin
ordinal-order bytes.

However, a **permutation internal to `Codec.storage_index_of()`** is invisible
here, because capture, apply and the probes all resolve through the same
mapping, so the ordinal-ordered wire bytes are unchanged. The accepted contract
already rules such a fixed mapping behaviourally equivalent for this frozen
schema; this note exists so that equivalence is **disclosed rather than counted
as a kill**. No claim is made that a transposed codec mapping was killed.

---

## F. Accepted structural domain vs. full-world obligations

The implementation consistently refuses to overclaim, and this review adopts the
same line. What these two files establish is: the twelve canonical columns, bare
row identities, the `equipped` byte, stale generations, an ascending free heap,
three derived counts and five catalog IDs move as one image, with first-failing
gate refusals and no partial write.

What they do **not** establish, and must not be read as establishing: exact
catalog membership, per-kind cap/manufacture validity, equipped-tool subtype,
lot item/quantity agreement, owner liveness/kind/mirror reconciliation, the
equipment biconditional, claim liveness, Work bindings, whole-section §7
assembly, disk rollback, or a playable settlement. The `column_inventory_matches`
predicate attests nothing for an unbound store; the coordinator still owns world
association. The stale-equipped-owner test correctly demonstrates the boundary:
the row is structurally preserved and the subsequent world audit refuses.

---

## G. Dependencies the parent must confirm independently

1. **Golden values.** The four literal SHA-256 strings cannot be confirmed by
   reading source. The integration notes state they were generated before author
   integration; that provenance claim is not verifiable here and must be
   re-established by the parent.
2. **Collaborator APIs used but not supplied.** `Codec.storage_index_of`,
   `column_slice`, `payload_bytes_of`, `KEYS_GEAR`, `OWNER_SCHEMA_VERSIONS`,
   `OwnerRecord.u8_column/i32_column/set_i32_column`, `owner_refusal`,
   `SimClock.is_load_barrier_held/acquire_load_barrier`,
   `Inventory.is_transaction_poisoned`, `Residents.directory/state_bytes/spawn/
   despawn`, `EntityDirectory.state_bytes`, `ItemDefinitions.load_from_file/
   DEFAULT_JSON_PATH` and `save_codec.Writer.write_utf8_u32` are all assumed
   present with the signatures the tests use. Import/static/editor passes are the
   only way to settle this.
3. **Reflection in tests.** `_inv.set("_tx_poisoned", true)` injects the poison
   state rather than reaching it through a real poisoning path; the guard is
   exercised, the path is not. Acceptable, but worth recording.
4. **Registry heading order.** `save_gear_restore.gd` is filed between
   `spatial_world.gd` and `stock_age.gd` rather than in alphabetical position
   (the same pre-existing placement as `save_reservations_restore.gd` and
   `save_stock_age_restore.gd`). Presentation only; the coverage script checks
   presence, not order. Bounded fix: move all three headings, or none, in one
   separate editorial pass.

---

## H. Disposition

No correctness blocker. Six bounded acceptance gaps (C1–C6), of which C1–C3 are
genuine non-vacuity holes that a surviving mutant could exploit and should close
before acceptance. Accounting, wire arithmetic, gate order, publication
atomicity, scope discipline and registry edits conform to the accepted v2
contract as read. Acceptance still depends on parent-run suite, import, static,
editor, mutant and exact-head CI results, which this review does not and cannot
supply.
