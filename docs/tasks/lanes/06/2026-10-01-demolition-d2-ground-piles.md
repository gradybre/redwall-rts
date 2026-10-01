# 2026-10-01 — demolition D2: ground piles

Task: 06_buildings_rooms_logistics.md (06.2, 06.4's spill half)
Date: 2026-10-01
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md) answer #9, and
Brendan's 2026-10-01 follow-up under [DEC-043](../../../setting_decisions.md)
Decision: [0532](../../../decisions/0532-ground-piles-are-placed-breadth-first-and-reclaimed-at-commit.md)

D2 implements answer #9 in full.

- **The door.** `inventory.gd::create_ground_pile(tile)` is the only door. Every pile it creates
  is:
  - owned by the World ref, with `POLICY_GROUND_PILE` = 1;
  - 400000 g;
  - fixed to its anchor tile;
  - one per tile, enforced by a derived, unsaved tile -> pile map.
- **Reclaim.** An empty pile is reclaimed at the successful commit that emptied it. A commit that
  would leave a pile with no lot but an outstanding claim is refused instead.
- **`ground_piles.gd`** is the site authority. It:
  - checks the site rule: in bounds, World bound, not destroyed, not on any standing footprint
    (DEMOLISHING by name), and passable;
  - places goods breadth-first N/E/S/W from one or more start tiles (16384-tile cap), all or
    nothing, and declares storage class 1500 after the commit;
  - derives the refund start tiles. That is the rotation-0 hall's door, or, for every other
    building, the edge ring nearest its front first.
- **No save schema change.** Section 7 stays 5, inventory owner schema 4, registry v7.

**Not done here, by design:**
- No production code creates the World directory row or wires the composer. That is D3's
  composition.
- D5 and D6 still have to extend the helper for in-transaction use and for moving existing cargo;
  decision 0532 lists both.

No checklist box in task 06 closes with D2.
