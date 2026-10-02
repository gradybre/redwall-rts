# 0535 — Demolition completion is one commit, and every piece of furniture refuses
Date: 2026-10-02 · Status: Accepted (the proposals below await Brendan)

Numbered 0535 because the brief named it. No record numbered 0535–0539 exists on any branch
(`git ls-tree` over every ref), in any registered worktree or in the main checkout when this was
written; `docs/validation/decision_numbers.py` passes and refuses a collision at merge.

## Decision

**Step D5 of [DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md) lands with this
record.** It covers answer #6, the furniture rule, answer #3b and blocker 2, and every item of
[decision 0534](0534-demolition-admit-and-the-adopted-inventory.md)'s "What D5 must know".

1. **`settlement_system.gd::complete_demolition(building_ref)` is #6's one no-yield commit.** It
   returns the same `DemolitionReport` as the gate. It proves everything, writing nothing, then
   mutates in #6's order.
   - **Stage 1's commit-time variant.** The building is live; it carries a project and
     `demolition_admissions.project_of()` names that same project (else
     `DEMOLITION_NOT_ADMITTED`: a store-level `open_demolition()` is not the coordinator's);
     `construction.demolition_commit_refusal()` proves a live DEMOLITION row in
     `PHASE_WORK_DONE` whose building stands (its codes re-raised: `WRONG_PHASE` before the work
     is done); and cancellation's claim proof (`_claim_release_refusal()`): no caller
     transaction, the store still holding the recorded grams, the record releasable.
   - **Stages 2–5 again** (`_gate_stages_refusal()`, now shared with `preview_demolition()`).
     The commit's own project is simply one more endpoint: it has no material container and
     nothing delivered, so the walk passes it, exactly as 0534 foresaw. Goods, claims,
     occupants, furniture users, foreign or ownerless containers on the footprint that appeared
     after admission all refuse by their D4 names.
   - **The furniture rule** (item 3).
   - **The return, proved placeable now.** The manifest is read from the project's own snapshot
     (`construction.demolition_return_into()`, new: the halved, once-floored lines in one call).
     A store return first requires the recorded grams to equal the snapshot's own charge
     (`DEMOLITION_RESERVATION_MISMATCH` otherwise; review L5), then is proved by releasing those
     grams and creating every lot inside a transaction that is then aborted; a ground-pile return by #9's rolled-back
     `preflight_lots_from_seeds()` from the refund seeds stage 5 just rebuilt. Either failing is
     `DEMOLITION_NO_OUTPUT_CAPACITY`, and the demolition stays commit-pending (0534's R2).
2. **The writes, in #6's order.**
   - One inventory transaction opens. **(1)** A fourth stage of the one endpoint walk,
     `ENDPOINT_STAGE_DESTROY`, destroys every container keyed to the building, its rooms, its
     furniture and their projects, and each project's material container by handle (skipped when
     its owner visit already destroyed it). Stages 3 and 5 proved each one empty, unclaimed and on
     the footprint. The output claim is released (`release_container_mass()`, exactly
     `unreleased_reserved_g_of()`), and then **`demolition_admissions.release()`** clears the
     record and advances the destination revision — while the building row still exists, as 0534
     requires.
   - **(2)** No furniture remains: every piece refused at the proof (item 3). **(3)** Every room is
     removed (`buildings.remove_room()`). **(4)** `construction.remove_demolished_building()`
     (new) unlinks and removes the building and keeps the project row.
   - **(5)** The return is placed INSIDE the same transaction: one lot per line into the released
     claim's store, or `ground_piles.place_lots_from_seeds_in_transaction()` (new, item 4) from the
     refund seeds, excluding the footprint mask built before the row went. The transaction
     commits; the new piles are then declared storage class 1500.
   - **(6)** `construction.retire_demolition()` (new) retires the row, refusing by name
     (`DEMOLITION_SUBJECT_STILL_STANDING`) while its building stands.
   - The report gains `destroyed_container_count`, `removed_room_count`, `returned_lot_count`,
     the project, the store and the grams released, and the revision after release.
   - **Only the proofs and the first block can refuse cleanly** (the block aborts the
     transaction and releases the record last), so only they leave the demolition
     commit-pending at no cost. Every later refusal is a guard the proofs make unreachable:
     `_abandon_commit()` aborts Inventory, re-records the admission while the building still
     stands, zeroes the report's counters, re-reads the revision and logs. Before the building
     row goes, that restores the stores and the claim's grams and keeps the demolition reachable
     by `cancel_demolition()` or a retry (tested by calling the guard directly, for a store and a
     pile return). After the row is gone, or after the commit, it cannot: removed rooms and the
     building stay removed (Buildings has no transaction), a refused `commit()` leaves the claim
     with no row to release it from, and a refused `retire_demolition()` leaves a live project
     with no subject. Those three cases are unreachable today and are stated, not handled
     (reviews M2, L-d).
3. **The furniture rule refuses every piece: `DEMOLITION_FURNITURE_PAID_PACKAGE_UNREADABLE`.**
   - Brendan's rule: a removed piece returns 50% of ITS recorded paid package. The ruling's
     executor's reading, which the brief told D5 to follow exactly: "If D5 finds the furniture
     build record does not carry a paid package to read, it refuses rather than repricing from
     the current catalog".
   - **D5 finds none.** The only record of a piece's package is its FURNITURE project's
     ConstructionPaidLedger row, and `_retire()` clears it when the project completes. INIT-C's
     31 starter pieces were placed with no project at all. A piece whose project is still live is
     under construction, not completed capital: BUILD-C4-R01 settles in-progress work through its
     cancellation contract first. No other store (Buildings' furniture row, section 1) carries a
     package.
   - So **any furniture in the building refuses**, before *admit* (the rule says the piece's
     return goes "to capacity reserved at admission", and admit cannot compute it) and again at
     the commit (a piece placed after admission). The check runs at the end of
     `preview_demolition()`, which `request_demolition()` runs first, so a preview that passes is
     one admit can act on (review M3); admit itself does not repeat it. The report counts every piece
     (`unpaid_furniture_count`) and names the first the walk reaches (`blocking_furniture`).
   - The starter hall, once its pantry is emptied, refuses for all 31 pieces
     (`test_the_emptied_starter_hall_still_refuses_for_its_31_pieces`). Rooms without furniture are
     removed normally.
   - The executor's other reading — the removal work is a quarter of the piece's construction WU
     — is **not confirmed**: no document states it, and nothing computes a piece's return, so
     nothing needs it yet.
4. **`ground_piles.gd`'s in-transaction variant (0532's M2 for D5).**
   `place_lots_from_seeds_in_transaction()` runs the same breadth-first placement inside the
   caller's open transaction and refuses `GROUND_PILE_TRANSACTION_NOT_OPEN` without one; on a
   refusal the caller aborts. `declare_placed_piles()` declares storage class 1500 after the
   caller's commit, never before, for 0532's slot-generation reason. The shared validation is now
   `_placement_refusal()`; the standalone helpers are unchanged.
5. **#3b inside a whole-building demolition reduces to stage 3.** The pantry container belongs to
   the building (D3) and is destroyed at step (1), after stage 3 proved it holds no lot and no
   claim; with every shelf gone the reduced capacity is 0, and 0 contents fit it. The rule's
   live case — removing a shelf from a STANDING pantry — needs a furniture-removal door, which the
   furniture rule refuses for every piece today, so no recompute code is written (it would be
   unreachable). It lands with Brendan's answer to P1.

## Proposals for Brendan

- **P1 — where a piece's paid package comes from** (the furniture rule is unimplementable as
  written: no piece carries one). Options:
  - (a) **Derive it from the piece's type at admission, exactly as ruling R4 does for buildings**:
    every standing piece's §4.3 bill counts as paid, starter pieces included. D5's commit would
    then remove each piece (step 2) and add 50% of its bill, floored once per item, to the return
    the admission reserves; whether the work grows by a quarter of the piece's WU is the second
    half of the question.
  - (b) **Record it**: a per-piece `furniture_paid_type` I32 × 81920 = 327680 B column, written
    when a FURNITURE project completes; INIT-C's pieces need a ruling of their own (paid or
    not). It needs a memory ledger row and a save owner (BUILDINGS-SAVED-BINDINGS).
  - (c) **Keep refusing**: a building with furniture can never be demolished.
  - **Recommendation: (a)**, because it is R4's reasoning applied to the same arithmetic and makes
    the hall demolishable; (b) is the long-term record if a piece's cost can ever differ from its
    type's bill.
- **P3 — close the store-level completion door.** `construction.commit_completion()` (and
  `close_refund()`, 0534) can retire a coordinator-admitted demolition around the coordinator,
  orphaning its containers and claim (see Why). Options: (a) make both refuse a DEMOLITION row by
  name and route the store-level path through `remove_demolished_building()` /
  `retire_demolition()`, updating the DEMOLISH retired-history fixtures; (b) leave them and rely
  on callers. Recommendation (a), before D6 wires work completion.
- **P2 — who removes a single piece.** #3b's shelf-capacity refusal and the furniture rule's
  standalone case need a coordinator furniture-removal door (dispatch has no arm for it). Options:
  (a) a D5 follow-up once P1 is answered; (b) fold it into D7's dispatch work. Recommendation (a).

## Why — the executor's readings, stated so they can be overruled

- **The record is released before step (4), so the revision advances there, not at (6).**
  Decision 0534 requires it: the record is keyed by the Building row, and nothing reaches it once
  no building stands there. #6's "(6) ... advance the movement revision" is therefore satisfied
  by that release inside the same call; the topology revision is D8's.
- **Step (1) destroys every affected endpoint's containers**, not only the building's and the
  project's: a room- or furniture-owned container left behind would name an owner the same call
  destroys. Stage 5 proved every such container is on the footprint, so the reading destroys
  nothing the ruling keeps.
- **The store return is proved, not assumed.** The claim makes a capacity failure impossible, but
  a lot-capacity limit or a restored filter can still refuse a lot, and a refusal at (5) would
  come after Buildings' unrecoverable writes. A rolled-back release-and-create proves it; failing,
  the store case stays commit-pending exactly like the pile case (0534's R2, applied to both).
- **`commit_completion()` is left as the store-level door, and its hazard is worse than a
  stranded claim** (review M1, reproduced). On a coordinator-admitted, room-less demolition it
  removes the building but destroys none of its containers and releases nothing: the claim stays
  reserved with no building on its row, and the building's own store survives, anchored on the
  freed footprint and owned by a destroyed building. A later building on that row can release the
  claim, but its own demolition then refuses `DEMOLITION_FOREIGN_CONTAINER_ON_FOOTPRINT` for good.
  Making the store door refuse a DEMOLITION would also rewrite construction's pinned
  retired-history fixtures (DEMOLISH-C in `test_construction_retired_histories.gd`), so it is
  P3 below, not done here. Every caller must use `complete_demolition()`.
- **No rule was reinterpreted.** The furniture rule refuses exactly where the ruling says to; the
  Alternative columns are untouched.

## Consequences — what D6, D7 and D8 must know

- **D6 (evacuation, work under BUILD).** Demolition work is `add_work_mwu()` on the admitted
  project; when it reaches `PHASE_WORK_DONE` call `complete_demolition()`, never
  `commit_completion()` or `close_refund()`: the store door orphans the building's containers on
  the freed footprint and strands the claim (P3). `DEMOLITION_NO_OUTPUT_CAPACITY` at the commit is
  commit-pending: retry later at no cost. Goods or claims that reappear refuse by name. Furniture
  is not hauled; it blocks admission until P1.
- **D7 (dispatch, notice, quicksave).** `preview_demolition()` and `request_demolition()` can now refuse
  `DEMOLITION_FURNITURE_PAID_PACKAGE_UNREADABLE` with `unpaid_furniture_count` and
  `blocking_furniture` for the notice. Completion is not a player command; the work owner calls
  it. REQ-SET-158's quicksave belongs before *admit*.
- **D8 (movement).** The destination revision advances at admit, at cancellation and at the
  commit's release — before the building row is removed. The footprint is freed by
  `demolish_building()` inside `_remove_structure()`; that is where the topology revision and the
  route re-check belong. The return's ground piles appear on tiles outside the footprint.
- **Open demolitions still do not survive a load** (CONSTRUCTION-SAVED-BINDINGS); nothing here
  is new state. `godot/scripts/systems` is outside the registry's coverage glob, and
  `construction.gd` and `ground_piles.gd` gain no column.
- **Memory: no change.** No packed array is allocated; the report gains five scalars. The
  furniture rule now runs on every preview and allocates through `rooms_of_building()` and
  `furniture_rows_in_room()`, as the D4 walk already does: fine for a command, but D7 must not
  run a preview every frame (for a hover, say) without a cheaper check. The
  capacity audit is regenerated because `construction.gd`'s lines moved.

## Evidence

- **Suite, CI-style** (a clone of the final tree with `godot/.godot` deleted, freshly imported, no
  `godot/demo/assets`), on the final tree: `7807 test(s), 575225 assertion(s), 0 failure(s)`;
  diagnostics `0 unexpected error(s), 0 unexpected warning(s), 271 expected, 353 tolerated;
  leaked at exit: 0 object(s), 0 resource(s)`. The run before the last review fixes reported one
  failure -- the D3 test the M3 fix broke, since corrected (`test_settlement_system.gd`).
- **Tests added or changed.**
  - `test_settlement_demolition_complete.gd` (24): the store and pile success paths, a hall with
    rooms and a room-owned store, tier 2, a dirt path's empty bill, a store sized exactly to the
    claim, a material container reached twice, the retry after success; every proof's refusal
    byte-identical (work not done, not admitted, stale, open transaction, claim short, goods,
    occupants, a foreign container, furniture at preview/admit and at the commit, a live furniture
    project, a pile fallback that no longer places, a store that no longer takes it, recorded
    grams one short and one over); the abandon guard for a store and a pile return.
  - `test_construction_demolition_completion.gd` (11): the commit proof writes nothing; steps 4
    and 6 and their refusals; `demolition_return_into()` against the line readers and the preview.
  - `test_ground_piles.gd` (+5): the in-transaction variant.
  - `test_settlement_starter_colony.gd` (+3, 1 changed): the real well completes into the fourth
    stockpile (wood 180 U -> 185 U), the workbench onto piles, the emptied hall refuses for its 31
    pieces; the D4 "hall reads as empty" test now ends at the furniture rule.
  - `test_settlement_system.gd` (1 changed): the same, for a hall with a bed.
- **Contracts.** Every "Specification contracts" step in `.github/workflows/tests.yml` (41
  scripts) passes on the tree, including `audit_registry_capacities.py --check` after
  regeneration, `test_construction_metadata_preflights.py` and `test_construction_allocation.py`.
- **Warnings.** `tools/gdscript_warnings.py` reports 0 on every changed file.
- **Mutation testing: 66 mutants**, each in a cloned tree against the focused suites
  (`test_settlement_demolition_complete`, `test_construction_demolition_completion`,
  `test_ground_piles`, `test_settlement_demolition_admit`, `test_settlement_starter_colony`,
  `test_construction`). **62 killed.** The four survivors are equivalent, all on paths the proofs
  make unreachable: the guard's abort in the first version of the commit (since replaced by
  `_abandon_commit()`, whose own five mutants are all killed), the store lot count on a refused
  lot creation, and `_open_commit()`'s counter reset on its abort (both reachable only if a proved
  write refuses), and the first version's missing re-record (killed once the guard got its tests).
- **Independent `code-reviewer`, two passes.**
  - First pass: no CRITICAL. HIGH H1, the stale capacity-audit sidecar: regenerated. MEDIUM, all
    addressed: M1 (the store-level `commit_completion()` orphans an admitted demolition's
    containers and claim, reproduced) recorded with its consequence and as P3; M2 (an unreachable
    guard after the record's release left an unreachable state, and the docs over-claimed)
    fixed by `_abandon_commit()` and qualified docstrings; M3 (preview passed what admit refused)
    fixed by moving the furniture rule into the preview. LOW, all fixed: L1 the first-piece
    assertion, L2 the hall's lot count, L3 the commit proof's "writes nothing", L4 stale counts,
    L5 the recorded-grams cross-check (`DEMOLITION_RESERVATION_MISMATCH`).
  - Second pass: no CRITICAL. HIGH H-A, the D3 test M3 broke: fixed and `test_settlement_system.gd`
    restored to D5's `owns`. MEDIUM M-A, `_abandon_commit()` untested: three tests added. LOW, all
    fixed: the re-record result is logged, the guard zeroes the counters and re-reads the revision,
    the mismatch is tested in both directions, this record's after-removal limits are stated, the
    preview's allocation is noted for D7, and unrelated re-encoding in `work_queue.json` dropped.

## Source

DEMO-CONTAIN-R01 #3b, #6, #9, the furniture rule and blocker 2 (Brendan, 2026-10-01, DEC-043);
decision 0534's rulings R1–R5 and Consequences; decision 0532's M2; BUILD-C4-R01; INV-GOODS-R01;
REQ-SET-127/128; ECON-003.
