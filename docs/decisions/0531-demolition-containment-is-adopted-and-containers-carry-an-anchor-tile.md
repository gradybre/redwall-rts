# 0531 — Demolition containment is adopted, and containers carry an anchor tile
Date: 2026-10-01 · Status: Accepted

Numbered 0531 because the brief asked for 0531–0539. No record numbered 0520–0599 exists on any
branch (`git log --all`) or in any sibling worktree.

## Decision

**Brendan approved the demolition-containment proposal on 2026-10-01**
([DEC-043](../setting_decisions.md)). The ruling that records it verbatim is
[DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md):

- answers 1–9 approved as recommended, including the new ground-pile rules in #9;
- furniture removal returns 50% of its materials (the same rule as buildings), not the intact item;
- the full path is approved, planned as steps D1–D9 (the ruling's table, and `DEMOLITION-D1..D9`
  in `docs/planning/work_queue.json`).

The endpoint contract that `CONSTRUCTION-EVACUATION-INTEGRATION` named is written:
[`destructive_edit_endpoint_contract.md`](../planning/destructive_edit_endpoint_contract.md).

**Step D1 lands with this record.** It covers answers #1, #2, #4 and #8.

1. **`inventory.gd` gains `_c_anchor_tile`**, one I32 per container row beside the owner columns.
   - `UNPLACED_TILE` = -1 means the container sits on no tile. Satchels and expedition packs use
     it, and so does every row nobody places.
   - Otherwise the value is a placement cell in `0..ANCHOR_TILE_COUNT-1`, which is 16384 cells,
     GDD §5.1's `z*128+x`.
   - Inventory writes 16384 itself rather than preloading `buildings.gd`. A test pins it to
     `buildings.gd`'s `TILE_COUNT`.
2. **Only two doors write it.**
   - `create_container(..., anchor_tile = UNPLACED_TILE)`. The anchor is optional, so the 47
     existing calls (production and tests) are unchanged.
   - `set_container_anchor(ref, tile)`.
   - Both refuse before writing anything. A tile outside the domain refuses
     `INVALID_ANCHOR_TILE`. A dead or stale container refuses `INVALID_CONTAINER`.
   - Both are journaled, so a poisoned transaction restores the anchor byte for byte.
   - They check the **domain** and not the world. Whether a tile is passable, on a footprint or
     already holds a pile is for D2 and D4 to decide, because Inventory holds no map.
3. **One bounded cold-path query reads it:** `containers_anchored_in_into(tile_mask, out_pairs,
   out)`.
   - It is the same two-pass shape as `containers_by_owner_into()`.
   - The caller owns a mask of exactly `anchor_query_mask_bytes()` = 16384 bytes. Any nonzero byte
     marks an affected cell.
   - The output buffer is sized by `owner_query_cells()`.
   - Unplaced rows are never reported, and retired rows are skipped.
   - A mask of the wrong size refuses `ANCHOR_MASK_SHAPE`. An undersized buffer refuses
     `OWNER_OUTPUT_TOO_SMALL` and writes nothing.
   - Nothing calls it per tick or per frame.
   - The plain reader `container_anchor_tile()` answers -1 for both "unplaced" and "no such
     container". `container_anchor_tile_into()` tells the two apart.
4. **Checks.** `audit()` refuses an out-of-domain anchor on a live row (`AUDIT_ANCHOR_OUT_OF_RANGE`).
   `state_bytes()` includes the column.
5. **Section 7 changes (answer #8).**
   - The `inventory` owner schema goes from 3 to **4** and the section schema from 4 to **5**.
   - `_c_anchor_tile` is **appended** as ordinal 30, so ordinals 0..29 keep their wire positions.
   - The field is hashed, and it is registered in REG-R01 as record 604, source contract C174.
     The registry version goes from 6 to 7.
   - The canonical projection copies live anchors exactly and writes -1 for an inactive row.
   - The decoder and the store's restore both refuse a live anchor outside -1..16383 and an
     inactive anchor other than -1.
   - **Schema 3 owner bodies and schema 4 section descriptors are refused, not migrated.** This
     follows the FISH-ID-R01 precedent.
6. **Memory (answer #8).**
   - The new ARCH §2.2 row is "InventoryContainer anchor_tile I32 ×101376 = 405504 B".
   - The §15 declaration table grows by 29 B: 15 B of fixed metadata plus 14 key bytes.
   - The planned payload goes from 70015827 to **70421360**, and the live total from 78404435 to
     **78809968**.
   - **Live headroom falls from 21595565 to 21190032 B.** It still fits.
   - **The transactional peak was already 42175094 B over the gate and is now 42986131 B over.**
     That is 811037 B worse, because the column is mutable world state and a second resident world
     would carry it too. ARCH-MEM-006 already rejects the two-resident-world design, so the
     conclusion does not change. Nothing offsets the increase.
   - **Cold-path save/load scratch also grows,** by up to three more 405504 B copies while a save
     or load is in progress: the section 7 `Record` column (its ledgered size is now 11250208 B),
     the caller's `CanonicalColumns` projection, and the `.duplicate()` that
     `restore_canonical_columns()` adopts. None is resident between saves, and like the rest of
     that codec scratch none has a §2.3 row; that pre-existing ledger gap is unchanged here.
7. **Stage 5 is unchanged.** `request_demolition()` still refuses `MISSING_CONTAINMENT_CONTRACT`.
   Giving it the success path is D4.

## Why

Answer #1 placed the anchor in Inventory for two reasons:
- R-BUILD-DOM-004 makes Inventory the only container owner and forbids a parallel store.
- A tile map in `buildings.gd` would hold Inventory refs that Buildings cannot validate.

Answer #2 chose container→tile over tile→container. A reverse map can hold one container per
tile, but a store, a project container and a pile can share one tile. The test fixture puts two
containers on one tile for exactly that reason.

**Rejected alternatives:**
- **A per-container setter that only validates the world.** Inventory has no map, so any world
  check here would be a guess. Domain and liveness are the store's to prove; placement legality
  belongs to the composer.
- **Migrating schema 3 saves by defaulting every anchor to -1.** Ruling #8 orders refusal, and
  FISH-ID-R01 set the precedent that an old-layout body is never reinterpreted. Today such a
  default would lose nothing, since no pre-0531 code could anchor a container; the refusal is the
  format rule, not a rescue of data.
- **A level column now.** Answer #4 defers levels to MOVE-G02. The anchor is a placement *cell*,
  so a later encoding can widen its meaning without widening the column.

## Consequences

- **D2 inherits the following:**
  - The anchor column and its two write doors.
  - The query.
  - `UNPLACED_TILE`.
  - The fact that Inventory does not check passability or one-pile-per-tile. D2's
    `create_ground_pile()` must do both. If it wants the optional derived tile→pile map
    (65536 B, approved with #9), it must also ledger that map.
- **D3** must anchor the hall pantry and the four stockpile stores at their buildings' origin
  tiles when it rebinds them.
- **D4** must read placement through `container_anchor_tile_into()` or the query, never the
  plain `container_anchor_tile()`, which answers -1 ("unplaced", i.e. off every footprint) for a
  stale ref.
- **D4** reads the query against a footprint mask. That mask is a new caller-owned 16384-byte
  buffer, and it must be ledgered beside decision 0145's demolition scratch.
- **Old development saves no longer load.** Section 7 schema 4 and inventory owner schema 3 are
  both refused.
- **`docs/planning/registry_capacity_audit.json` was regenerated.** The sidecar records the source
  hash and line numbers of every module it audits, and `inventory.gd` changed.

## Evidence

- **Mutation testing**: 41 mutants, run against `test_inventory_anchor.gd` and
  `test_save_section_inventories.gd`. 32 were in `inventory.gd` and 9 in the section 7 codec.
  - 40 are killed.
  - The first pass left four alive. Three of them were real test gaps, and the tests that close
    them were added:
    - `clear()` refilling the column;
    - the query writing the reused slot's current generation;
    - the plain reader on a stale ref of a reused slot.
  - **The one survivor is equivalent.** It removes the liveness test from
    `_canonical_live_anchor_refusal()`. An inactive row must already hold -1 by the time that
    check runs, because the inactive-payload check runs first, so the guard never changes an
    outcome.
- **Independent `code-reviewer` pass**: no CRITICAL or HIGH findings.
  - **MEDIUM findings, all fixed:**
    - a slot-reuse test;
    - the plain reader documented as diagnostic-only, with D4 pointed at `_into`;
    - the stated reason for refusing old saves corrected (above);
    - the D1 queue entry now lists every file it edits;
    - the cold-path scratch growth stated (above).
  - **LOW findings, fixed:**
    - the stale stage-5 docstring in `settlement_system.gd`;
    - the anchor's own refusal wording in the codec;
    - a vacuous literal-arithmetic assertion removed;
    - a hand-added wire offset for ordinal 30;
    - a test for anchors above int32;
    - the committed `.uid`.

## Source

DEMO-CONTAIN-R01 (Brendan, 2026-10-01, DEC-043); INV-GOODS-R01; decision 0145; decision 0511 §1;
R-BUILD-DOM-004; BUILD-C4-R01; FISH-ID-R01 and decision 0167; ARCH-MEM-002, ARCH-MEM-006,
ARCH-SAVE-007; GDD §5.1 and §5.9.
