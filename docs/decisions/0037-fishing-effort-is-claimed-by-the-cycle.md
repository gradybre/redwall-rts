# 0037 — Fishing effort is claimed by the cycle, and habitats are bound, never created
Date: 2026-09-09 · Status: Accepted — planner ruling received 2026-09-09
Implements `docs/rulings/2026-09-09_ready06_open_item_answers.md` §5 and §8B.
Ratifies [0027](0027-fishing-needs-two-columns-4-2-omits.md).

## The decisions

**1. There is no single-slot effort API any more.** `reserve_effort_slot()` and
`release_effort_slot()` are replaced by `reserve_effort_slots(expedition, job,
habitat, slot_count)` and `release_effort_slots(expedition)`. §5.4's gear table
gives a weir and a boat **two** effort slots each and a net, trap or ice kit
one, and the ruling is explicit that "two single-slot calls without rollback are
not a safe two-slot admission API". Every condition is checked before a single
column is written, so a refused two-slot request takes nothing — the
allocate-before-consume hazard decision 0024 named.

**2. Slots are owned, not counted.** `FishingEffortClaim` is a fixed slice
indexed by **Expedition typed row** — 512 rows, `active:B8` plus six I32
columns, **12800 bytes**, no child heap. Claim publication and the `effort_used`
change happen together, so completion, cancellation and stale calls release
exactly that owner's slots exactly once, and the aggregate is **rebuilt from the
live claims on load** rather than trusted.

**3. Only a coordinator Job owns a claim.** A member Job is refused
(`JOB_IS_MEMBER`), which is what makes cancelling one party member unable to end
the coordinator's cycle — decision 0017's rule, enforced here structurally.

**4. "Default to restocking" blocks harvest.** `fishing.gd`'s header labelled
that an interpretation; the ruling makes it the contract. The latch transitions
are `100*P < 30*K` to enter and `100*P > 40*K` to clear, both **strict**, and
the latch is updated **independently** of the intensive-harvest override so
lowering the policy restores the restriction on the next call.

**5. A designation binds; it never creates.** `habitat_slot_for_designation_into()`
resolves designation → its existing `HarvestZone.basin` → the unique
`FishHabitat` whose `zone` equals that basin reference, validating **both**
generations and requiring **exactly one** match by scanning the bounded 32
habitat rows. `generate_initial_estuary()` is the world-generation operation and
produces exactly three habitats and nine stocks.

## Why these shapes and not the obvious ones

**Why no `expedition_slot` column.** The ruling budgets six I32 columns and
lists only `expedition_generation`. The row index already *is* the Expedition's
typed row, so the missing slot is recovered from the directory's existing
reverse map through a new reader, `EntityDirectory.owner_slot_of_typed_row()`.
That reader allocates nothing: `_typed_owner_slot` exists for ARCH-ID-003's
validator. Adding a slot column would have been 2048 bytes over budget for a
number the directory already holds.

**Why validation is two steps, in that order.** The directory settles that a
reference is live. Only the *stored* generation can tell that the claim sitting
on a live expedition's row was written by a **previous** expedition that
occupied the same typed row. A single check cannot express that, and the case is
reachable: destroy an expedition without releasing, and the next one takes its
row. `purge_stale_effort_claims()` is what frees such a row.

**Why the latch is cross-multiplied.** `population < floor(K*30/100)` and
`100*P < 30*K` agree only while K is a multiple of 10. §5.4's nine capacities
all are, so this changes no shipped number — but the ruling states the
comparison, equality at 30% and 40% must not flip the latch, and a future
capacity that is not a multiple of 10 would silently move the boundary.

**Why fishing.gd now takes a `forage.gd` collaborator.** forage.gd owns the
`HarvestZone` row, and the old header recorded that the zone's `ZoneType`
therefore could not be checked here. It still is not read directly: an
**optional** store is supplied the same way forage.gd takes an optional
`jobs.gd`, and with it the ecology-creation path requires ZoneType.FISH and a
self-owning basin. Without it, the designation resolution refuses
`NO_ZONE_STORE` rather than guessing.

## Consequences

**Blocked, and named rather than invented.** The **Expedition store's columns do
not exist** — §4.2 declares the row and no module implements it. Claims are
therefore allocated and validated through `entity_directory.gd`'s
`KIND_EXPEDITION` alone; nothing here reads a phase, a crew or a cargo, and the
hazard and rare-quality FISHING draws remain the expedition owner's. Only §5.4's
"Workers/effort slots" column of the gear table is compiled; the rest of that
table is still blocker U5.

**Two mutants survive as proved equivalents**, recorded so a later reader does
not mistake them for gaps:

- The duplicate branch of the basin scan (`DUPLICATE_HABITAT_FOR_BASIN`) is
  unreachable, because `_refuse_zone_binding()` prevents two habitats from ever
  naming one basin reference. Prevention is the reachable half and is tested;
  the scan's check is defence in depth for a future loader.
- `daily_regrowth_milli_into()`'s `P == K` early return — see decision 0036.

`destroy_habitat()` still refuses while any effort slot is reserved, so a claim
naming a dead habitat is unreachable; `_release_effort_claim_row()` handles it
anyway rather than subtracting from a row that is gone.

## Packed payload
- `FishingEffortClaim`: **12800 bytes**, new, `[ruling §5]`.
- Decision 0027's three columns: **256 bytes**, ratified — `effort_used` 128,
  `restocking` 96, `intensive_harvest` 32.
- Load scratch (`_effort_total_scratch`, I32[32]): **128 bytes**, reported by
  `effort_total_scratch_bytes()` and counted **outside** both figures.

## Source
`docs/rulings/2026-09-09_ready06_open_item_answers.md` §5 and §8B, adopted by
Brendan as part of the whole READY_06 handoff. GDD §4.2, §5.1, §5.4;
decisions [0017](0017-party-work-versus-single-job-worker.md),
[0024](0024-work-tick-optimization-order.md),
[0026](0026-forage-patches-belong-to-the-basin.md),
[0027](0027-fishing-needs-two-columns-4-2-omits.md).

## Evidence
`./tools/run_tests.sh` on this change: **1264 tests, 36408 assertions, 0 failures**
(the branch's HEAD before it was 1224 / 35844 / 0). 40 mutations, one per run,
each restored and `shasum` byte-compared: 38 killed, two proved equivalent. The
two mutants killed only by an `_init` drift assert — swapping the gear table's
boat and hand-net entries, and resizing the claim slice to 256 — are each paired
with a value mutation of the same number that a test kills on a mismatched
result (`BASIC_GEAR_EFFORT_SLOTS` 1→2 and the 12800-byte payload assertion).
