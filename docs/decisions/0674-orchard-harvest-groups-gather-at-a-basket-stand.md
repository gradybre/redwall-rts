# 0674 — Orchard harvest groups: a basket stand each, a destination, a nursery share and a timing
Date: 2026-10-01 · Status: Accepted (review ECO-010, group Y); the stand's numbers (0671's proposal 4) **approved as
built by Brendan on 2026-10-01**

## Decision

- **Two groups**: the old orchard (its two old trees' blocks) and the east orchard (its two planting sites and the
  hedge). Policy is **per group, never per tree** (ECO-010: "Recommend group-level policy rather
  than per-tree staffing").
- **A gathering point each: a basket stand**, which is a real pantry store (120 U, §5.8's covered-store factor) marked
  **staging** (`farm_storage.gd KEY_STAGING`): fruit picked there ages and shows in the Pantry like any lot, but no
  harvest or delivery from elsewhere ever chooses it (`farm_pantry.gd _best_location_into` passes it by). A harvest or
  a picking holds its room there first (`reserve_at_into`, room first: decision 0222) and is carried there.
- **Destination**: the Haulers carry the baskets on, 10 U a trip, to the **kitchen pantry** (the fresh table) or the
  **best keeping store** (a root cellar first). A haul **moves** the food (`move_upto_into`): its lot keeps its age
  (merged lots keep the older), and the ledger counts it once (stored at the stand, never again). It unloads where its
  room is **held**, read when it unloads (a store's index moves when a cellar is dug; the hold follows its store by
  id), and a move never lands at a gathering place.
- **Food at a stand is not yet stored**: the kitchen never reserves a stand's lots (`ingredient_takes.gd _staged`) and
  a hungry resident never eats one raw (`kitchen.gd _raw_candidate`, since §5.7's fruit and berries rows are raw-edible:
  0671's proposal 9), so a haul or the nursery can never take food out from under a planned meal.
- **The nursery's share**: a group keeps 0, 4 or 8 U of each fruit at its stand for propagation (the old orchard 4 U by
  default: one sapling's fruit).
- **Timing**: *as each ripens* (each tree picked when its window opens: apples Autumn 1, pears Autumn 3) or *all
  together* (the group's trees picked on the first day all may be -- the apple waits for the pear's Autumn 3 -- unless a
  window is closing). ECO-010's "concentrated festival abundance against manageable preserving labor".

## Why a staging store rather than a separate buffer

Fruit waiting under the trees is still food that ages; a store in the pantry keeps one spoilage and one ledger, and the
Pantry, the kitchen and the planner see it with no new readers. The two small pantry hooks are additive: no existing
store is staging, so nothing else changes.

## Not built

Carts; per-share percentages for fresh table / preserve / seedling (built as a destination and a unit share).

## Source

REVIEW.md ECO-010 (2426); GDD §5.8; decision 0222; BAL-CAT-010's haul payload work.
