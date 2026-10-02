# 0676 — The berry hedge is one §5.5 Berries patch: raspberry, blackberry and strawberry, picked in summer and autumn
Date: 2026-10-01 · Status: Accepted; the hedge's specifics (0671's proposal 5) **approved as built by Brendan on
2026-10-01, with one change: every picking is the generic `berries` item**

## Decision

- **The GDD has no planted soft-fruit row**: §5.6's orchard rows are trees, and the farm lane excluded strawberry for
  that reason (`farm_catalog.gd` EXCLUDED). Berries are §5.5's **Berries forage row**. So the east orchard's hedge is
  **one Berries patch**: capacity 300 U, opening at §5.1's 80%, regrowing each midnight by decision 0036's capped
  additive form at 120 per mille times the season (spring 0, summer 1000, autumn 400, winter 0), never picked below its
  sustainable floor (20%) or in a dormant season.
- **Its three bushes share one stock and one item**: the raspberry canes, the blackberry bramble and the strawberry bed
  share the patch's stock, and every picking is the pantry's **one generic `berries` item** (§5.7 `berries`: 700 NP,
  48 h), the item the foraging lane defines under the same key (Brendan's ruling of 2026-10-01 on foraging's general
  items, applied to the hedge the same day; `orchard_rules.gd BERRY_ITEM`). The bush is still named in the panel and
  on the Work screen ("a basket of up to 5.0 U of raspberries, as berries"). As first built each bush gave its own item
  (`raspberry`, `blackberry`, `strawberry`); that was replaced before merge. A picking takes 5 U at §5.5's work (4 WU a U at FORAGE 0 and the danger band of land within 64 m of the hall) to the east orchard's
  baskets.
- The arithmetic is written in `orchard_rules.gd` from `scripts/core/forage.gd`'s table constants, not through the
  Forage store itself: the store's daily quota counter (`harvested_today_milli`) has no midnight reset yet, so a patch
  picked through it would stop for good once a day's quota was reached. **Reported**: that reset belongs to the
  settlement's midnight (ARCH-SYS-005), not to this lane.
- **No new bushes are planted**: no document gives a soft fruit's establishment time (approved as built).

## Source

GDD §5.5 (the Berries row, the floors, "unavailable patches become dormant"), §5.1 (80% opening stock), decision 0036;
§5.7 (`berries`: 700 NP, 48 h).
