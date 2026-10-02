# 1023 — Haul payloads are sized at assignment and go to the lowest eligible store
Date: 2026-10-02 · Status: Accepted (slice H2 of task 06.4); P1–P3 ruled by Brendan 2026-10-02, all as recommended

## Decision

Slice H2 builds haul admission in a new `haul_planner.gd` on Brendan's 2026-10-02 rulings R-H3,
R-H6 and R-H7 (decision 1021).

1. **Sizing (REQ-SET-111, BAL-WORK-003).** `payload_milli_into()` is
   `min(available, floor((carry_g − other_cargo_g)·1000 / m))` -- exactly the largest quantity
   whose per-lot charge `ceil(q·m/1000)` fits (a massless item would go whole; the branch is
   defensive, since `register_item()` refuses mass 0). `trips_into()` is
   BAL-WORK-003's planning formula; a test pins that the actual per-lot-ceiling departures can be
   one more (3428571 milli-U at 7 g/U: plan 2, departures 3). `travel_ticks_into()` is the
   straight-leg lower bound; `handling_milli_wu()` is BAL-CAT-010's 2000/2000 cut to 1800 on a
   REQ-SET-134 pantry connection. REQ-SET-032's 30/300 lease ticks are published constants.
2. **Demand.** `next_haul_lot()` walks a source in list order to lots with unclaimed quantity --
   one item lot per job (R-H6). `is_standing_haul_source()` is true for REQ-SET-110's ground
   piles and for a satchel left by a cancelled haul (R-H2b), each while it holds unclaimed goods; a building store is a source only
   when something names it (D6's evacuation intent, an output policy).
3. **Destination (R-H3).** `select_destination_into()` takes decision 0534's R1 for hauling: the
   lowest container slot, walked with the new allocation-free `inventory.next_container_anchored_in()`
   over the complement of the source building's footprint, that is not the source, not a pile,
   not a satchel, owned by a different live ACTIVE Building, reachable, admitting the item's
   category and with free mass for the whole charge. The footprint mask costs only the footprint's
   own rectangle: between calls it is all ones, and the rectangle is cleared for one choice and
   restored after it (review M4: the first build rewrote all 16384 tiles, about 0.27 ms a call).
   Else R2: ground piles from the source
   building's refund seeds, proved by a rolled-back placement, reserving nothing; the unload tile
   is the first eligible seed. A source with no Building owner has no R2 and refuses
   `HAUL_NO_DESTINATION`, REQ-SET-031's cause.
4. **Admission (REQ-SET-030/031).** `admit()` sizes the payload against the hauler's carry limit,
   chooses the destination, reserves the store's grams, then takes the HAUL_SOURCE claim through
   `claim_batch()`; a refused claim gives the grams back exactly, so a refusal is byte-identical and
   its code is the blocking cause. A satchel source admits only its owner. `cancel()` releases the
   grams and every claim the job holds (after the load, the goods stay in the satchel unclaimed).
   **`complete_unload()` unloads through the haul's own record** -- into the recorded store with
   exactly the recorded grams, or breadth-first from the recorded tile -- and retires the record
   only when the unload succeeded, so a late `cancel()` refuses instead of releasing grams the
   delivery already returned (review H1/H2: a separate `finish()` let a cancel after the unload
   take another job's grams, and let a pile unload of a store destination leak its grams).
   `audit()` checks that, per store, the records never hold more grams than the store reserves;
   it rescans the 8192 rows per store, so it is a test and diagnostic tool -- a save-time check
   should sum per store in one pass first (H8).
5. **The ReservationPurpose domain is numbered (R-H7).** `PURPOSE_UNSPECIFIED = 0` (the value a
   cleared row holds and every pre-domain claim carried), `PURPOSE_HAUL_SOURCE = 1`,
   `PURPOSE_HAUL_DESTINATION = 2`, in `reservations.gd`, explicitly, never by a sorted-key compile.
   HAUL_SOURCE claims the payload at its source until the load; HAUL_DESTINATION claims the same
   goods in the satchel, owed to the destination, until the unload.
6. **The destination record.** Inventory's `reserved_mass_g` is one anonymous total per container
   (decision 0534), so the haul records which store holds its grams: one row per reservation-pool
   Job key (8192) -- job generation, destination container pair, unload tile (I32) and grams (I64)
   -- 196608 B, folded into §3's Auxiliary payload as `HaulAdmission`. Registry: UNRESOLVED with
   its question, as decision 0534 classified the demolition record.

7. **"Filters admit" asks the store policy (added when master's decision 1031 merged in).**
   R1's filter clause calls `store_policy.store_admits(candidate, item)` -- the container's
   category mask AND, for a building's main store, its per-item allow byte -- as decision 1031 P3
   rules; `bind()` takes the store policy as a required sixth store. A building that disallows an
   item sends its haul to the next eligible store. Capacity and reachability stay separate
   clauses, as `store_admits()` intends. Decision 1031 P2's haul-out demand for disallowed stock
   and its `inventory.container_accepts_item()` follow-up are H5's and H8's, not done here.

## Why

- **R1 restated, not called.** Its only implementation is `settlement_system.gd`'s private
  `_is_output_store()`, which this branch could not touch while DEMOLITION-D6 changed that file.
  The predicate here has the same clauses plus "not a satchel"; folding both into one reader is
  follow-up work for H3, which owns `settlement_system.gd`.
- **A cursor instead of a pair buffer.** `containers_anchored_in_into()` needs a caller buffer of
  2 × 101376 cells (811008 B); the cursor walks the same rows in the same order for nothing.
- **Grams first, then the claim.** Releasing container mass restores the exact field; the pool's
  claim refuses cleanly with nothing written. The other order would need a pool rollback that
  can land the row at a different index.
- **The carried claim is HAUL_DESTINATION** because a Reservation row names a LOT (GDD §4.2);
  destination capacity is container mass, which Inventory reserves and this record attributes.

## Brendan's rulings on P1–P3, 2026-10-02

All three approved as recommended (relayed by the coordinator); no behaviour changed here:
- **P1 → as built.** HAUL_DESTINATION means the claim on the carried lot from load to unload.
- **P2 → refuse later.** The pool keeps admitting any int32 now and refuses unnumbered purposes
  once every producer is numbered; that change belongs to whichever slice numbers the last one.
- **P3 → (a) for piles, (b) for satchels.** A pile source with no free store stays queued with
  HAUL_NO_DESTINATION. A satchel's goods with no free store go down at the hauler's tile, through
  the drop path (`drop_seeds_into()` + the pile mover); H4 builds that.

## Proposals as offered (the documents were silent)

- **P1 -- HAUL_DESTINATION's meaning.** Built: the claim on the carried lot from load to unload.
  Alternative: a purpose for a container-capacity claim, which would need a new row shape GDD
  §4.2's Reservation does not have. **Recommend as built.**
- **P2 -- unnumbered purposes.** Built: the pool still admits any int32 so nothing unnumbered
  breaks. Alternative: refuse every value outside the numbered domain once each producer is
  numbered. **Recommend refusing when the last producer is numbered.**
- **P3 -- a pile or satchel source with no store.** Built: queued with HAUL_NO_DESTINATION.
  Options: (a) as built; (b) a satchel's goods go down at the hauler's tile (the drop path);
  (c) the nearest building's ring. **Recommend (a) for piles, (b) for satchels in H4.**

## Consequences

- H4 calls `admit()` at assignment with `now + LEASE_EXPIRY_TICKS`, `load_payload()` after WORK's
  2000 milli-WU, and `complete_unload()` after HAUL_OUTPUT's -- never `haul_carry`'s unloads
  directly, which would leave the record's grams for a later `cancel()` to release twice. **Every early end goes through
  `cancel()`**: a cancellation, the hauler's death or departure (`cancel()`, then
  `haul_carry.drop_satchel()` before despawn), and a lease the pool expired. Anything else leaves
  the record's grams reserved in the store, which `audit()` does not see (it checks the other
  direction) but which blocks that store's destruction.
- A store that filled before the unload refuses `complete_unload()`; the record stays, H4
  cancels and re-admits. An unload onto piles starts from the recorded tile only; the
  admission's proof walked the whole ring, so a world that changed in between refuses the
  unload's own preflight and H4 re-plans.
- Memory: +196608 B record (§3) and +34956 B scratch (one §2.3 row, `haul_carry.gd`'s 40 B
  included). After merging master (decision 0537's +16384 B): payload 70955808, live 79344416,
  headroom 20655584; the rejected two-world peak is 463128 B worse. `ready07_arithmetic.py` pins
  it. The capacity audit sidecar is regenerated (source hashes moved).

## Evidence

See decision 1022's Evidence: the two slices were built, tested, mutated and reviewed together.
H2-specific: `test_haul_planner.gd` (31 tests) pins every R1 clause, R2's proof with a full
ring pile, the 3-departure / 2-trip case, the 150-tick 16 m leg, 1800 milli-WU by a pantry,
byte-identical refusals, the late-cancel case and the planner audit.

## Source

Brendan's rulings of 2026-10-02 (decision 1021 R-H3, R-H6, R-H7); GDD §4.2 Reservation, REQ-SET-
030–033, 110–112, 134; BAL-CAT-010; BAL-WORK-003/004; BAL-NUM-001; BAL-SAFE-002/004/016; decisions
0019, 0532, 0534, 0537.
