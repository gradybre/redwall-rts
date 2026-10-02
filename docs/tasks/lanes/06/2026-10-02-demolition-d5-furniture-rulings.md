# 2026-10-02 — demolition D5 follow-up: Brendan's furniture rulings

Task: 06_buildings_rooms_logistics.md (06.2's demolition; REQ-SET-127/128)
Date: 2026-10-02
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md)'s furniture
rule and #3b, as Brendan ruled on decision 0535's P1–P3
Decision: [0536](../../../decisions/0536-furniture-returns-half-by-type-and-pieces-are-removed-alone.md)

- **Furniture comes down with its building.** Each piece's package is derived from its type; it
  returns 50% of its bill (floored per piece, per item) and adds a quarter of its WU to the
  demolition's work. Admit reserves the combined return. The starter hall, once its pantry is
  empty, is demolished with its 4 rooms and 31 pieces.
- **A changed return refuses.** The admission records its return's charge (piles included); if
  furniture is placed or removed around the coordinator, the commit refuses
  `DEMOLITION_RESERVATION_MISMATCH` and stays commit-pending.
- **One piece can be taken out alone.** `preview_/request_/complete_/cancel_furniture_removal()`
  reuse D4's admit and D5's commit with the piece as subject; one admission per building.
- **#3b is live.** A shelf in a pantry room (valid or not yet) takes its 50000 g out of the building's main store,
  refusing when the contents and claims would no longer fit
  (`inventory.reduce_container_capacity()`).
- **Only the coordinator completes or cancels a removal.** `commit_completion()` and
  `close_refund()` refuse a demolition by name; the pinned DEMOLISH fixtures use the
  coordinator's doors.

**Readings confirmed by Brendan on 2026-10-02 as rulings R1–R8** (0536), among them: one admission per building; a piece's return never
goes to its own building's stores; a removal requires an ACTIVE building; the removal purpose sits
outside ADR 0186's frozen enum until CONSTRUCTION-SAVED-BINDINGS revisits it.

No checklist box in task 06 closes with this follow-up.
