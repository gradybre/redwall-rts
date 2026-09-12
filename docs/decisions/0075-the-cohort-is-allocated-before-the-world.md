# 0075 — The cohort is allocated before the world, and §5.1's "IDs 1–12" is literal

Date: 2026-09-11 · Status: **Accepted**. Supersedes the open half of
[0071](0071-world-generation-creates-the-cohort.md), whose arithmetic is retained
below as the record of what was wrong and why it looked forced.

## Decision

`SettlementSystem.create_generated_settlement()` is one transaction in the order
[R-INIT-ID-001](../rulings/2026-09-11_initial_ids_and_narrow_alerts.md) requires:

1. **Preflight**, mutating nothing: the settlement must be empty, the seventeen
   resource ids must bind against the compiled catalog, `WorldInit.preflight()`
   must stage and validate the whole terrain plan, and `_refuse_cohort_preflight()`
   must prove the cohort's species catalog, capacities, schedule template and
   opening-day weather preconditions.
2. **Enter the transaction**: `reset()` once — every store, the directory and its
   allocators, the command queue, the job store and the published map — then
   `WorldInit.seed_prepared_streams()` seeds all nine RNG streams, before any
   consumer draws.
3. **Allocate the twelve residents first**, in §5.1's cohort order, through the
   ordinary directory allocator, and attach their Priorities, Schedule and
   JobAgent rows inside the transaction. They receive persistent IDs **1–12**;
   **Warden Rowan is ID 1**.
4. **Publish the world from the same counter.** `WorldInit.publish_prepared()`
   clears nothing and seeds nothing, so the first world entity is **13**.

`WorldInit.generate()` survives unchanged in contract as the standalone reset
wrapper the ruling preserves "for isolated controls": it is `preflight()`,
`_reset_stores()`, `seed_prepared_streams()`, `publish_prepared()`.

## Why

Decision 0071 recorded the order as *forced*: `world_init._publish()` called
`EntityDirectory.clear()`, so a cohort spawned first was destroyed by its own
world, and §5.1's own world content consumed the id space first:

| Source | ids |
|---|---|
| Published `ResourceNode` rows (1663 tree + 32 ore) | 1695 |
| Tree nodes the ore footprints replace — created, then destroyed, never reused | 8 |
| `HarvestZone` basins (4 forest + 3 fish) | 7 |
| `FishHabitat` rows | 3 |
| **Total** | **1713** |

so the cohort received 1714–1725. The specification owner ruled that that reset
is **a reset before new-world allocation, not a second reset inside terrain
publication**, and that `EntityDirectory.clear()`'s location inside `_publish()`
was "implementation structure, not an owning-spec constraint". The constraint 0071
treated as immovable was ours, not the GDD's, so the composition boundary moved
and the ids came out where §5.1 says they are.

**What was explicitly not done**, each forbidden by the ruling: no generate-then-
renumber, no skipped reset across new worlds, no per-kind id counters, no id
forced into a live row, no reserved offset. No allocator state and no save-schema
field was added. `EntityDirectory` gained one reader, `ref_of_slot()`, which
rebuilds the GDD §4.1 `(slot, generation)` pair from a slot the ruling's audit
walks; it adds no column.

**The counter is derived, never pinned.** `test_the_next_persistent_id_is_derived_from_every_allocation_event`
counts live directory rows and adds the tree nodes created-then-destroyed by the
ore footprints, itself derived from the run's own plan counts. It prints the
result and asserts a probe allocation equals it. Today that reports **1725 ids
consumed, next id 1726**, which is the ruling's illustrative total — reached by
arithmetic, so later composition moves the test with the code.

## Consequences

- §5.3's `hash(persistent_id, world_seed)` name generation now hashes the ids the
  GDD names. Nothing else observably depended on the old values: `jobs.gd`'s
  stagger is `persistent_id % 30`, and twelve consecutive ids still give twelve
  distinct offsets.
- **`publish_prepared()` proves the caller reset instead of trusting it.** It
  refuses `WORLD_NOT_RESET_FOR_PUBLICATION` when any store it fills still holds a
  row, and `WORLD_SEED_NOT_APPLIED` when the streams are unseeded or carry another
  seed. A plan is held between preflight and publication and is dropped on every
  abandon path, so an abandoned transaction cannot publish a stale world later.
- **A refused initialization retains the previous valid world by preflight, not by
  rollback, and one case is genuinely unrestorable.** A world with residents in it
  refuses at step 1 and is byte-identical afterwards — proved by
  `test_a_refusal_before_the_transaction_retains_the_previous_valid_world`. A
  published world with **no** residents is the only thing the transaction can
  overwrite, and if the transaction then fails the settlement returns to empty
  rather than to that map: restoring it would mean re-running generation, and a
  regenerated world is a different set of persistent ids rather than the same world
  back. This is named in `_abandon_transaction()` and reported, not hidden.
- Source-only generation geometry and census are unchanged: still 1695 resource
  nodes, 7 basins, 3 habitats, seed 20260905. `test_the_three_steps_publish_the_same_world_the_wrapper_does`
  compares the composed path against the standalone wrapper by content digest.
- **No golden state hash needed regenerating, because none exists.** The only
  committed digest in the suite is `test_catalog_ids.gd`'s `COMMITTED_SHA256`, which
  covers the compiled item catalog and is untouched by identity order;
  `test_world_init.gd`'s two fingerprints are computed within each test. Old and new
  world-state digests are therefore not claimed to match — they were never compared,
  and the identity order genuinely changed.
- **Save/load identity preservation is not evidenced, because no codec exists.**
  `save_codec.gd` and `save_header.gd` do not exist anywhere in this repository
  (`grep -rl save_codec .` finds nothing); task 09 owns the codec. When one lands it
  must preserve these ids across a round trip, and that is its test to write.

## Source

- `docs/rulings/2026-09-11_initial_ids_and_narrow_alerts.md` §R-INIT-ID-001 — the
  ruled lifecycle, the forbidden shapes and the required evidence.
- GDD §5.1 ("IDs 1–12; ID 1 named Warden Rowan"), §4.2 (`EntityIdentity`, "IDs
  unique across kinds"), ARCH-ID-001–004, task `04_world_commands.md` §04.3.
- Decision 0071 for the arithmetic this overturns; decision
  [0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) for
  allocate-before-consume, which the ruling leans on at world scale.
