# 1738 — The tuning measured: the staged matrix after 1732–1737, the P6 fishing run, and P9's threshold
Date: 2026-10-07 · Status: Accepted (measurement and harness only; no game number is changed here)

## What this records

Brendan's rulings of 2026-10-07 on the balance rerun's proposals (decision 1731) asked for:
- P6: "measure first", rerunning the provisioning player with `FISH_STOCK_HIGH` at 12 U;
- P9 (a): `hungry_max_pct` kept at 5%, marked unattainable until P1 has been measured;
- a short follow-up in the report: did hunger, winter, the cordial and the peas move?

## Decision

- **The harness flag.** `balance_run.gd` takes `--fish-high U`: the scripted player's fresh-fish line over which it
  authorises no trip (`light_touch_policy.gd fish_stock_high`, default `FISH_STOCK_HIGH` 4 U).
  - It is refused for `hands_off`, which does not fish, and for a non-integer.
  - The run's meta records it (`fish_stock_high_milli`).
  - The argument checks moved to `_check_args`, which keeps `_read_args` to 30 lines.
- **P9.** `tools/balance_thresholds.json` keeps `hungry_max_pct` at 5%. Its reason now says it is unattainable until P1 is
  measured, and P1 is now measured (below).
- **The measurement.** The staged matrix (3 seeds × 3 policies, and hands-off for 2 years) was rerun on this branch, and
  provisioning was run at `--fish-high 12` (3 seeds). It is in the report's follow-up section
  (`docs/balance/2026-10-07-year-matrix-rerun.md`, "Follow-up: after the tuning"), with the runs' summaries and CSVs
  beside it.

## What it found (staged, nine residents; before → after, on `7a8279d3`)

Every measured year sums to 864 meals. An earlier P6 run summed 866, because the tally counted a diner holding its second
helping twice; that was fixed before these runs (decision 1732).

- **Hunger barely moved: P1 is supply-limited.**
  - HUNGRY share of hours: light-touch 87% → 84%, provisioning 86–88% → 83%, hands-off 88–89% → 86–87%.
  - Missed meals are flat: light-touch 29–30% → 29–33%, provisioning 25–27% → 24–26%. The kitchen serves the portion and
    a half (portions eaten 378–388 → 407–417 under light-touch), so the same food runs out sooner.
  - Hands-off rarely has food for seconds (portions 128–129 → 127–130).
- **Winter did not improve.** Light-touch 126–149 → 134–160 of 216 missed; provisioning 85–88 → 68–93; hands-off still
  97–100%.
- **The cordial now works.** Made 36–76 U; spoiled 0–6 U, where all of it spoiled before; 32–51 U poured at suppers.
- **The peas moved a little.** 0 → 6–10 U eaten a year under the players; still 0 hands-off. About 33 U are still in
  store at year's end. Roots are the hotpot's limit now: the village grows about 50 U of roots a year, and the soups
  take them first.
- **P6, fishing to 12 U** (provisioning):
  - **It feeds the table, a little.** 16–53 U more fish a year (3–7 more trips); 203–221 meals missed instead of 210–225.
  - **It feeds no rack.** Dry fish is still refused NO_FISH on 47 of 48 mornings, and rations are never made: the
    kitchen reserves every fish for its next two days of meals.
  - **So the limit is the reservation, not the catch.** Options for Brendan are in the report (F3).

## Frames (decisions 1733, 1734 and 1736)

`test/live/demo_food_live.gd` now checks, at 1280×720 and 1920×1080 with the art staged (`LIVE-SUMMARY 49 0` at both):
- the Brew mead card's note and the order's warned answer;
- the cordial card ("keeps 240 h", "poured at supper") and the table drink bound;
- the ledger's "raw" line, the ledger keeping its eight lines and fitting the window, and the food tooltip.

Frames looked at: `brew_warning_*`, `ready_food_ledger_*` (session scratchpad `tune_frames/`).

## Gates

The branch's gates are recorded in the PR and in decisions 1732–1737.
