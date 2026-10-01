# 2026-10-01 — demolition D3: INIT-C live apply and the owned stores

Task: 06_buildings_rooms_logistics.md (06.2's starter build; INIT-C)
Date: 2026-10-01
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md) answers #3a, #3b,
#7 and blocker 6, plus decision 0532's World-row and M4 obligations
Decision: [0533](../../../decisions/0533-the-starter-colony-is-materialised-and-the-stores-are-owned-by-it.md)

- **The starter colony is real.** `starter_colony.gd` places `starter_structures.gd`'s plan
  through `buildings.gd`'s public doors: 7 ACTIVE buildings, the hall's 4 rooms and 31 floor
  furniture. It preflights everything first and re-reads every row against the plan afterwards.
  - Boot runs it inside `create_generated_settlement()`'s transaction, after the world, so the
    cohort keeps ids 1-12 and the world starts at 13.
  - Create runs it through `materialize_starter_colony()`.
- **The World row exists.** It is created with the colony. `ground_piles.gd` is composed in
  `_init()`, kept alive by the settlement and bound to the World row, so a pile request succeeds.
- **A footprint over a live pile is refused**, as `BUILDING_FOOTPRINT_OVER_GROUND_PILE`, through
  `buildings.gd`'s new weakly held placement authority.
- **The stores are owned.** EconomySystem opens nothing until it is bound:
  - the pantry belongs to the hall;
  - four 400000 g material stores belong to the four stockpiles;
  - each is anchored at its building's origin tile.
  `create_container()` now refuses an ownerless container. Deposits follow §5.9's fill order.
- **No save schema change.** The directory, section 1, section 4 and section 7 carry the colony as
  they are.

**Not done here, by design:** the eight partition and door edges, room validity, building
condition and bed assignment (0533 says why). Merging EconomySystem's inventory into the
settlement's is also left; **D4 must read 0533's Consequences first**, because the gate cannot
see the starter stores until that is done.

No checklist box in task 06 closes with D3.
