# 0912 — The demo opens with a stocked pantry, and its threats come on the game calendar
Date: 2026-10-01 · Status: Accepted

Numbered 0912: the next number after the balance harness (0911). No record numbered 09xx existed on any branch or
worktree when this was written.

## The ruling

**Brendan, 2026-10-01**, approved experiments E1 and E7 from the first balance baseline
(`docs/balance/2026-10-01-first-year-baseline.md`, decision 0911). In the same ruling he approved E2, E3, E4 and E5,
and other lanes take those. These two are built here:

- **E1: the demo opens with a stocked pantry**: 40 U of wheat and 50 U of carrots, the stock the meal loop's
  acceptance runs (decisions 0381 and 0421) topped the kitchen up with.
- **E7: threats move to the game calendar**, about one every nine game days instead of a real-time schedule. The
  threat kinds and their handling stay as they are.

## What the baseline measured

- **E1.** The demo opened with an empty pantry, and its first crops were still growing. Nobody could eat until the
  first harvest (Spring 2 for the radish, Spring 8 for the wheat). Every day-0 meal was missed whatever the player
  did; hands-off missed 203 of 216 spring meals.
- **E7.** The flood and the fire came every 9 real minutes plus up to 2 (`demo_events.gd`, decision 0196). Since
  decision 0421 made a game day ten minutes, that was about one threat a game day: 45 in a 48-day year, in every run.
  Each one raised a critical incident and autopaused the village, about every 2.5 real minutes at 4x. Decision 0421
  left this open.

## Decision

### E1: the opening pantry (`demo/farm/opening_pantry.gd`)

- `ITEMS` / `MILLI`: wheat 40 000 and carrot 50 000 milli-U. That is four days of meals for nine residents
  (porridge takes 2 U a batch and soup 3 U, for two portions each).
- **Where:**
  - The stock goes into the covered store (location 0, 400 U), through the pantry's own `add_into`, as fresh lots.
  - It ages and spoils like any harvest: carrots 240 h, wheat 720 h.
  - Nothing is forced. A row the store has no room for is left out, and the returned milli-U say so.
- **Not a harvest.**
  - The pantry's stored ledger counts the stock, because it is a delivery like any other.
  - The farm's after-action record (decision 0451) is re-opened on its hour once the stock is in (`record.start`).
    So the opening day records nothing as harvested.
  - The balance harness binds after boot, so it does not count the stock as produced either.
- **When:** at boot, once. The village calls it at the end of `_build_kitchen`, after the farm and the kitchen are
  built and before the clock first moves.
- **Why not in `demo_farm.gd` or the pantry files.** The farm suites build `DemoFarm` by hand and expect an empty
  pantry. The cellar lane is editing the pantry files, and the crops lane is editing `demo_farm.gd`. So the data and
  its one function are a new file, and the village gains two lines: a preload and the call.

### E7: threats on the calendar (`demo/events/demo_events.gd`)

- **The schedule is in game days**:
  - `FIRST_AUTO_DAYS` 6, `AUTO_EVERY_DAYS` 9 and `AUTO_JITTER_DAYS` 2. These are the old 6, 9 and 2 minutes, each now
    a game day.
  - They become demo microseconds through `demo_calendar.gd DAY_USEC`: `FIRST_AUTO_USEC`, `AUTO_EVERY_USEC` and
    `AUTO_JITTER_USEC` keep their names and their one consumer.
  - The calendar counts that same demo time 1:1 (decision 0421), so a threat comes N game days on. Pause, 1x, 2x and
    4x move the threats and the calendar together.
- **Timing:**
  - The first threat comes on Spring 7 (day 6, measured from the 06:00 opening). That is 60 real minutes at 1x and 15
    at 4x.
  - Each later one comes 9 days plus a seeded jitter under 2 days after the last one ended (the countdown waits while a threat is under way).
  - A 48-day year meets five threats (tested), where it met 45.
- **Unchanged:**
  - the seeded kinds (flood, fire, flood, flood, ...);
  - a threat's 40 s of demo time;
  - the evacuation;
  - the incidents and the autopause;
  - the Lab's "Test event", which still brings the next one at once.
- **Not moved by a calendar jump.** The Lab's "Next weather" runs the calendar ahead without demo time, so it does not
  bring a threat sooner. The schedule follows the demo time the village actually lives through.

## Tests

- `test/test_demo_opening_pantry.gd`:
  - the stock, its location, its freshness and its ledger;
  - the record not counting it as harvested;
  - a store without room;
  - **the real village opening with it**, run in its own process (`test/live/opening_pantry_probe.gd`). The probe
    checks the pantry, the kitchen's Ready food and the record's open-day snapshot.
- `test/test_demo_tunnel_ext.gd`:
  - the first threat after exactly six game days;
  - the next one 9 days plus the seeded jitter;
  - every gap between 9 and 11 days across 20 ordinals;
  - five threats in a 48-day year.
- **Mutation testing.** The mutants were hand-written against these changes and run against the two suites. The
  results are under Verification.

## Consequences

- Shared files touched:
  - `godot/demo/demo_village.gd`: a preload and one call in `_build_kitchen`, plus its docstring.
  - `godot/demo/events/demo_events.gd`: the schedule's constants and the header.
  - `godot/test/test_demo_tunnel_ext.gd`: the two schedule tests updated, and one added.
- The baseline in `docs/balance/` measured the old opening and schedule. The year matrix is to be rerun after the
  dish and crop lanes merge (the coordinator's ruling), and is not rerun here.
- The demo's guide and README say nothing about the threat schedule's period, so no text was changed. The README's
  Threats line describes kinds and handling, which are unchanged.

## The review (code-reviewer, 2026-10-01)

No CRITICAL or HIGH finding. Fixed:
- the opening stock is four days of meals (72 portions), not about five; the probe now pins Ready food at 4000;
- the schedule test drives the real module (trigger, run the threat out, check the next gap) and pins the five start
  hours of a 48-day year, instead of re-deriving the formula;
- the probe exits 1 on a missing part, the test passes `--quit-after` and fails on a `SCRIPT ERROR`;
- the village reports an opening stock that came up short (`push_error`);
- the gap is counted from a threat's end, and the header says "game days of demo time".
Left: the jitter's modulo bias (a mean of about 0.91 days, not 1.0; seeded and deterministic) -- changing it would
re-pin the schedule.

## Verification

- **The affected suites (2026-10-01), every one with 0 failures.** Load was high, so these were run in place of the
  full suite:

  | Suite | Assertions |
  |---|---|
  | `test_demo_opening_pantry` | 16 |
  | `test_demo_tunnel_ext` | 1314 |
  | `test_demo_tunnel_ext_world` | 459 |
  | `test_demo_news` | 234 |
  | `test_weir_sluice` | 194 |
  | `test_demo_planner` | 247 |
  | `test_demo_build` | 224 |
  | `test_demo_prewarm` | 34 |
  | `test_balance_harness` | 88 |
  | `test_demo_session_live` | 94 |
  | `test_demo_planner_live` | 78 |
  | `test_demo_input_live` | 380 |
  | `test_demo_layout_live` | 624 |
  | `test_demo_people_live` | 72 |
  | `test_demo_routes_live` | 76 |
  | `test_demo_guide_live` | 106 |

  The live suites boot the real village, which now opens stocked.
- **13 mutants, all killed.** They covered:
  - the opening stock's amounts, item and location;
  - the record's re-opening, removed;
  - the refusal check, removed;
  - the village's call, removed, and the call made without the record;
  - each of the three schedule day counts, off by one;
  - each day-to-microsecond conversion, done in hours.
