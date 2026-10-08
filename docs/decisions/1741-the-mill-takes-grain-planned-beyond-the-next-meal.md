# 1741 — The mill may take the grain the kitchen planned for meals beyond the next one
Date: 2026-10-08 · Status: Accepted

## The ruling

Brendan, 2026-10-08, on F6 (decision 1740's measurement; relayed by the coordinator): **"Push on: mill takes grain
too."** The mill, grinding flour, may take grain the kitchen has planned beyond the next meal, under the same rule as
the rack's fish under F5 (b) (decision 1739): never the next meal's grain, and never grain in the cook's hand.

**The evidence** (1740's first measurement). With the dried fish kept, rations were still never made, and Pack rations
read NO_FLOUR on all 48 mornings. A one-seed probe logged the mill at the 06:00 round on the 18 mornings that dried fish
and nuts were both free. Every one was refused NO_GRAIN: 1.1–1.6 U of grain nobody had set aside, against the 3 U a
batch takes. The year's one harvest goes to the porridge the kitchen plans two days ahead.

## Decision

- **The kitchen's machinery works by category** (`kitchen.gd`, THE RACK'S FISH AND THE MILL'S GRAIN; GRAIN FOR THE MILL):
  - `beyond_next_meal_milli(crop)` and `release_beyond_next_meal(milli, crop)`, with `crop` last so a station binds it
    (`.bind(crop)`);
  - `fish_beyond_next_meal_milli` and `release_fish_beyond_next_meal` now wrap them for fish, unchanged in behaviour;
  - the protections are 1739's and the same for both: the next meal (by the calendar), an occasion's meal, a meal
    cooked or at the cauldron, and food in the cook's hand. Food in store goes first, then food at the kitchen, each
    the latest meal's first.
- **The mill** (`fishery.gd`):
  - `bind_spare_grain(spare, give)`, the grain pair beside 1739's fish pair;
  - `grain_available_milli()`: the free grain plus the kitchen's beyond its next meal;
  - `mill_refusal` counts it, and its words name the kitchen's grain when bound;
  - `order_mill` first asks the kitchen for exactly what the free grain lacks (`_ask_kitchen`, now shared with the
    rack's fish). If the grain is still short, the order is refused NO_GRAIN and opens nothing;
  - the Mill grain card (`demo_fishery.gd mill_card`) counts the same grain.
- **The village** (`demo_village.gd`) binds the kitchen's two functions for `FarmingScript.CROP_GRAIN`.
- **The scripted provisioning player** needs no change. Its grind gate already asks `mill_refusal`, which now counts
  the kitchen's grain.
- **1740's keep reads it.** "Grain enough for a mill batch" counts the kitchen's grain beyond its next meal too.

## Tests

- `test_demo_kitchen.gd`, `test_the_mill_may_take_grain_only_beyond_the_next_meal`: at 03:00 the next meal is a
  porridge breakfast. Every later meal's grain is counted and given back, the next meal keeps its own, and fish counts
  0 there.
- `test_demo_preserve.gd`:
  - 1 U free and 2 U beyond the next meal make a mill batch; the kitchen is asked for exactly 2 U, and the batch holds
    3 U;
  - free grain enough asks nothing, and unbound counts the free grain only, with words that name no kitchen;
  - a kitchen that gives nothing back gets the order refused NO_GRAIN with nothing opened;
  - one milli-U short in all is refused NO_GRAIN, with the kitchen named and nothing asked.
- `test/live/demo_food_live.gd`: the built village binds the mill to the kitchen, and the Mill grain card counts the
  kitchen's grain.

- **Mutation:**
  - **Mine, 20 mutants on `b21acaf8`:**
    - the kitchen's category machinery (count, crop, store first, the kitchen pass);
    - the mill's count, ask, short give-back, refusal and card;
    - the village binding;
    - the regatta guard.

    All of these are killed. The rations' keep is reported in 1740.
  - **The reviewer's:** G01–G09 and L01 and L03 are killed. L02, the live grain pair bound to fish, survived, and
    `dab332ab`'s binding check kills it.

## Review

The independent `code-reviewer`'s re-review of `b21acaf8` (waited for) found nothing CRITICAL or HIGH here. It checked:
- the `.bind(CROP_GRAIN)` order;
- the `_ask_kitchen` sharing;
- that the refusal paths open no job;
- that the grain set aside after a give-back is the grain that spoils first.

It found one gap: the live check could pass with the grain pair bound to the wrong category. It is closed in
`dab332ab`.

## The measurement

Staged provisioning, 3 seeds, on `b21acaf8` (1740 and the report's follow-up section):
- **The mill never ran**, so the porridge kept all its grain (94–98 U withdrawn, as in every run).
  - The scripted player grinds only when dried fish and nuts are free together (1731's chain order).
  - Grain beyond the next meal is there only on days 12–14, after the harvest, and dried fish never was then.
- **In a probe the mill ran, and still no rations were made.** The probe (uncommitted) had the player grind whenever
  flour was not free.
  - It ran 4 batches a year, 12 U of flour.
  - The kitchen cooked all of it into hardtack, the biscuit soup, the pasty and the scones.
  - Rations still read NO_FLOUR, and missed meals rose to 226–245.
