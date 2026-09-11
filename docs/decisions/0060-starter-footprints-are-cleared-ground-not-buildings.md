# 0060 — The starter footprints are cleared GROUND, and the 1695-node fixture is retired for a derivation that happens to equal it
Date: 2026-09-11 · Status: **Accepted** ·
Implements [READY_07 §7.1](../rulings/2026-09-11_ready07_open_item_answers.md) ·
Depends on decisions [0029](0029-deposits-are-sixteen-nodes.md),
[0048](0048-world-generation-anchors-and-what-it-refuses-to-invent.md)

## Decision

`world_init.gd` now clears GDD §5.9's seven authored starter building footprints
and GDD §5.1's one-tile apron around them, alongside the loam rectangle it
already cleared, **before** it places any resource node.

1. **The footprints are transcribed, not derived.** §5.9: "place the hall at
   (58,59), stockpiles at (50,60),(50,65),(70,60),(70,65), well at (64,54), and
   workbench at (58,54), all rotation 0. Clear these footprints before resource
   placement." The extents come from §5.9's own building table — refuge hall
   **12×10**, open stockpile **4×4**, well **2×2**, workbench shelter **3×3**.
2. **The first table number is the X extent, proved rather than assumed.** §5.9
   gives the hall "Interior 10×8" and "Hall interior origin is exterior
   origin+(1,1)". 12−2=10 across and 10−2=8 down is the only reading that
   closes, and §5.9's interior ASCII block is ten columns by eight rows.
   `_assert_authored_constants()` guards it.
3. **Clearing is idempotent and the three parts may overlap.** The workbench and
   well aprons reach z=53 inside the loam rectangle; fourteen apron tiles belong
   to two footprints at once. READY_07 §7.1 permits that ("Shared aprons may
   overlap as cleared ground"), and the mask is a boolean, so an overlap is
   cleared exactly once.
4. **No authored footprint overlaps another.** All 21 distinct pairs are
   disjoint, asserted in production (`_assert_footprints_dont_overlap()`) and in
   the suite against an independent transcription of §5.9.
5. **The order is executed, not restated.** `_stage_masks()` writes the cleared
   column and `_stage_tree_plan()` **reads** it. Swapping the two stages is a
   mutation the suite kills.

**No Building, Furniture or Room store is created here.** Clearing ground is
geometry; the stores are READY_07 §7.2 step 2 and belong to another increment.
Nothing in this module knows that the hall footprint will one day hold a hall.

## The recalculated census: 1695, retired as a fixture and re-derived

READY_07 §7.1 warned that this "legitimately changes the incomplete 1695-node
generator fixture/hashes" and forbade protecting the old count by leaving trees
inside the well, workbench or apron. **The count was recalculated from the
geometry and comes back to 1695.** That is arithmetic, not protection, and the
reason is asserted rather than asserted-away:

| Term | Before | After | Why |
|---|---:|---:|---|
| Tree centres (§5.1 even x / even z, forest masks) | 1571 | **1571** | Unchanged |
| Guaranteed grove | 100 | **100** | §5.1: "until exactly 100 guaranteed nodes exist" |
| Centres replaced by the two ore footprints | −8 | **−8** | Decision 0029 |
| Ore nodes (two 4×4 deposits) | +32 | **+32** | Decision 0029 |
| **Total** | 1695 | **1695** | |

The centre count does not move because the cleared building ground touches a
forest mask in exactly **one column, x=49**, for eleven tiles (z=59..69) — the
west mask ends at x=49 and the nearest footprint starts at x=50. A tree centre
needs **even** x, and 49 is odd, so not one centre is cleared. The loam
rectangle (x=58..65) lies in no forest mask at all and never did.

The **composition** did change, and that is the part the old fixture was hiding:

* Five grove tiles at **(49,59)…(49,63)** now fall inside the (50,60)
  stockpile's apron. 25 grove tiles were already duplicate centres, so **70 of
  the 100 now land inside §5.1's grove rectangle and 30 relocate**, where it was
  75/25.
* §5.1's replacement window x=36..49, z=50..67 supplies the five extra in
  ascending tile order, extending the tail from **(43,52)** to **(37,53)**. The
  first 25 replacements are unchanged: the clearing lengthens the tail, it does
  not reorder it.
* The cleared census is **376 tiles** = 197 footprint + 122 apron ring + 57 loam
  rectangle tiles no apron already takes. All 376 are LOAM.

So the fixture value is retired; the suite now derives the count on every run
from `_qualifying_centres()` and §5.1's grove rule and asserts it equals 1695,
with a named test for the odd-column reason. Decision 0048's published figure of
"1695 resource nodes" and `docs/tasks/04_world_commands.md`'s remain correct and
were **not** edited to preserve them — they were rechecked.

## Why a survivor is recorded instead of a contrivance

Mutation testing (38 mutants, one per run, byte-compared after each restore)
killed 37. The survivor is `_is_tree_centre()` passing a literal `false` for
`cleared`: on the authored map that line can never change an outcome, for the
odd-column reason above. Rather than declare it equivalent, two tests were
added: the rule itself is exercised directly through the pure
`is_centre_candidate(x, z, cleared)` with both values, and
`test_the_clearing_takes_no_tree_centre_because_its_forest_overlap_is_odd`
asserts over all 16384 tiles that the clearing meets a forest mask only at x=49.
The survivor is therefore a **proved-unreachable** branch, not an untested one,
and it is recorded in the function's docstring.

The two duplicated grove gates were merged into one `_is_plantable_tile()` for
the same reason: the replacement pass's copy of the cleared check was
unreachable on the authored map (the scan supplies its 30 tiles from rows
z=50..53 and never reaches the cleared x=49 at z≥59), so one shared gate is both
DRY and fully exercised.

## What §5.9 left unstated and was not invented

* **No rotation column.** §5.9 says "all rotation 0"; a column with one value is
  not stored. Rotation belongs to the building store, which is §7.2 step 2.
* **The renewable bedrock access at (48,70)** still has no quantity, period or
  footprint anywhere and is left as constants, exactly as decision 0048 left it.
* **No Building/Furniture/Room store, no 12-resident fixture, no containers.**

## Consequences

* `is_cleared_tile()` is now the union of three parts and is no longer a synonym
  for the loam rectangle. Callers wanting only the rectangle must use
  `is_cleared_loam_tile()`; `test_cleared_loam_rectangle_boundaries` was updated
  to say so and to assert that (60,54) — the workbench's own footprint — changed
  answer.
* A future footprint moved into a forest mask will silently start removing tree
  centres and change the census. The derivation in the suite will move with it;
  the fixture would not have.
* No new storage: the cleared mask is the existing `PackedByteArray` column, and
  the footprint roster is compile-time constants. The ARCH-MEM-009 ledger is
  untouched by this increment.

## Source

GDD §5.9 line 671 and its building-catalog table; GDD §5.1's "Clear initial
building footprints, a one-tile apron, and the loam rectangle x=58..65,z=46..53
before placing resource nodes"; READY_07 §7.1.
