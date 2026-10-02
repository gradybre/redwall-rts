# 2026-10-02 — demolition D5: the composed completion

*Superseded in part the same day by
[the furniture-rulings follow-up](2026-10-02-demolition-d5-furniture-rulings.md) (decision 0536):
furniture no longer refuses.*

Task: 06_buildings_rooms_logistics.md (06.2's demolition; REQ-SET-127/128)
Date: 2026-10-02
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md) answer #6, the
furniture rule, #3b and blocker 2
Decision: [0535](../../../decisions/0535-demolition-completion-is-one-commit-and-furniture-refuses.md)

- **A demolition can finish.** `complete_demolition()` commits a finished, admitted demolition
  in one call. It proves everything first: the coordinator's own project with its work done and
  its claim held, the gate's stages 2–5 again, the furniture rule, and that the return can be
  placed now. Then, in #6's order, it destroys every affected container, removes the rooms and
  the building, places the 50% return and retires the project.
- **One inventory transaction** holds the destroyed stores, the released claim and the return.
  The admission record is released (destination revision +1) before the building row goes.
- **The return lands for real**: as one lot per item in the store whose claim admit took, or on
  ground piles from the door or the front ring through `ground_piles.gd`'s new in-transaction
  variant, declared storage class 1500 after the commit.
- **A refusal writes nothing** and leaves the project commit-pending; a retry costs nothing.
- **Furniture refuses.** No store records a piece's paid package, so under the ruling's own line
  any furniture refuses (`DEMOLITION_FURNITURE_PAID_PACKAGE_UNREADABLE`), in the preview (so before
  admit) and at the commit. The starter hall therefore cannot be demolished yet; its 31 pieces are named.
- **#3b** reduces to stage 3's emptiness proof inside a whole-building demolition: the pantry
  container is destroyed at step (1).

**Waiting on Brendan:** 0535's P1 (where a piece's paid package comes from; recommended: derive
it from the type, as ruling R4 does for buildings) P2 (a single-piece removal door, where #3b's live
case belongs) and P3 (closing the store-level completion door, which orphans a demolished
building's containers and claim if called around the coordinator).

**Not done here, by design:** hauling and the work under BUILD (D6), dispatch, the notice and the
quicksave (D7), movement consumption of the revision and the freed footprint (D8).

No checklist box in task 06 closes with D5.
