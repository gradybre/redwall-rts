# 0532 — Ground piles are placed breadth-first and reclaimed at commit
Date: 2026-10-01 · Status: Accepted

Numbered 0532 because the brief asked for 0532–0539 and decision 0531 (D1) set the series. No
record numbered 0532 exists on any branch (`git log --all`) when this was written. Parallel
branches (PC-04 family stores, the demo integration, test hygiene) may also allocate in the 053x
range; `docs/validation/decision_numbers.py` will refuse a collision at merge.

## Decision

**Step D2 of [DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md) lands with this
record.** It implements:
- answer #9, the ground-pile rules Brendan approved on 2026-10-01 ([DEC-043](../setting_decisions.md));
- **Brendan's follow-up ruling of the same day**, recorded under DEC-043. It sets the refund start
  tiles for doorless structures and confirms the footprint reading. Items 7 and the first reading
  under Why carry it.

1. **`inventory.gd::create_ground_pile(tile)` is the only door that makes a pile.**
   - Owner: the World ref. Policy: `POLICY_GROUND_PILE`. Capacity: 400000 g. Filters: every
     category. Reachable. Anchored at `tile`.
   - The anchor can never move: `set_container_anchor()` refuses `GROUND_PILE_ANCHOR_FIXED`.
   - `create_container()` refuses the pile policy (`GROUND_PILE_POLICY_RESERVED`). A row that
     carries it is therefore always a pile.
   - Creation is refused outside an explicit transaction (`GROUND_PILE_NEEDS_TRANSACTION`). On its
     own, a new pile would be empty when its own commit ran, and that commit would reclaim it
     (item 4).
2. **The container policy domain gets its first authored member: `POLICY_GROUND_PILE = 1`.**
   - #9 names a "GROUND_PILE policy value", and no policy domain existed.
   - It is numbered explicitly so BAL-CAT-001's sorted-key compile can never move it.
   - 0 stays the `UNSET_POLICY` sentinel. Every other value stays opaque, as before.
   - No test or production caller used 1. `economy_system.gd` and every fixture use 0.
3. **One pile per tile is enforced through the optional derived tile → pile map** that #9 approved.
   - `_pile_at_tile`: 16384 × I32 = 65536 B. Each cell holds the container slot of the live pile
     on that tile, or -1.
   - It is **derived and never saved** (registry category 2). It is journaled per cell, so a
     rollback restores it with the rows.
   - `audit()` re-derives it and refuses a disagreement (`AUDIT_GROUND_PILE_MAP`).
   - `restore_canonical_columns()` checks the projection before adopting anything. It refuses an
     unplaced pile, two piles on one tile, a capacity other than 400000 and a malformed owner.
     Then `_rebuild_derived_state()` rebuilds the map.
   - `state_bytes()` includes the map, because rollback must restore it exactly.
4. **Empty piles are reclaimed at commit (ARCH-MEM-002).**
   - A transaction records each pile it created, took a lot out of, or changed the reserved mass
     of: 4096 × I32 = 16384 B of transaction scratch, bounded by the undo journal.
   - The successful commit retires every such pile left with no lot. This applies to an explicit
     `commit()` and to an implicit single operation alike.
   - A rolled-back transaction reclaims nothing.
   - **A commit that would leave a pile with no lot but an outstanding reserved mass is refused,**
     with `GROUND_PILE_EMPTY_WITH_CLAIM`, and rolled back. ARCH-MEM-002 forbids the lotless row,
     and `destroy_container()` refuses to drop a capacity claim, so that state has no legal end.
     Refusing it is the only answer that neither keeps an illegal row nor silently unclaims
     headroom; releasing the claim in the same transaction lets the pile go. The review asked for
     this (H2): the first version kept such a pile, which no rule allows.
   - `audit()` refuses a lotless pile at rest, and restore refuses one in a save.
5. **The world rules are asked of a bound site authority, `godot/scripts/core/ground_piles.gd`.**
   - Inventory holds no map, so it cannot check them itself. The authority is held weakly and
     guarded by `_attesting`, the same pattern as the equipment and seed-expiry authorities.
   - An unbound authority refuses `NO_GROUND_PILE_AUTHORITY`. A released one refuses
     `INVALID_GROUND_PILE_AUTHORITY`. Both fail closed.
   - A tile is admitted only when every rule below holds, checked in this order:
     1. It is in `0..16383`.
     2. A live World row is bound.
     3. It is not in the operation's destroyed-footprint mask.
     4. It is on no live building footprint. A DEMOLISHING footprint refuses by that name; every
        other live footprint refuses `GROUND_PILE_ON_INACCESSIBLE_FOOTPRINT`.
     5. It is passable: GDD §5.1 walkable terrain, plus every one of its 16 navigation cells
        walkable when a `SpatialWorld` is bound.
6. **`ground_piles.gd::place_lots_into_piles(start_tile, excluded_mask, specs, out)`** is the helper
   D4/D5 refunds and D6 hauling call.
   - `specs` is 7 × int64 per lot: item, quantity_milli, quality, provenance, recipe, age and age
     remainder.
   - Tiles are visited breadth-first from `start_tile`, expanding N, E, S, W.
     - **N is -Z**: the hall's south door runs +Z in `starter_structures.gd`.
     - Expansion goes only through tiles that pass the site rule.
     - At most 16384 tiles are visited.
   - Each visited tile fills its existing pile, or creates one, before the goods spill on.
   - A lot is split across piles at `floor(free_g * 1000 / mass_g)`. That is the largest quantity
     whose per-lot ceiling charge still fits.
   - The whole call is **one inventory transaction**. Any refusal rolls every pile and lot back,
     byte for byte. That includes running out of reachable capacity, which is the explicit
     `GROUND_PILE_NO_CAPACITY`.
   - After the commit, every new pile on a visited tile is declared `STORAGE_OPEN_PILE`. That is
     §5.8's factor 1500, the approved "storage class 1500".
   - `preflight_lots_into_piles()` runs the same placement and always rolls it back.
7. **`refund_seeds_into(building_ref, mask, out_seeds, out)` derives where a refund starts.** It
   implements #9 and DEC-043's follow-up. It also marks the building's footprint in the caller's
   mask, and must be called before the building is removed.
   - **A building with an authored door starts outside it.** `buildings.gd` stores no door, so the
     only authored one is GDD §5.9's hall at rotation 0. Its outside tile is the exterior exit
     `starter_structures.gd` resolves, minus the starter hall's origin: (+6, +10). A door that
     would fall off the grid refuses `GROUND_PILE_DOOR_OFF_GRID`.
   - **Every other building starts from the ring of tiles touching its footprint, nearest to its
     front first.** That covers wells, workbenches, stockpiles, and a hall at any rotation but 0,
     whose door position no layout authors. The choices DEC-043 asked to be recorded:
     - **Front.** No building type defines a front, so it is the rotation-0 south side (+Z, the
       hall's door side) turned a quarter clockwise per rotation step. That is the sense
       UI-SET-056's "Rotate placement 90 degrees clockwise" gives, seen from above with north (−Z)
       up: rotation 0 faces S, 1 W, 2 N, 3 E. `buildings.gd` itself names no rotation sense.
     - **Touching** is edge-sharing. The four diagonal corner tiles are not in the ring; they are
       reached as the spill's first step.
     - **Nearest** is Manhattan distance, in half tiles, to the centre of the front side's ring
       segment. Ties go to the lower tile index. Ring tiles off the grid are omitted.
   - The caller's seed buffer must hold `REFUND_SEED_CAPACITY` = 2 × (128 + 128) = 512 cells, the
     largest edge ring any rectangle on the grid can have.
   - `place_lots_from_seeds()` and `preflight_lots_from_seeds()` run the placement as one
     breadth-first walk seeded with every eligible start tile in that order. Ineligible seeds are
     skipped; when none is eligible, the first seed's own refusal is returned.
   - The `GROUND_PILE_DOOR_NOT_AUTHORED` refusal of the first version is gone.
8. **Save (section 7): no schema bump.**
   - A pile is an ordinary container, and every fact about it travels in an existing column:
     `policy`, `owner_slot`/`owner_generation`, `max_mass_g` and decision 0531's `anchor_tile`.
   - The tile map is derived, so it is never written.
   - Section 7 stays at schema 5, inventory owner schema 4. The registry stays at version 7, with no
     new record and no new contract.
   - Verified by a capture → encode → decode → publish → capture round trip, byte-identical, in
     `test_ground_piles.gd`.
9. **Memory**: four new ARCH §2.3 rows, +167940 B in total.
   - The tile map: 65536 B.
   - The reclaim candidates: 16384 B.
   - The spill scratch: `_visited` + `_queue`, 16384 × 5 = 81920 B.
   - The refund-ring sort keys plus one start tile: 512 × 8 + 4 = 4100 B.
   - The planned payload goes from 70421360 to **70589300**, and the live total from 78809968 to
     **78977908**.
   - Live headroom is **21022092 B**.
   - The rejected two-world transactional peak is a further 335880 B worse, now **−43322011**.
     Nothing offsets it, and ARCH-MEM-006's conclusion does not change.

## Why — the executor's readings, stated so they can be overruled

- **"Inaccessible footprint" means any standing building's footprint. Brendan confirmed this
  reading on 2026-10-01 (DEC-043).** A ground pile never sits on any standing footprint, and a
  DEMOLISHING one refuses by its own name. The executor had proposed the reading because nothing
  proves a footprint tile accessible: `buildings.gd` has no door or access column, and the spatial
  contact schema leaves "which side of a building offers one" to the contact owner.

- **"Destroyed footprint" is the operation's own caller-supplied mask.**
  - In D5's commit order the building is removed (step 4) before its return is placed (step 5).
    By then the footprint is no longer in `buildings.gd`, and only the mask still knows it.
  - `refund_seeds_into()` fills that mask before the removal.
  - It is the same 16384-byte caller buffer D4 must build for `containers_anchored_in_into()`, so
    D4 and D5 need one mask, not two.

- **The site authority lives in a new module, not in Inventory.** Answer #1 and R-BUILD-DOM-004 keep
  Inventory free of a world map, and decision 0531 kept it free of a `buildings.gd` dependency.
  Inventory still publishes the single door and enforces every rule it can see.

- **Storage class is declared by the composer after the commit, not inside the door.** It is
  `stock_age.gd`'s fact. More importantly, a pile rolled back inside a transaction returns its slot
  to the free stack *with the same generation*. A declaration made before the commit would then be
  inherited by an unrelated container. Once the placement has committed, the answer is `ok`
  whatever the declaration does. A failed declaration, unreachable while every visited pile holds a
  lot, sets the `GROUND_PILE_STORAGE_CLASS_REFUSED` flag on a successful result, because a caller
  retrying a "refused" refund would place it twice (review M1). A pile made directly through
  Inventory's door is never declared; making StockAge treat `POLICY_GROUND_PILE` rows as open piles
  by themselves is the cleaner long-term fix and is left to D6, which is the next caller.

- **Reclaim uses a candidate list, not a 16384-cell scan per commit.** The first version scanned the
  whole map on every commit that touched a pile. The 16384-tile cap test commits 33 batches of
  500 piles; at that size the scan makes every hauling commit pay for the whole map.

- **A rotated hall does not rotate its door.** The coordinator allowed rotating the hall's authored
  door offset if that were purely geometric. It is not: `buildings.gd` swaps extents for odd
  rotations but names no rotation sense or pivot, so a rotated door's position would be a choice.
  Under DEC-043's follow-up the rotated hall is simply a building without an authored door, and the
  ring rule (whose rotation sense is recorded above) covers it.

- **Rejected alternatives:**
  - Letting `create_container()` mint piles. A second door could skip every #9 rule.
  - Keeping a lotless pile that carries a reservation. That was the first version's behaviour, and
    neither #9 nor ARCH-MEM-002 allows it.
  - Saving the tile map. It would be a second source of truth that can disagree with the rows.
  - A free-standing `ground_piles` store with its own container rows. R-BUILD-DOM-004 forbids a
    parallel container store.
  - Guessing a door for doorless buildings. The ruling's exclusions say an unimplementable rule
    refuses and asks.

## Consequences

- **The World directory row does not exist in production.** No code calls
  `directory.create(KIND_WORLD)`; only tests do.
  - `ground_piles.gd::bind_world()` refuses anything but a live `KIND_WORLD` ref.
  - Until the composer owner creates that row and binds it, every pile request refuses.
  - **D3 (or whoever composes the settlement) must create the World row**, then:
    1. construct `ground_piles.gd`;
    2. call `bind_stores(inventory, buildings, stock_age, spatial)` and `bind_world(world_ref)`;
    3. keep the composer alive for as long as the inventory, because Inventory holds it weakly.

  `settlement_system.gd` is deliberately not edited here.
- **D4/D5** should:
  - call `refund_seeds_into()` before `demolish_building()`;
  - pass the same mask and seeds to `place_lots_from_seeds()`;
  - call `preflight_lots_from_seeds()` in the validate-everything phase and
    `place_lots_from_seeds()` in the mutate phase.

  The placement helper refuses an already-open inventory transaction, because it owns its own.
  If D5 must put store destruction and the return in ONE inventory transaction, it has to add a
  variant that places inside the caller's open transaction and declares storage class after the
  caller's commit (review M2).
- **The helper only creates goods.** It places new lots, which is a conservation source, and that
  is right for a refund. D6's existing cargo (REQ-SET-110) must instead MOVE or split the carried
  lot into a pile, keeping its identity, reservations and gear row, so D6 extends the helper with a
  move variant rather than sinking and recreating (review M2).
- **A pile on a tile that later becomes illegal is not moved.** Nothing stops
  `buildings.place_building()` from covering a tile that holds a pile, and lots moved into an
  existing pile ref skip the site rule. Placement here never tops up such a pile, because the spill
  re-checks every tile, but D3 (building placement) or D8 must refuse a footprint over a live pile
  or evacuate it first (review M4).
- **D6 hauling** must go through the same helper (REQ-SET-110's "existing cargo ... in a visible
  temporary ground pile at the destination"). A pile created directly through Inventory is never
  declared storage class 1500.
- **Every hauling commit that empties a pile reclaims it.** That includes `stock_age.gd`'s
  waste-removal commit. A pile ref is therefore not stable across operations; re-read it by tile.
- `docs/planning/registry_capacity_audit.json` is regenerated, because `inventory.gd` changed.

## Evidence

- **Tests.** `test_inventory_ground_piles.gd` (29 tests) covers the door, its refusals, rollback,
  reclaim, the claimed-empty refusal, the audit and the restore rebuild. `test_ground_piles.gd`
  (35 tests) covers the site rule, the breadth-first order and the 16384-tile cap, the per-lot
  ceiling, all-or-nothing, preflight, the door and ring seeds for every rotation, and the save
  round trip.
- **Mutation testing**: 104 mutants over `inventory.gd` and `ground_piles.gd`, run against both
  suites.
  - **95 are killed.** Earlier passes left gaps that new tests now close: a slot reused by an
    ordinary container, the map in `state_bytes()`, `is_ground_pile()` against an opaque policy,
    the mask released after a commit, a pile on a now-illegal tile, the reclaimed slot's
    generation, a grid-clipped ring and a duplicated seed.
  - **The 9 survivors are equivalent:**
    - the reclaim call in `_leave_into()` (aging and transform never unlink or change a claim);
    - the reclaim's own reserved-mass test (a lotless claimed pile is refused before reclaim runs);
    - candidate clearing at begin and at rollback (a stale candidate is re-checked for liveness,
      policy and emptiness, and a pile at rest always holds a lot);
    - noting a pile when its claim changes (a claim change alone never empties a pile);
    - journaling the reclaim's free-stack push (the journal is discarded on the next line);
    - the `head < SPILL_TILE_CAP` loop bound (the grid has exactly 16384 tiles, so the queue ends
      there first);
    - the front-centre offset `extent + 1` versus `extent` (it differs only for 1 x N footprints
      with N >= 3, and the catalog has none);
    - the "already declared" skip (declaring a pile twice is idempotent).
- **Independent `code-reviewer` pass**:
  - **HIGH, both fixed:**
    - H1, the stale capacity-audit sidecar and the missing lane note. The sidecar is regenerated
      and the lane note is written.
    - H2, a lotless pile kept because it carried a claim. Item 4 now refuses such a commit, and
      audit and restore refuse the row.
  - **MEDIUM:**
    - M1, a post-commit declaration failure reported as a refusal. Fixed: it is now a flag on a
      successful result.
    - M3, the duplicated free-slot logic. Fixed: one body with a `journaled` flag.
    - M2 (an in-transaction variant and a move-existing-cargo variant) and M4 (a pile under a later
      building) are handed to D5, D6 and D3/D8 under Consequences.
  - **LOW:**
    - The passability wording is corrected.
    - The cap test is renamed.
    - The owner-slot restore clause is now tested.
    - The unreachable candidate-overflow fallback stays as a guard.
- **Suite and contracts:** quoted in the D2 lane note and the handover; every "Specification
  contracts" step in `.github/workflows/tests.yml` passes, with the capacity audit regenerated.

## Source

DEMO-CONTAIN-R01 #9 (Brendan, 2026-10-01, DEC-043); decision 0531 (D1); GDD §5.1, §5.8, §5.9,
REQ-SET-110, REQ-SET-127; ARCH-MEM-002, ARCH-MEM-006; INV-GOODS-R01; R-BUILD-DOM-004;
`starter_structures.gd` (INIT-C-PREP-R01v1).
