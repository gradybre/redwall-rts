# Destructive-edit endpoint contract (demolition)

**Status:** approved contract, 2026-10-01. Authority: [DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md)
(Brendan, [DEC-043](../setting_decisions.md)), recorded in
[decision 0531](../decisions/0531-demolition-containment-is-adopted-and-containers-carry-an-anchor-tile.md).
Owning queue entry: `CONSTRUCTION-EVACUATION-INTEGRATION`, which named this file.

This is a **summary** of the approved contract, written so an implementer of D2-D9 can find every
endpoint rule in one place. Where this page and the ruling differ, the ruling wins and this page
gets fixed. Nothing here adds a rule.

## 1. Who proves what

| Endpoint | Owner of the row | How it is located | Counts toward demolition |
|---|---|---|---|
| Building main store | Inventory (`inventory.gd`), owner = the Building directory ref | **Anchored explicitly** at the building's origin tile (#3a) | Yes. The owner scan and the tile scan must agree; a Building-owned container anchored off the footprint is a refusal |
| Pantry shelves | Not containers (#3b) | Each shelf adds 50000 g of capacity to the Building-owned pantry container | Removing a shelf refuses if remaining contents or reservations would exceed the reduced capacity |
| Project material container | Inventory, owner = the Project directory ref | Anchored at the subject's origin tile (building or furniture origin); created when the project opens (#3c) | Yes, and also validated through `material_container` against Inventory |
| Resident satchel | Inventory, owner = the resident | **Unplaced, anchor -1** (#3d) | No. The occupant gate covers it; the anchor is never written per tick |
| Expedition pack | Inventory | Unplaced, anchor -1 (#2) | No |
| Ground pile | Inventory, owner = the World ref, GROUND_PILE policy (#9) | Anchored at its tile; at most one pile per tile | Yes, if on the footprint; outside the footprint it **survives** and does not block (#5) |
| Ownerless (`NULL_REF`) container | Inventory, until INIT-C rebinds it (#7) | Unanchored: outside every footprint. **Anchored**: a refusal | Rebinding (D3) makes `NULL_REF` owners refusable at creation |

Inventory owns every container row and the anchor column (R-BUILD-DOM-004: no parallel container
store). Buildings never holds an Inventory ref. Only `settlement_system.gd` composes the stores
(decision 0145).

## 2. The anchor column (D1, landed)

* `inventory.gd::_c_anchor_tile`, I32, one per container row, beside the owner columns. One anchor
  per container; a tile may hold several containers (store, project, at most one pile) (#2).
* Domain: `-1` = unplaced, else `0..16383` (`z*128+x`, GDD §5.1; interiors use the same grid). The
  value is a *placement cell* so MOVE-G02's level encoding can later widen the meaning without
  widening the column (#4).
* Written by `create_container(..., anchor_tile = -1)` and `set_container_anchor(ref, tile)`, which
  refuse an out-of-domain tile (`INVALID_ANCHOR_TILE`) or a dead/stale container
  (`INVALID_CONTAINER`) before any write, and are journaled like every other container write.
* Read by `containers_anchored_in_into(tile_mask, out_pairs, out)`: a bounded cold-path scan, the
  same shape as `containers_by_owner_into()`. The caller owns a 16384-byte tile mask (nonzero =
  affected) and an output buffer sized by `owner_query_cells()`. Unplaced containers are never
  reported. A wrongly sized mask or an undersized buffer refuses without truncating. **No per-tick
  or per-frame caller.**
* Saved and hashed in section 7 (`inventory` owner schema 4, section schema 5). Older saves are
  refused, not migrated (FISH-ID-R01 precedent). Memory: 101376 x 4 = 405504 B.

## 3. Affected tiles (#5)

The **footprint only**, door tiles included: the exterior door sits on the footprint's perimeter
ring (GDD §5.9 door at interior x5; interior = footprint inset by one). Containers on outside access
tiles survive. `buildings.gd` has no exterior-door column, so the outside access tile used for
refund placement must be derived from the authored layout (D2/D5).

## 4. Ground piles (#9, D2)

`create_ground_pile(tile)` is the only door. Owner = World ref; GROUND_PILE policy; 400000 g
capacity; storage class 1500; one pile per tile; tile in bounds and passable. When full, spill to
neighbours breadth-first in N, E, S, W order, capped at 16384 tiles. Never on a DEMOLISHING,
destroyed or inaccessible footprint. An empty pile is reclaimed when the operation commits. Refunds
place lots by breadth-first search from the door's outside access tile, excluding the footprint.
An optional derived, unsaved tile→pile map (16384 x 4 = 65536 B) is approved with #9 and must be
ledgered if built.

## 5. Admission and completion (D4, D5)

* **Preview** is today's read-only gate. **Admit** runs in the same call with no yield once preview
  passes: snapshot tier and paid packages (BUILD-C4-R01), reserve output capacity, call
  `construction.open_demolition()`, advance the destination revision. Every check runs before the
  first write.
* **Completion** is one no-yield commit in `settlement_system.gd`: re-run the gate, validate every
  step, then mutate in this order: (1) destroy footprint containers owned by the building or project
  (`destroy_container` refuses a nonempty one); (2) remove furniture; (3) remove rooms;
  (4) `demolish_building`; (5) place the 50% return into capacity reserved at admission;
  (6) retire the project and advance the movement revision. The coordinator destroys
  building-owned containers, not Inventory or Buildings (#6).
* **Returns.** A building returns 50% of its recorded base package plus each completed paid upgrade,
  floored once per item (BUILD-C4-R01). **Furniture returns 50% of its own materials, not the intact
  item** (Brendan, 2026-10-01), never through the building's costs. Ground piles are the fallback
  destination.
* A refusal at any stage leaves Building, Construction, Inventory and directory bytes unchanged.

## 6. Evacuation, dispatch, movement (D6-D8)

Real HAUL jobs move goods first (no teleports); a persisted evacuate-then-demolish intent retries
admit once the sources are empty (D6, depends on task 06.4). DEMOLISH dispatch, the stranded-goods
notice listing exact lots and occupants (REQ-SET-128) and the pre-major-demolition quicksave
(REQ-SET-158) are D7. Topology and `destination_revision` advance on admit and removal, with
MOVE-TEST-05/10 retested (D8).

## 7. Acceptance

INV-GOODS-R01's full-gate test list still applies in full, plus: owner scan and tile scan agreeing
and disagreeing; an anchored `NULL_REF` container refusing; satchels excluded; a pile outside the
footprint surviving; furniture returning 50% of its materials; a tier-2 fixture per BUILD-C4-R01;
refusal immutability across all four stores. D9 runs the independent review and the visible Mac run.
