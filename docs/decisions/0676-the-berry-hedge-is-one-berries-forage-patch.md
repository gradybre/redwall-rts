# 0676 — The berry hedge is one §5.5 Berries patch: raspberry, blackberry and strawberry, picked in summer and autumn
Date: 2026-10-01 · Status: Accepted; the hedge's specifics are 0671's proposal 5

## Decision

- **The GDD has no planted soft-fruit row**: §5.6's orchard rows are trees, and the farm lane excluded strawberry for
  that reason (`farm_catalog.gd` EXCLUDED). Berries are §5.5's **Berries forage row**. So the east orchard's hedge is
  **one Berries patch**: capacity 300 U, opening at §5.1's 80%, regrowing each midnight by decision 0036's capped
  additive form at 120 per mille times the season (spring 0, summer 1000, autumn 400, winter 0), never picked below its
  sustainable floor (20%) or in a dormant season.
- **Its three bushes are its kinds**: the raspberry canes, the blackberry bramble and the strawberry bed share the
  patch's stock, and what a picking takes is the picked bush's own item ("a raspberry is a raspberry"). A picking takes
  5 U at §5.5's work (4 WU a U at FORAGE 0 and the danger band of land within 64 m of the hall) to the east orchard's
  baskets.
- The arithmetic is written in `orchard_rules.gd` from `scripts/core/forage.gd`'s table constants, not through the
  Forage store itself: the store's daily quota counter (`harvested_today_milli`) has no midnight reset yet, so a patch
  picked through it would stop for good once a day's quota was reached. **Reported**: that reset belongs to the
  settlement's midnight (ARCH-SYS-005), not to this lane.
- **No new bushes are planted**: no document gives a soft fruit's establishment time. Asking.

## Source

GDD §5.5 (the Berries row, the floors, "unavailable patches become dormant"), §5.1 (80% opening stock), decision 0036;
§5.7 (`berries`: 700 NP, 48 h).
