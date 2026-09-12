# 0105 — The directory publishes its six columns, and rebuilds everything else on restore

Date: 2026-09-12 · Status: **Accepted**

Closes **BLOCKER D1** from
[decision 0103](0103-section-3-writes-six-columns-and-rebuilds-the-rest.md):
`godot/scripts/core/entity_directory.gd` had no bulk column reader or writer, so
ARCH-SAVE-002 §3 could encode a `Record` but could neither capture one from a live
directory nor apply one to it. This record fixes the judgements adding those two calls
required. It does not close 09.2, does not certify a production save, and does not
touch **BLOCKER D2**.

## Decision

1. **Two bulk calls, in the shape decision 0103 asked for, and no third.**
   `copy_columns_into(out_active, out_generation, out_retired, out_persistent_id,
   out_kind, out_typed_row) -> bool` and `restore_columns(active, generation, retired,
   persistent_id, kind, typed_row) -> bool`. The six columns and their category-1
   classification are unchanged from the registry. Packed arrays are passed by
   reference in Godot 4 (verified on 4.7.2 for a script member as well as a local), so
   each buffer is refilled in place; `copy_columns_into()` hands back **snapshots**,
   not aliases.

2. **`restore_columns()` rebuilds every category-2 member, and the rebuild IS the
   validator.** `_typed_owner_slot`, `_free_heap`, `_heap_index`, `_kind_free_count`,
   `_kind_live_count`, `_free_count` and `_live_count` are recomputed; `_kind_base` is
   the prefix sum of a compile-time constant and never moves. A duplicate
   `(kind, typed_row)` is caught inside `_fill_owner_map()`, at the instant two live
   slots try to own one arena entry — not by a separate pass that could drift from the
   fill it is supposed to describe.

3. **Ascending fill is load-bearing and is pinned by a test, not by a comment.**
   Both free windows are filled ascending, live slots and retired slots excluded.
   `_pop_min()` returns the window minimum, so allocation order depends on the free
   **set** and not on the permutation — which is what makes a rebuilt heap allocate
   exactly as the saved one would, and why the tail beyond `_free_count` is stale
   garbage that must never be persisted.
   `test_restore_columns_pins_allocation_order_across_a_round_trip` runs one fixed
   interleaved create/destroy script against the saved directory and against the
   restored one and compares the whole slot sequence, then compares the typed row the
   next resident lands on. A descending free-slot fill and a descending free-row fill
   are separate mutants and both die there; no "the same slots are live" assertion sees
   either.

4. **A refused restore leaves the directory byte-identical, proved by image
   comparison.** Decision 0059 matters more here than anywhere else, because every
   `EntityRef` in every other section resolves through this store. Everything
   checkable without mutation is checked first; the collision scan is the one step that
   must write `_typed_owner_slot` and `_kind_live_count` to find its answer, and on
   refusal those two are rebuilt **from the directory's own untouched columns** by the
   same `_fill_owner_map()` call. That rollback is exact because the reverse map is a
   pure function of `_active`/`_kind`/`_typed_row`, which the refusal path never wrote.

5. **`state_bytes()` is added, and it emits the free windows SORTED.** It carries the
   six columns, the reverse map, the three per-kind counter arrays, `_free_count`,
   `_live_count`, `_next_persistent_id`, and each free window's live prefix sorted.
   Sorting is not laziness: by decision 0103's own argument the permutation is not
   state, only the set is, so a live directory and its restored copy are comparable
   only as sets. The heap tails and both category-3 refusal codes are excluded — a
   refusal must not alter the image that proves it changed nothing. Verified
   non-vacuous by mutation: `state_bytes()` returning an empty array is killed by three
   assertions that require two images to **differ**.

6. **A second refusal namespace, `last_column_refusal()`, separate from
   `last_refusal()`.** Callers read `last_refusal()` immediately after a `NULL_REF`
   from `create()`; a save or a load clobbering it would make a create refusal report a
   column problem. The two never share a value either — every column code is prefixed
   `COLUMN_`, including `COLUMN_LIVING_CAP`, which deliberately does **not** reuse
   `LIVING_CAP_RESIDENT`. ARCH-ID-004 numbers the `create()` codes and publishes no
   registry for column operations, so these spellings are a **proposal**, recorded here
   rather than presented as ruled.

7. **The validation is deliberately duplicated between the directory and §3, in one
   direction only.** `save_section_directory.gd` preloads the directory and never the
   reverse, so the directory cannot delegate to the section's validator, and the store
   that every reference resolves through must not depend on being called through a save
   codec to stay consistent. §3 keeps the wire format, ARCH-SAVE-004's unique
   persistent IDs and the §3-specific rules; the directory re-checks its own invariants
   (shape, occupancy bytes, non-negative generation, live-slot identity, retirement in
   both directions, free-slot unused values, the living cap, and the collision). A
   divergence between the two surfaces as `SAVE_DIR_STORE_REFUSED_COLUMNS` and a
   written-nothing store, which is a loud failure rather than a half-loaded world.

8. **Unique persistent IDs are NOT re-checked in the directory.** §3 owns
   ARCH-SAVE-004, the allocator never reads `_persistent_id`, and while D2 is open
   `restore_columns()` cannot guarantee uniqueness across the reload anyway — a second
   implementation of that rule would be two things to keep in step for no gain.

9. **`_next_persistent_id` is not written, not restored, and the gap is pinned by a
   test that fails in both directions.**
   `test_restore_columns_does_not_restore_the_persistent_id_allocator` asserts the
   restored image **differs** from the saved one, then sets that one scalar by hand and
   asserts the images are then identical. If a later change starts restoring it here,
   the first assertion goes; if the rebuild ever stops being exact, the second does.

10. **Section 3's `capture_into()` and a new `apply()` are the wrappers.**
    `capture_into()` copies into a local `Record`, validates it, and writes the caller's
    Record only on success. `apply()` validates the Record, then calls
    `restore_columns()`. `capture_columns_into()` stays as the column-level entry point.
    `agrees_with_directory()` is deliberately left scoped to the PUBLIC readers so it
    remains an independent cross-check rather than comparing `copy_columns_into()` with
    itself.

## Why this API instead of reading the directory's underscore columns

The directory's other readers answer only for live slots, so the generation of an
**inactive** slot — the exact value the registry requires to survive verbatim — was
unreachable. No module in this repository reads another's underscore-prefixed columns,
and §3 declined to be the first; the precedent is `save_section_world_runtime.gd`'s
BLOCKER W1 against `sim_clock.gd`, which Astra resolved by ruling `restore_runtime()`
into existence rather than by permitting the reach-in. This is the same resolution:
the invariants of the two min-heaps stay in the one file that owns them.

## What the tests pin, and what mutation proved

Sixteen mutants, one per Godot invocation, each production file restored and
`shasum -a 256` byte-compared afterwards; all sixteen killed. The six the work was
required to kill: a descending free-list fill (and, separately, a descending free-row
fill), live slots left in the free heap, a retired slot restored as reusable, a
duplicate `(kind, row)` accepted, a refusal that leaves the directory partly written
(two variants: no rollback, and install-before-validate), and counters carried over
from the overwritten world instead of rebuilt.

One finding worth keeping: the round-trip test's "re-encodes byte for byte" assertion
is **vacuous** against a `capture_into()` that publishes nothing — both sides encode an
empty world. Only the allocation-order comparison caught that mutant, and a
non-vacuousness assertion on the captured record was added afterwards.

## Consequences

- §3 can now round-trip a live directory: capture → encode → decode → apply →
  re-encode is byte-identical, and the reloaded world allocates identically.
- **D2 is now more visible, not less.** A world can be reloaded with every slot,
  generation and retirement intact and will still reissue persistent IDs from 1,
  because §1 WORLD carries no `next_persistent_id`. Two tests state that in the
  positive.
- `restore_columns()` overwrites generations in both directions, so it is a load-
  boundary call onto a directory whose previous contents are being discarded. A
  reference taken before the call belongs to a different world; the docstring says so.
- Rows owed to files outside this work's allowlist, reported and **not applied**: one
  category-3 member row for `_last_column_refusal` in
  `docs/persistence_state_registry.md`'s `entity_directory.gd` section (alongside the
  existing `_last_refusal` row), and — if the registry is taken to be the record of
  *how* each column is restored — a note on the free-heap row that ascending refill is
  now `restore_columns()`'s and no longer only `_rebuild_free_heaps()`'s.
  `state_registry_coverage.py` passes without them, because it checks packed columns.

## Source

- `docs/persistence_state_registry.md`, `godot/scripts/core/entity_directory.gd`
  section — the category-1/category-2 split, and "ARCH-SAVE-002 already requires all
  generations including free/retired slots".
- [Decision 0103](0103-section-3-writes-six-columns-and-rebuilds-the-rest.md) — the
  requested signatures and the ascending-fill requirement, quoted rather than invented.
- [Decision 0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) — allocate before consume.
- [Decision 0104](0104-the-load-barrier-is-a-token-the-clock-holds.md) and
  RESTORE-R01 — the precedent for ruling a missing restore API into the owning module.
- `AGENTS.md` — integer authoritative state, the 256 living cap, `EntityRef` shape.
