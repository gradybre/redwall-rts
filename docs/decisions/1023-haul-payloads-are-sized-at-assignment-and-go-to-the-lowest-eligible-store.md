# 1023 — Haul payloads are sized at assignment and go to the lowest eligible store
Date: 2026-10-02 · Status: Accepted (slice H2 of task 06.4); proposals P1–P3 await Brendan

## Decision

Slice H2 builds haul admission in a new `haul_planner.gd` on Brendan's 2026-10-02 rulings R-H3,
R-H6 and R-H7 (decision 1021).

1. **Sizing (REQ-SET-111, BAL-WORK-003).** `payload_milli_into()` is
   `min(available, floor((carry_g − other_cargo_g)·1000 / m))` -- exactly the largest quantity
   whose per-lot charge `ceil(q·m/1000)` fits -- and a massless item goes whole. `trips_into()` is
   BAL-WORK-003's planning formula; a test pins that the actual per-lot-ceiling departures can be
   one more (3428571 milli-U at 7 g/U: plan 2, departures 3). `travel_ticks_into()` is the
   straight-leg lower bound; `handling_milli_wu()` is BAL-CAT-010's 2000/2000 cut to 1800 on a
   REQ-SET-134 pantry connection. REQ-SET-032's 30/300 lease ticks are published constants.
2. **Demand.** `next_haul_lot()` walks a source in list order to lots with unclaimed quantity --
   one item lot per job (R-H6). `is_standing_haul_source()` is true for REQ-SET-110's ground
   piles and for a satchel left holding unclaimed goods (R-H2b); a building store is a source only
   when something names it (D6's evacuation intent, an output policy).
3. **Destination (R-H3).** `select_destination_into()` takes decision 0534's R1 for hauling: the
   lowest container slot, walked with the new allocation-free `inventory.next_container_anchored_in()`
   over the complement of the source building's footprint, that is not the source, not a pile,
   not a satchel, owned by a different live ACTIVE Building, reachable, admitting the item's
   category and with free mass for the whole charge. Else R2: ground piles from the source
   building's refund seeds, proved by a rolled-back placement, reserving nothing; the unload tile
   is the first eligible seed. A source with no Building owner has no R2 and refuses
   `HAUL_NO_DESTINATION`, REQ-SET-031's cause.
4. **Admission (REQ-SET-030/031).** `admit()` sizes the payload against the hauler's carry limit,
   chooses the destination, reserves the store's grams, then takes the HAUL_SOURCE claim through
   `claim_batch()`; a refused claim gives the grams back exactly, so a refusal is byte-identical and
   its code is the blocking cause. A satchel source admits only its owner. `cancel()` releases the
   grams and every claim the job holds (after the load, the goods stay in the satchel unclaimed);
   `finish()` retires the record after the unload released its grams.
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

## Proposals for Brendan (the documents are silent)

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
  2000 milli-WU, `unload_into_store(dest, reserved_g_of(job))` or `unload_into_piles([tile])`
  after HAUL_OUTPUT's, then `finish()`; on cancel `cancel()`, and a fresh admit for satchel goods.
- An unload onto piles starts from the recorded tile only; the admission's proof walked the whole
  ring. A world that changed in between refuses the unload's own preflight and H4 re-plans.
- Memory: +196608 B record (§3) and +34952 B scratch (one §2.3 row, `haul_carry.gd`'s 40 B
  included); live 79328028, headroom 20671972; the rejected two-world peak is 463120 B worse.
  `ready07_arithmetic.py` pins it. The capacity audit sidecar is regenerated (source hashes moved).

## Evidence

Filled in below the line once the gates have run.

## Source

Brendan's rulings of 2026-10-02 (decision 1021 R-H3, R-H6, R-H7); GDD §4.2 Reservation, REQ-SET-
030–033, 110–112, 134; BAL-CAT-010; BAL-WORK-003/004; BAL-NUM-001; BAL-SAFE-002/004/016; decisions
0019, 0532, 0534, 0537.
