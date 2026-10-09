# 1736 — "Eaten raw: N days" beside Ready food
Date: 2026-10-07 · Status: Accepted

## The ruling

Brendan, 2026-10-07, on the balance rerun's P7 (decision 1731): **(a)**, show raw-edible stock beside Ready food. It is
shown beside it, not counted in it, so no rule changes.

The evidence: Ready food read 0.00 in all 36 measured seasons, with up to 161 U of berries, fruit, honey, jam and cheese
in store.

## Decision

- **The figure** (`godot/demo/kitchen/raw_reserve.gd`):
  - **What it counts.** Every raw-edible category (`meal_rules.gd RAW_NP_PER_U`) that no plain meal dish takes, so never
    a food Ready food counts. Its food nobody has set aside is taken at its raw NP.
  - **What it is divided by.** A day of the village's portions (`daily_portions()`, so 1732's portion and a half) at a
    plain portion's 1800 NP.
  - **Units.** Thousandths of a day, floored, as Ready food is.
- **Where it shows** (`ui/demo_hud_model.gd`):
  - on the ledger's food line, short: "Ready food: 4.5 days · raw 2.0 days".
    - The ledger keeps its eight lines at 296 px, a fixed size the settlement shell sets.
    - The first build, "Ready food: 4.5 days of meals · eaten raw: 2.0 days", wrapped at both sizes and pushed the Beds
      line out of the panel; the frames caught it.
    - The short form is 37 characters at worst, with both figures in double digits.
  - in the Ready food cell's tooltip: "Eaten raw: 2.0 days more (berries, fruit, honey, nuts, jam, cheese and other food
    eaten as it is)".
- **The cost.** The pantry keeps no revision to watch, and the figure is a pass over its lots per category. So the HUD
  reads it through `hourly_days_milli`, worked out at most once a game hour. It is in the model's `stamp()`, and the
  food cell repaints on a restamp (`demo_hud_counters.gd _stamped`).

## Tests

`test_demo_kitchen_ui.gd`:
- free berries and honey become NP over nine residents' day (401 thousandths);
- Ready food's own categories, and honey set aside, are left out;
- the hourly figure holds within the hour;
- with no kitchen the figure is 0;
- the ledger's and the tooltip's words.

The frames are in decision 1738.
