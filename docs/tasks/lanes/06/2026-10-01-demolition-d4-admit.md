# 2026-10-01 — demolition D4: the gate's success path and *admit*

Task: 06_buildings_rooms_logistics.md (06.2's demolition gate; REQ-SET-127/128)
Date: 2026-10-01
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md) answers #3a,
#3c, #3d, #5, #7 and blockers 1 and 3; BUILD-C4-R01's tier-2 basis
Decision: [0534](../../../decisions/0534-demolition-admit-and-the-adopted-inventory.md)

- **The gate can say yes.** Stage 5 marks the footprint and requires the owner scan and the tile
  scan to agree. An affected container off the footprint, a foreign container on it, or an
  anchored ownerless one refuses by name; a ground pile on it is counted as goods.
- **Preview and admit.** `preview_demolition()` is the read-only gate. `request_demolition()`
  runs it and then *admit*, which proves every write before making one: it reserves the 50%
  return's capacity in one surviving store (or proves ground piles can take it), publishes the
  demolition project, and advances the building's destination revision.
- **BUILD-C4-R01 is implemented.** `construction.gd`'s ConstructionPaidLedger columns record each
  project's paid package keys. A demolition snapshots the base package and, at tier 2, the
  completed upgrade, then totals each item and floors the 50% once.
- **One inventory.** EconomySystem adopts the settlement's inventory before the starter stores
  open, so the gate sees the pantry and the stockpiles. The hall and stockpiles now refuse with
  their goods; the well and workbench are admitted.
- **Create during a demolition** works: the session declares KIND_CONSTRUCTION as cleared.
- **Cancelling releases the claim first.** `cancel_demolition()` frees the reserved capacity
  before retiring the project; `release_stranded_reservation()` frees a claim whose project was
  retired around the coordinator.

**Not done here, by design:** removing the building and placing the return (D5), hauling (D6),
dispatch and UI (D7), movement consumption of the revision (D8). Five proposals in 0534 await a
ruling. **D5 must read 0534's Consequences first.**

No checklist box in task 06 closes with D4.
