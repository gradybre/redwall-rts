# 0401 — Spoil becomes earth, not compost
Date: 2026-10-01 · Status: Accepted · Supersedes part of [0196](0196-the-live-demo.md) (spoil as soil) and of
[0205](0205-the-playtest-fix-pass.md) §13 (where cleared spoil goes) · Resolves [0222](0222-harvests-reserve-room-cancels-deliver-and-forecasts-count-calendar-hours.md)'s
open item on spoil carried for Raise/Bank/Compost

Review group L of the live-demo review (`redwall-review/REVIEW.md`: ECO-13 at line 1416, the earthworks loop at line
2001, ECO-F13 / ECO-047–049). Built on integrate/review-batch-3 6515825 (master plus group A, decision 0361, and the
sound pass, 0351). Everything here is the demo's presentation layer (`godot/demo/`); the simulation is untouched.

Number: the next free above 0400 after checking every branch and worktree (none at or above 0400 existed).

## The rule and the ruling

- **The adopted rule.** [`underground_economy_hazard_amendment.md`](../underground_economy_hazard_amendment.md)
  ECON-002 (SET-MOVE-ECON-001, adopted under DEC-040's engineering follow-through): `excavated_earth` is its own
  MATERIAL, "never alias stone or compost", with "no food/fertility/fuel benefit or sale recipe". GDD §5.7 makes
  compost from `spoiled_food 4 or roots 4`; REQ-SET-085 returns 0.5 U from a cleared withered crop; §5.8 composts
  expired seed. Every adopted compost source is plant waste.
- **Brendan's ruling, 2026-09-30** (relayed by the review-batch executor): align the demo with the adopted rule that
  **dug earth is never fertiliser**. Spoil becomes *earth*, used for raising beds, banking and backfill; compost comes
  only from plant waste. This replaces the demo's spoil→compost conversion, which Brendan had originally asked for as
  "spoil as soil".

## Decision

1. **No path from earth to compost or fertility.** The farm's Compost job no longer has a spoil plan
   (`farm_jobs.gd` COMPOST_FROM_SPOIL_PLAN, SOURCE_STORE / SOURCE_SPOIL, `compost_source` and the job's `source` column
   are gone; `open_into` and `plan_work_usec` lose their source argument). `farm_sim.gd compost(bed)` always pays its
   2 U from the compost store; `compost_refusal(bed)` always checks it. Raise and Bank only set their flags.
2. **Compost is plant waste only, and needed no new source.** The demo already had two adopted ones: clearing a
   withered or blighted crop (REQ-SET-085, +0.5 U) and the Pantry's "Compost it (4 → 2)" for spoiled food (§5.7).
   Planting a sapling still spends the farm's compost store. The store still opens at 4 U (0196's demo value).
3. **Earth is a real, conserved material.** `farm_tunnels.gd` keeps the earth books (EARTH): a mouth's heap is what was
   tipped on it minus taken; earth taken is in a basket or a hand, KEPT in the village stores, BUILT into a bed
   (`built_milli`, `build_with`) or put back (`return_spoil_into`). Cleared heaps' earth goes into
   `tunnel_stores.gd earth_milli_u` (`add_earth`, `take_earth`, all or nothing) instead of the compost store; the
   panels' stores line ends "· earth N U". At every moment: heaped = on the heaps + in clearing baskets + in farm
   hands + in the stores + built in (with no dig crew hauling; 0211's pile and dig baskets come before "on the heap").
4. **Raise and Bank fetch earth physically from a heap or the stores.** The stores are source STORE beside the heap
   rows (`bind_store`, which `demo_spoil.gd configure` does with the village stores at the stockpile's drop spot).
   The nearest source holding 2 U is walked to (`nearest_earth_into`), dug (2 WU), carried (the carry walk) and built
   in at the bed; arrival is A's explicit arrival (0361). The 2 U is unchanged; it is now named
   `EARTH_PER_JOB_MILLI`, a demo value (it had been justified as §5.6's compost dose).
5. **A carry of earth is never lost** (0222's open item, B's ruling that a cancel is not loss, A's
   `return_spoil_into`). A raise or bank that ends with earth in hand -- cancelled, refused at its bed, or unable to
   reach it -- becomes an **earth return** (`farm_jobs.gd KIND_RETURN_EARTH`, "Carry earth back", not an orderable
   kind): its carrier walks the earth back to the heap or stores it came from and tips it there on arrival (1 WU), as a
   cancelled sawing carries its logs back (0222). Cancel leaves it alone; a resident called away keeps it to come back
   to; unassigned, the field crew takes it. A return that cannot get through puts the earth back from where it stands
   (0361's rule for an undelivered basket). A source that refuses it (a heap whose mouth row was freed) passes it to
   the stores; with no stores it waits on the board holding it, as a harvest with nowhere to go does.
6. **Words.** "Compost from spoil" is gone everywhere: the farm card's costs (Compost: only "Compost (store)";
   Raise/Bank: "Earth (one heap or the stores)" as have / need, decision 0332), its needs, refusals and fixes
   (`NO_EARTH`: "no spoil heap or store holds 2.0 U of earth" — "Dig tunnel (B): its earth heaps up at the mouth";
   NOT_ENOUGH_COMPOST: "… from the compost store" — "Pantry (K) ▸ compost spoiled food, or clear a withered bed"),
   the results ("earth adds no fertility"), the frost alert ("raise them with earth"), the heap's notice ("N U of
   earth … haul it to the stores"), the hauling task ("Hauling earth to the stores"), the farm task texts ("to the
   stores for earth", "Carrying 2.0 U of earth back to the spoil heap"), the headers and the README.
7. **Not done: backfill, the HUD, the Pantry.** The tunnels have no operation that fills a dug passage (no
   removal, closure or dead-end abandonment exists in `demo/tunnel/`), so there is no cheap backfill hook; adopted
   backfill (ECON-002: 2000 milli-U and 3000 milli-WU per quantum) waits for one, as do tips, compaction and reclaim
   (ECO-047/048). Earth is not a top-bar cell (the shell is six cells, decision 0251) nor a Pantry row (it is not food).

## What of 0196 is superseded

0196's "spoil as soil" -- §58's "Raise, bank and spoil-compost each take §5.6's 2 U dose of tunnel spoil" (now:
raise and bank take 2 U of earth, a demo value; there is no spoil-compost) and the farm's reading of a heap as
compost material -- is superseded. Its drainage/irrigation, the raised and banked bed effects, the heap placement
(§36) and the 2 U per cubic metre stand. 0205 §13's "the demo's one use of spoil is compost … hauled into the farm's
compost store" is superseded by §3 above (already amended by 0361 for baskets called away).

## Why

- Earth that becomes compost is the one fertility source the adopted rules forbid, and it made digging a fertiliser
  mine. The review called the conversion "an intentional adaptation, not adopted fertility semantics" (ECO-13).
- Keeping the cleared earth in the stores (rather than deleting it or leaving it only on mouth heaps) keeps the
  playtest's clearing (0205) and makes it useful: a cleared heap is still earth for the next raise. Rejected: earth
  only on the mouth heaps (cleared earth would have been a dead end, and a card saying "no earth" beside 20 U kept
  would mislead); a drawn tip heap at the stockpile with its own obstacle row (new placement and nav cost, and P7's
  asset swap owns the stockpile's look).
- Walking a cancelled carry back follows the two rulings on record (cancel finishes the delivery; nothing credited or
  lost from afar) and the woods' precedent, rather than inventing a ground pile. **The one exception is 0361's own:**
  a carrier that cannot get back at all puts its earth back on its source -- or, when that heap will no longer take it
  (its mouth row freed), into the stores -- from where it stands. A clearing basket follows the same rule
  (`spoil_crew.gd _settle_load`). Earth is moved from afar only then, and only back to where it came from or to the
  stores; it is never lost and never credited to a bed.

## Consequences

- `farm_jobs.open_into(kind, bed, origin, out)`; `plan_work_usec(kind, from_step)`; `farm_sim.compost(bed)`,
  `compost_refusal(bed)`; `farm_crew.most_earth()` replaces `max_heap_spoil()`; `farm_tunnels.nearest_earth_into`
  replaces `nearest_heap_into`; `demo_spoil.configure` takes the stores instead of a deliver callable;
  `demo_village.give_compost` is gone. Any branch calling the old shapes must follow.
- Anything that later consumes earth (backfill, tips, landscaping) draws on the same books and must keep the
  conservation sum true.
- The stores line is one figure longer in the Tunnels and Water panels.

## Tests

`godot/test/test_demo_earth.gd` (new): no fertility from raising or banking; compost refused with heaps full of earth;
compost only from plant waste (a cleared crop, and a cleared heap leaving the compost store unmoved); earth conserved
every frame from the dig through clearing to beds built; Raise from the stores (card have / need = what is spent, the
party panel's words); no earth anywhere refused alike on card and order; a cancel mid-carry, a cancel mid-work, a
cancel from the stores, a carrier called away then cancelled, a raise refused at its bed, and a return that cannot get
through -- each conserving every frame; the stores' all-or-nothing earth; the store as a source; the village wiring.
Updated: `test_demo_farm.gd`, `test_demo_action_cards.gd`, `test_demo_farm_ui.gd`, `test_demo_spoil.gd`,
`test_demo_forestry.gd`, `test_demo_props.gd`, `test_demo_conservation.gd`.

Mutation testing: 53 mutants of the new logic (the earth books, the store source, the stores' earth, the earth
return and its fallbacks, the plans, the refusals, the card costs, compost store-only, the village wiring), one at a
time, sources shasum-checked after each, run against the earth, farm, farm UI, spoil, action-card and conservation
suites. 47 were killed at once; of the rest, one was equivalent (rewritten as a stronger mutant), one pattern did not
apply (rewritten), and four survived -- a source index below 0, the dig spot moved off the heap, the stores' take not
bumping their revision, and an unbound store reached (a script error the scratch runner had not counted). Tests and
the harness were tightened and every one is killed.

## Review (2026-10-01)

The independent code review of 12684ab found no CRITICAL or HIGH. Its MEDIUM and LOW findings were all applied in a
follow-up commit:
- **MEDIUM:** earth carried back was not redrawn on its heap -- `farm_view.gd _shrink_heaps` skipped a heap with
  nothing taken, and the tunnel overlay redraws a heap only when its tipped earth changes. So a heap emptied by a raise
  and then refilled by the cancelled raise's return stayed invisible. The view now keeps `_drawn_taken` per heap and
  redraws whenever what was taken changes, including back to 0.
- **LOW:** a stuck earth return (or delivery) raised a meaningless "farm:stuck:<bed>:10" incident; `_raise_stuck` now
  raises only for production.
- **LOW:** the heap-gone test moved its own conservation target; it now frees the mouth as `_free_node` does
  (`mouth_spoil` 0) and checks the books every frame, the no-store branch too.
- **LOW:** a clearing basket whose heap refused it back was zeroed (lost); it now goes into the stores.
- **LOW:** `take_spoil_into` ignored `take_earth`'s result; it now refuses.
- **LOW:** the wording above now names 0361's exception.
- **Optional:** `has_store()` is now `_is_source`'s test; the bed panel's Cancel tip says earth in hand goes back to its
  heap; `decide` reads `most_earth` once, and the card reuses it.

Mutation testing of the fixes: 14 mutants, one at a time, sources shasum-checked after each. 13 were killed (three
after new tests: the view redrawn every frame while earth is taken, a clearing basket whose heap has gone, and the
Cancel tip). One is equivalent: ignoring `take_earth`'s result cannot change anything, because `take_spoil_into`
checks the same amount against the same store first.

## Integration with review batch 4 (M's work board)

The work board (0411) landed before this branch. Its farm adapter shows an earth return as a delivery -- HAULING,
carrying, never claimed as farm production -- and Cancel refuses it (`work_ids.gd EARTH_GOES_BACK`); the farm crew's
`pause` and `reassign`, which the board's commands call, refuse while earth is in hand. See 0411's integration note.

## Source

Brendan's ruling of 2026-09-30 (above); `docs/underground_economy_hazard_amendment.md` ECON-002; GDD §5.6, §5.7, §5.8,
REQ-SET-076, REQ-SET-085; decisions 0196, 0205, 0211, 0222, 0332, 0361.
