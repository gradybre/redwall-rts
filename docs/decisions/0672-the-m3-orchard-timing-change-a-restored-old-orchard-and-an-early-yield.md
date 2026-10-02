# 0672 — The M3 orchard timing change: a restored old orchard at the start, and a fifth of a crop from a tree's first year
Date: 2026-10-01 · Status: Accepted (the direction: Brendan, group Y, 2026-09-30); the numbers are PROPOSALS (0671's 1–2)

Group Y's approval (decision 0493) reads: *"Approved; the M3 orchard timing change to be recorded as a decision."* This
is that record.

## The problem it answers

GDD §5.10's milestone table opens orchards at **M3 Deep Roots** (population 80, year 2, 8 food-days), with "2 apple + 2
pear saplings once", and §5.6 gives apple 96 days and pear 144 days to maturity, an immature tree yielding 0. The
review (REVIEW.md 2053; gameplay_balance.md BAL-CONFLICT-002 says the same) worked the arithmetic: a tree planted on
M3's earliest day bears its first fruit after the earliest year-3 Charter -- "long-investment fruit can arrive after the
earliest possible year-3 Charter eligibility". ECO-008's recommendation: keep long-lived mature trees, do **not** divide
maturity by ten; give "a staged orchard (sapling → blossom → small first yield of 15–25% of mature output)", and
"recommend the restoration option for the first scenario because it shows the payoff without accelerating every tree".

## Decision

1. **Maturity is unchanged.** Apple 96 days, pear 144 days, §5.6's full yield from then, REQ-SET-079/080 as written.
2. **An early yield.** A tree at least one full seasonal cycle old (48 days, §5.1's year) and not yet mature may be
   picked once a year in its species' window for **20%** of §5.6's yield at its health, pollination and chill
   (`orchard_rules.gd early_yield_milli`: the store's product, floored once). Its picking takes the same share of
   BAL-CAT-010's 80 WU. The year is marked picked (a tree maturing later in the same window is not picked again).
   An apple planted on Y1 Spring 1 bears early on Y2 Autumn 1 and fully from Y3 Autumn 1; a pear early on Y2 Autumn 3,
   fully from Y4 Autumn 3 -- each shown before the planting (REQ-SET-081's preview, with the early day first).
3. **The restoration start.** The first scenario (the demo) opens with an **inherited old orchard**: an old apple and
   an old pear, mature, neglected (35% health), which tending restores (+50 a tended spring/summer day) and neglect
   wears down (-100). Left untended until its first autumn the apple falls to 11% and gives under 9 U; tended every
   spring and summer day it rises to 47% and gives about 38 U -- the near-term reason to care for it; a new planting
   is the long-term goal.
4. **M3 in this scenario.** Because the old orchard supplies fruit from the first autumn, the bootstrap §5.6 guards
   against ("preventing a fruit/sapling bootstrap loop") is already broken by design: the nursery and orchard planting
   are open from the start, and **the M3 grant (2 apple + 2 pear saplings) is held in the nursery from the start**
   instead of arriving with M3. M3's other unlocks (boats, the boathouse, fruit recipes, the Orchard feast) are not
   touched. A scenario without an inherited orchard keeps §5.10's M3 row as written.

## Why

- It is the review's recommended direction, approved: payoff inside the main arc without making every tree fast.
- 20% is the middle of the review's own 15–25%; one year is its "after one full seasonal cycle".
- Holding the grant at the start (rather than adding saplings, or unlocking M3 early) changes the fewest numbers.

## Consequences

- **The GDD's text is to be amended** once Brendan confirms the numbers (0671's proposals 1–2): §5.6's sentence
  "Immature trees yield 0" gains "except decision 0672's early yield: from one year old, 20% once a year in the window",
  and §5.10's M3 row gains "(in a scenario that opens with an inherited orchard, the saplings and the nursery are held
  from the start)". Until then this record is the authority for the demo; the settlement's code
  (`scripts/core/orchard_hive.gd`) is unchanged and still yields 0 before maturity -- the early yield lives in the
  demo's model.
- Milestones are not evaluated in the demo (as decision 0603 notes for recipe unlocks), so nothing here gates on M3.
- SOC-031–034 (progression and difficulty) stay deferred (group AF); this decision does not re-plan the milestone ladder.

## Source

REVIEW.md ECO-008 (2380) and the M3 timing note (2053); gameplay_balance.md BAL-CONFLICT-002; GDD §5.6, §5.10 (M3);
group Y's approval in decision 0493.
