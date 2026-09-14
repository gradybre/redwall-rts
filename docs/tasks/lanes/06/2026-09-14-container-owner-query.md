# 2026-09-14 — the container owner query, and a demolition gate that refuses

Task: 06_buildings_rooms_logistics.md (06.2)
Date: 2026-09-14
Ruling: [INV-GOODS-R01](../../../rulings/2026-09-14_cycle02_construction_goods.md)
Decision: [0145](../../../decisions/0145-the-owner-scan-proves-ownership-and-the-demolition-gate-refuses-containment.md)

`inventory.gd` now publishes `containers_by_owner_into()`: a bounded, read-only,
two-pass scan over the existing container rows, writing complete
inventory-container pairs in ascending slot order into a buffer the caller owns.
`owner_query_cells()` publishes the largest result the store can produce. No
reverse index is saved, no revision counter is added, and no row is touched — a
refusal and a successful scan both leave `state_bytes()` byte-identical.

`settlement_system.gd::request_demolition()` is REQ-SET-128's composed gate, in
the one place `buildings()`, `construction()` and `inventory()` meet over a
single directory. Five ordered stages: subject, endpoint proof, goods, occupant
recheck, footprint coverage. **It changes no state on any path and never calls
`open_demolition()`.**

**It refuses every time, and that is the finding, not a gap in the work.** A
container row carries no position and nothing maps a tile to a container, so the
owner scan proves OWNERSHIP and cannot prove CONTAINMENT; stage 5 therefore
refuses as `MISSING_CONTAINMENT_CONTRACT` even for a spotless building. Stages 2
to 4 run first, so a stranded lot, an outstanding capacity claim, an occupant or
a furniture user is still reported with its exact count and its exact lot refs.

**What this proves.** Goods keyed to the building, to any of its rooms, to any
furniture in those rooms, to any project of those subjects, and goods in a
project's `material_container` however it is owned — including a container
another entity owns entirely, reached by handle and de-duplicated by slot.

**What it does NOT prove.** Anything physically inside the footprint that no
binding names: a ground pile, another entity's cart, a container placed by a
system with no directory link to this building. Closing that needs a
footprint/placement binding from its owner, and the relocation half is the
separate containment/evacuation integration.

06.2 stays unchecked. The tier-2 demolition basis is untouched and still uses
the base §4.1 row at every tier.
