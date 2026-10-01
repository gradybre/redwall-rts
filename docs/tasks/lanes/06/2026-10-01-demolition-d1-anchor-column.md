# 2026-10-01 — demolition D1: the ruling, the container anchor, section 7 v5

Task: 06_buildings_rooms_logistics.md (06.2)
Date: 2026-10-01
Ruling: [DEMO-CONTAIN-R01](../../../rulings/2026-10-01_demolition_containment.md) (Brendan, DEC-043)
Decision: [0531](../../../decisions/0531-demolition-containment-is-adopted-and-containers-carry-an-anchor-tile.md)
Contract: [destructive_edit_endpoint_contract.md](../../../planning/destructive_edit_endpoint_contract.md)

Brendan approved the demolition-containment answers 1-9, ruled that furniture removal returns 50%
of its materials rather than the intact item, and approved the full path. The ruling records all of
it verbatim and names steps D1-D9; `work_queue.json` carries them as `DEMOLITION-D1..D9`, and
`CONSTRUCTION-EVACUATION-INTEGRATION` now waits on D9.

D1 itself:

- `inventory.gd::_c_anchor_tile` (I32, unplaced = -1), written only by `create_container()`'s
  optional anchor and `set_container_anchor()`, both domain- and liveness-checked and journaled.
- `containers_anchored_in_into()`: the bounded cold-path placement query, the twin of
  `containers_by_owner_into()`; unplaced rows never reported, short masks and buffers refused.
- Section 7: `inventory` owner schema 4, section schema 5, ordinal 30 appended and hashed; older
  saves refused. Registry version 7, record 604, contract C174.
- ARCH §2.2 row 405504 B; live headroom 21190032 B; transactional peak 811037 B further over a gate
  it already failed.

**Not done here, by design:** `request_demolition()` stage 5 still refuses
`MISSING_CONTAINMENT_CONTRACT` (D4), no ground pile exists (D2), and nothing anchors the live
starter stores yet (D3). No checklist box in task 06 closes with D1.
