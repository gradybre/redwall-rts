# 0536 — Furniture returns half by type, a piece can be removed alone, and only the coordinator completes a removal
Date: 2026-10-02 · Status: Accepted. Brendan's rulings on decision 0535's P1–P3, and his confirmation of this record's eight readings as rulings R1–R8 (2026-10-02)

Numbered 0536 because the follow-up brief offered it. No record numbered 0536 exists on any
branch (`git ls-tree` over every ref) or in any registered worktree when this was written;
`docs/validation/decision_numbers.py` refuses a collision at merge. It follows
[decision 0535](0535-demolition-completion-is-one-commit-and-furniture-refuses.md), whose
furniture refusal it replaces.

## Brendan's rulings, 2026-10-02 (relayed by the coordinator)

- **P1 (a):** a furniture piece's paid package is DERIVED from its type, as ruling R4 derives a
  building's (decision 0534), starter pieces included.
- **P1's sub-question, yes:** removing furniture adds a quarter of the piece's build WU to the
  demolition work.
- **P2, yes:** a single-piece removal door, as a D5 follow-up; #3b's live pantry-shelf recompute
  belongs there.
- **P3 (a), yes, before D6:** `commit_completion()` and `close_refund()` refuse a demolition by
  name; the pinned DEMOLISH retired-history fixtures are updated.

## Decision

1. **P1: a building's return includes every piece's 50%** (`construction.gd`).
   - `demolition_return_preview_into()`, `demolition_return_into()` and the three per-line readers
     now return the COMBINED return: the building's own half (BUILD-C4-R01: base + completed
     upgrade per item, floored once), plus, for every piece in the building's rooms, 50% of that
     piece's §4.3 bill floored once per item OF THAT PIECE ("same rule as buildings", the ruling's
     per-piece arithmetic). Every §4.3 quantity is even today, so flooring per piece and flooring
     the total agree on current data; the per-piece rule matters only once an odd quantity exists.
   - The combined return can name every material key once (furniture adds wax and iron), so the
     buffers are `RETURN_LINE_CAPACITY` = 6, and `construction.gd` keeps a 6-line halved scratch.
   - `open_demolition()`'s work is a quarter of the building's WU (and its upgrade's) plus a
     quarter of each piece's §4.3 WU. `_assert_bills()` already proves every §4.3 WU divides by 4.
   - Admit reserves the combined return (or proves the pile fallback for it). The commit's step
     (2) takes every piece out (`buildings.remove_furniture()`) after step (1) destroyed the pieces'
     stores. The starter hall, once its pantry is empty, is demolished with its 4 rooms and 31
     pieces (`test_the_emptied_starter_hall_is_demolished_with_its_31_pieces`).
   - `DEMOLITION_FURNITURE_PAID_PACKAGE_UNREADABLE` is gone. The one furniture refusal left is
     `DEMOLITION_FURNITURE_UNDER_CONSTRUCTION`: a piece whose own project is still live (being
     built, or being removed on its own) is not completed capital (BUILD-C4-R01 settles
     in-progress work through its cancellation first). It runs at the end of the preview and at
     the commit; `blocked_furniture_count` and `blocking_furniture` name the pieces.
2. **The admitted return is fixed at admission** (`demolition_admissions.gd`, +8192 B).
   The return now depends on the pieces present, so `record()` takes the admitted return's
   capacity charge for EVERY admission, a ground-pile fallback included; a store-bound
   reservation must equal it. The commit recomputes the return and refuses
   `DEMOLITION_RESERVATION_MISMATCH` when its charge differs -- a piece placed or removed around
   the coordinator since admission -- and stays commit-pending until it agrees (or is cancelled).
3. **P2: one piece can be taken out of a standing building** (`settlement_system.gd`).
   - `preview_furniture_removal(piece)`: the piece is live and in an ACTIVE building, unused, with
     no project of its own; its own stores (and any its project names) hold no goods and no claim
     (stages 2–3 for one endpoint); and #3b (item 4).
   - `request_furniture_removal(piece)`: the preview, then D4's *admit* unchanged in shape: the new
     `construction.open_furniture_removal()` (purpose `PURPOSE_REMOVE_FURNITURE`, work a quarter
     of the piece's WU, delivers nothing, policy REFUND_DEMOLITION, paid base key = the piece's
     type), the reservation of the piece's 50% in another building's store, else the pile
     fallback from the building's refund seeds, the admission record and the revision.
   - `complete_furniture_removal(piece)`: D5's commit with a piece subject. It proves the admitted
     project, its work, its claim, the preview's checks again and the return; then, in one
     inventory transaction, destroys the piece's stores, releases the claim and the record, lowers
     the pantry capacity (item 4), removes the piece (`remove_demolished_subject()`), places the
     return, commits, declares the piles, retires the project.
   - `cancel_furniture_removal(piece)`: free, like `cancel_demolition()` (ruling R5).
   - **A piece removed around the coordinator** (the store door `buildings.remove_furniture()`)
     while its removal is admitted leaves a live project with no subject, which neither complete
     nor cancel can reach (review M1). `release_stranded_reservation(building)` now recognises
     that shape, retires the orphaned project through `close_demolition_refund()` (nothing is
     returned: nobody took the piece), releases the claim and clears the record.
   - The commit's unreachable guard, before the inventory commit, re-records the admission
     while the BUILDING row stands; for a piece already removed that is exactly the orphaned
     shape the stranded door recovers (second review). A refusal of step (6) after the commit is
     logged, not undone. The abort does bring back a removed piece's stores and shelf capacity,
     which no door repairs; it is unreachable while the proofs hold.
   - A shelf removed around the coordinator and then recovered through the stranded door never
     applies #3b: the pantry keeps that shelf's 50000 g (the store door knows no Inventory).
4. **#3b's recompute** (`inventory.gd::reduce_container_capacity()`, new). A shelf in a PANTRY
   room carries `shelf_capacity_g_of()` = 50000 g of its building's pantry store; the kitchen's
   fifth shelf and any other piece carry none. **Validity is not required**, by #3b's own words
   ("A shelf adds 50,000 g of capacity to the Building-owned pantry container") and because that
   is how the capacity was granted: D3 gives the starter pantry 200000 g from its four shelves
   while nothing yet marks any room valid. Keying on `pantry_capacity_g_of_room()` (VALID PANTRY,
   R-BUILD-DOM-004's service query) would make #3b a no-op in play -- the review reproduced four
   starter shelves leaving a 179200 g pantry at 200000 g (review H2). Now the first starter shelf
   refuses until the pantry is drawn below 150000 g
   (`test_a_starter_pantry_shelf_cannot_leave_a_full_pantry`). The pantry store is the building's
   main store: its ONE owned container anchored at its origin tile (#3a); none or two refuse
   `FURNITURE_REMOVAL_PANTRY_STORE_UNREADABLE`. If its contents plus reservations would exceed the
   capacity left, the removal refuses `FURNITURE_REMOVAL_PANTRY_OVER_CAPACITY` naming the store, at
   preview and again at the commit; otherwise the commit lowers the capacity inside its
   transaction. Inventory's door refuses a dead container, a ground pile
   (`GROUND_PILE_CAPACITY_FIXED`: #9's 400000 g), a non-positive or oversized reduction and a
   reduction the contents and claims would not fit (`CAPACITY_EXCEEDED`); it is journaled.
   Inside a whole-building demolition #3b still reduces to stage 3's emptiness proof (0535).
5. **P3: only the coordinator completes or cancels a removal** (`construction.gd`).
   - `commit_completion()` and `close_refund()` refuse a demolition or a furniture removal
     `DEMOLITION_COMPLETES_THROUGH_COORDINATOR`. The DEMOLISH arm of `_apply_completion()` is gone.
   - The coordinator's doors: `remove_demolished_subject()` (renamed from 0535's
     `remove_demolished_building()`; a building or a piece), `retire_demolition()` (either), and the
     new `close_demolition_refund()` for a cancellation (a demolition's building returns to ACTIVE).
   - Updated on purpose: `test_construction.gd`'s two demolition-completion tests, the three
     DEMOLISH retired-history fixtures in `test_construction_retired_histories.gd` (each now also
     asserts the store door's refusal; the retired rows they pin are unchanged), and D4's three
     stranded-claim tests, which now strand a claim through `close_demolition_refund()` called
     around the coordinator.

## Brendan's confirmation of the eight readings, 2026-10-02 (rulings R1–R8)

The executor reported eight readings with this record; Brendan confirmed all eight on
2026-10-02 (relayed by the coordinator). No behaviour changed when they were adopted. They are
rulings R1–R8 of this record; each is stated in full where it lives below.

- **R1 — #3b ignores room validity.** Any shelf in a PANTRY room carries its 50000 g of the
  building's pantry store, valid or not yet (Decision item 4).
- **R2 — one admission per building.** A piece's removal is recorded on its building's row; the
  building's demolition and a second piece wait (Readings, first bullet).
- **R3 — a piece's return never goes to its own building's stores.** R1 of decision 0534 applies
  unchanged with the piece's building as subject (Readings).
- **R4 — a removal requires an ACTIVE building** (Readings).
- **R5 — the removal purpose sits outside ADR 0186's frozen enum** until
  CONSTRUCTION-SAVED-BINDINGS revisits that contract (Readings).
- **R6 — equal-charge furniture swaps are not detected** (Readings).
- **R7 — shelf capacity is subtracted, never added here;** a future shelf-placement path must add
  the 50000 g (Readings).
- **R8 — a shelf removed around the coordinator and recovered through the stranded door keeps
  its 50000 g in the pantry** (Decision item 3).

The Readings section's "coordinator's own doors stay public" bullet was not among the eight
presented; it stays a recorded consequence of ruling P3, not a separate ruling.

## Readings (confirmed as rulings R1–R8 above, except where noted)

- **One admission per building.** A piece's removal is recorded on its building's row in
  `demolition_admissions.gd`, so a building has at most one demolition OR one piece removal
  admitted at a time; no per-piece record (81920 rows) is allocated. A second piece waits
  (`DEMOLITION_ALREADY_ADMITTED`); the building's demolition waits too (its preview names the
  piece as under construction). Alternative: a per-piece record, which costs memory and a save
  owner.
- **The piece's return never goes to its own building's stores.** D4's store rule (R1: "owned by
  a different ACTIVE building, off the footprint") is applied with the piece's building as the
  subject, unchanged, so the bed's half goes to a stockpile or onto piles at the door rather
  than into the hall's own store. Alternative: admit the building's own stores, excluding the
  pantry store being reduced.
- **A removal requires an ACTIVE building.** A blueprint, a building under construction and a
  DEMOLISHING one refuse `FURNITURE_REMOVAL_BUILDING_NOT_ACTIVE`; an upgrading building is ACTIVE
  and may lose a piece.
- **The removal purpose sits outside ADR 0186's enum.** `PURPOSE_REMOVE_FURNITURE` = 4 is a new
  module ordinal; `PURPOSE_COUNT` stays 4 because ADR 0186's frozen local Columns validation pins
  it (`SOURCE_PURPOSE_COUNT`), and `LIVE_PURPOSE_COUNT` = 5 is what the live doors accept. That
  validation therefore refuses a removal row COLUMN_ENUM, and already disagrees with a tier-2 or
  furnished demolition's work (it declares W as the base WU x 0.25). No live path calls it and
  open projects are in no save yet; CONSTRUCTION-SAVED-BINDINGS must revisit that contract before
  saving one. Nothing in the frozen section was edited.
- **The coordinator's own doors stay public.** P3 closes `commit_completion()`/`close_refund()`;
  `remove_demolished_subject()`, `retire_demolition()` and `close_demolition_refund()` are still
  callable around the coordinator and would recreate an orphaned claim, which
  `release_stranded_reservation()` recovers. D6 must not call them directly (review L5).
- **Shelf capacity is subtracted, not recomputed.** A removed shelf takes a fixed 50000 g; no
  path ADDS capacity when a shelf is built (no shelf-build path exists yet). Whoever builds one
  (06.4 / D7) must add the same 50000 g, or repeated build/remove cycles would drain the store.
- **Equal-charge swaps are not detected.** The admitted-charge check catches any change in the
  return's mass; replacing a piece with a different one of exactly equal capacity charge would
  pass with that piece's return and the original's work. No authored pair of pieces has equal
  charge and unequal bills today.

## Consequences — what D6, D7 and D8 must know

- **D6:** demolition and piece-removal work is `add_work_mwu()` on the admitted project; complete
  through `complete_demolition()` / `complete_furniture_removal()` -- the store doors now refuse.
  Furniture no longer blocks admission; a piece's own live project does.
- **D7:** the notice reads `blocked_furniture_count` / `blocking_furniture` for
  `DEMOLITION_FURNITURE_UNDER_CONSTRUCTION`, and the single-piece door needs its own command (a
  REMOVE_FURNITURE arm; dispatch has none). `DEMOLITION_RESERVATION_MISMATCH` means "the building's
  furniture changed since you ordered this": cancel and re-request.
- **D8:** a piece's admission and its commit advance its BUILDING's destination revision, like a
  demolition's; no footprint changes.
- **Saving:** the admitted charge is UNRESOLVED-classified with the rest of the admission record
  (CONSTRUCTION-SAVED-BINDINGS), and ADR 0186's contract must learn the removal purpose and the
  real demolition W first.

## Memory

+8400 B: the admitted charge (1024 x I64 = 8192, folded into the Auxiliary payload row with the
rest of the admission record) and 208 B of wider return scratch (the coordinator's keys, milli and
spec rows from 4 to 6 lines, +24 +112; `construction.gd`'s 6-line halved return, +72). Live total
79096468, headroom 20903532; the rejected two-world peak a further 16800 B worse (−43559131).
`ready07_arithmetic.py` checks all of it; `persistence_state_registry.md` gains the three rows.

## Evidence

- **Suite, CI-style** (a clone of the final tree, `godot/.godot` deleted and re-imported, no
  `godot/demo/assets`): `8055 test(s), 578519 assertion(s), 0 failure(s)`; diagnostics
  `0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit:
  0 object(s), 0 resource(s)`.
- **Contracts.** All 42 scripts of `.github/workflows/tests.yml`'s contract steps pass, including
  `ready07_arithmetic.py` (the +8400 ledger), `state_registry_coverage.py` (three new rows),
  `audit_registry_capacities.py --check` (regenerated), and the construction metadata and
  allocation preflights. `gdscript_warnings.py` reports 0 on the 15 changed `.gd` files.
- **Tests added or changed.**
  - `test_settlement_furniture_removal.gd` (new, 21): the single-piece door end to end into a store
    and onto piles; a piece's own store; #3b (a full pantry refuses, at preview and at the
    commit; a shelf in a not-yet-valid pantry carries its capacity; the kitchen's shelf and a seat
    carry none; no single main store refuses); every refusal byte-identical; one admission per
    building; cancellation; the commit's rechecks; a piece removed around the coordinator released
    through the stranded door (store, pile, already refunding); the guard's re-record; a piece
    project opened after a building's admission; an admission in between keeping a piece's piles
    at its own building.
  - `test_settlement_demolition_complete.gd` (furniture section rewritten, 6): the combined return
    and work; five lines with wax and iron; two pieces of one kind; a piece under construction; a
    piece placed after admission, for a store and a pile admission.
  - `test_construction_demolition_completion.gd` (+10): P3's refusals and the coordinator's
    cancellation door; P1's work and return; P2's purpose, work, base key, refusals, subject step
    and retirement; the frozen validation refusing a removal row COLUMN_ENUM.
  - `test_inventory_capacity_reduction.gd` (new, 5), `test_demolition_admissions.gd` (charge shape
    and release), `test_settlement_starter_colony.gd` (+3, 1 rewritten: the emptied hall demolished
    with 31 pieces, a starter bed removed into the fourth stockpile, a full starter pantry keeping
    its shelf until drawn down).
  - Changed on purpose by P3: `test_construction.gd` (2), `test_construction_retired_histories.gd`
    (DEMOLISH-A/B/C), `test_settlement_demolition_admit.gd` (3 stranded-claim tests),
    `test_construction_paid_ledger.gd` (6-cell buffer), `test_settlement_system.gd` (1).
- **Mutation testing: 58 mutants** over `construction.gd`, `settlement_system.gd`, `inventory.gd`
  and `demolition_admissions.gd`, each in a cloned tree against the focused suites. **55 killed**
  (two first survivors -- the charge column cleared at release, the main store's origin anchor --
  were killed by tests added for them). The three survivors: a dead write the mutant exposed
  (removed from the code), a probe setting the charge before a compile that resets it
  (equivalent), and a removal row reading the build bill columns (equivalent: its delivery bill
  count is 0; the columns now route through `is_furniture_subject()` anyway).
- **Independent `code-reviewer`, two passes.**
  - First: no CRITICAL. HIGH H1 (stale capacity audit): regenerated. HIGH H2 (#3b a no-op in the
    real colony): keyed on a shelf in a PANTRY room, recorded in item 4, starter test added.
    MEDIUM M1 (a piece removed around the coordinator stranded the row): the stranded door now
    recovers it, and the guard was corrected. M2/M3 (tests that could not fail, survivors):
    fixed. LOW L1-L5: fixed or recorded.
  - Second: no CRITICAL or HIGH. MEDIUM-1 (the guard did not re-record after the piece went, so
    nothing could recover): it now re-records on the standing building row, which the stranded door
    recovers, and the test asserts that recovery. MEDIUM-2 (two commit proofs unexercised): both
    tests added; their mutants are killed. LOW: the orphan-already-refunding branch tested, the
    redundant grams check commented as a guard, the wording updated, the stranded condition
    simplified, the store-door shelf case recorded above.

## Source

Brendan's 2026-10-02 rulings on decision 0535's P1–P3; DEMO-CONTAIN-R01 #3a, #3b, #6, #9 and the
furniture rule; BUILD-C4-R01; decision 0534's rulings R1, R2, R4, R5; R-BUILD-DOM-004; ADR 0186.
