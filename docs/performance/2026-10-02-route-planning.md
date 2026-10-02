# Route planning and the bursts, before and after — 2026-10-02

Brendan approved this work after the scale test ([2026-10-01](2026-10-01-scale-test.md), decision 0561): "route
planning + bursts" and "smaller fixes". The crowd rendering is deferred. What changed is in decisions
[1001](../decisions/1001-one-route-plan-is-local-and-divisible.md), [1002](../decisions/1002-one-field-per-shared-goal-guides-a-crowds-plans.md),
[1003](../decisions/1003-the-meal-call-and-dusk-send-eight-a-frame.md) and
[1004](../decisions/1004-neighbours-by-cell-pairs-by-bucket-and-an-index-that-does-not-grow.md).

**In short:**

- **50 and 100 now run.** The 4x clock no longer steps down: 29 and 427 step-downs before, none after. The CRITICAL
  stalls are gone.
- **The bursts are gone at 50.** Frame p95 is under 10 ms in every phase.
- **100 is close.** Frame p95 is 17–21 ms. At 100 the routing desk spends its whole 3.5 ms budget every frame, and the
  UI spikes.
- **256 runs.** Every phase's p95 is now 40–49 ms, down from 207–302 ms. What is left at 256 is the skeletal actors
  and the UI, not routing.
- **A plan's mean cost** at 50 residents fell from 19.8 ms to 0.7 ms. At 100 it fell from 36 ms to 1.8 ms.
- **No window spends a whole plan any more.** The largest routing window was 4.2 ms at 50, 6.8 ms at 100 and 8.2 ms at
  256, against a 3.5 ms budget. Before, one plan alone took up to 188 ms at 50 and 437 ms at 100.

## How this was measured

- **The scale harness** (`python3 tools/scale_test.py`, decision 0561): the same plan, phases and stocked pantry as the
  2026-10-01 note. Headless, uncapped at a fixed 60 Hz step, editor binary (debug GDScript), on the development Mac
  (Apple M5 Pro).
- **Interleaved.** For each N the base build (`origin/master` at d75d9d89, untouched) ran first, then this branch, one
  after the other, on the same machine within minutes. N = 9, 25, 50, 100, then 256.
- **The contention factor** (wall time over the run's own CPU time) was 1.01–1.03 for every run, before and after. The
  1-minute load average was 10–14 throughout, from other agents' work. The numbers are therefore comparable with each
  other, and much cleaner than the 2026-10-01 note's runs at 100 and 256 (contention 3.5 and 2.5 there).
- **Not REQ-SET-163.** As in that note, these are not a pass or fail against REQ-SET-163, which is defined on the
  qualification floor with a release build. Read them as before against after.
- **Waits for a route** are on the harness's 60 Hz virtual clock. A resident whose plan the desk carries over counts as
  waiting: the harness now reads the desk's job too.

Reproduce:

```
python3 tools/scale_test.py --out <dir> --residents 9 25 50 100 256      # this branch; the base: the same on origin/master
python3 tools/scale_test.py --out <dir> --tables-only --residents 9 25 50 100 256
```

## Frame work, p95 (ms), before → after

| N | 1x breakfast | 4x day | 1x supper | 4x evening | 1x dusk |
|---|---|---|---|---|---|
| 9 | 4.7 → **3.0** | 4.2 → **3.3** | 3.5 → **3.2** | 3.9 → **4.0** | 3.0 → **3.0** |
| 25 | 6.4 → **5.5** | 9.0 → **6.5** | 7.3 → **6.3** | 8.5 → **7.3** | 6.0 → **5.8** |
| 50 | 10.3 → **8.3** | 97.8 → **8.6** | 61.3 → **8.0** | 108.6 → **8.3** | 14.6 → **9.4** |
| 100 | 17.8 → **16.9** | 196.6 → **17.9** | 190.2 → **20.8** | 222.4 → **21.4** | 177.2 → **21.3** |
| 256 | 49.2 → **45.6** | 206.6 → **46.0** | 218.1 → **39.6** | 301.8 → **41.8** | 266.8 → **49.0** |

p50 / p99 (ms), before → after:

| N | 1x breakfast | 4x day | 1x supper | 4x evening | 1x dusk |
|---|---|---|---|---|---|
| 9 | 3.4 / 6.2 → 1.8 / 4.0 | 2.3 / 6.1 → 2.0 / 4.4 | 1.9 / 4.8 → 1.8 / 3.8 | 2.2 / 7.3 → 2.4 / 5.3 | 1.6 / 3.5 → 1.8 / 3.6 |
| 25 | 3.8 / 8.7 → 3.0 / 6.6 | 3.6 / 34.3 → 3.4 / 7.9 | 3.8 / 12.3 → 3.4 / 7.3 | 4.3 / 13.7 → 4.2 / 9.0 | 3.2 / 8.8 → 3.2 / 6.7 |
| 50 | 4.7 / 52.5 → 3.4 / 9.3 | 6.1 / 108.3 → 4.3 / 10.5 | 8.2 / 103.2 → 3.3 / 9.4 | 23.0 / 117.5 → 3.9 / 11.1 | 6.5 / 24.9 → 5.6 / 11.5 |
| 100 | 7.3 / 22.7 → 6.6 / 20.3 | 14.5 / 213.7 → 9.2 / 21.1 | 14.4 / 215.1 → 11.2 / 24.1 | 34.2 / 233.8 → 11.6 / 23.9 | 18.1 / 246.2 → 12.0 / 24.5 |
| 256 | 14.7 / 137.1 → 13.4 / 49.0 | 28.1 / 226.9 → 15.5 / 50.6 | 28.8 / 297.5 → 11.7 / 45.2 | 36.6 / 341.4 → 14.2 / 45.7 | 31.5 / 312.9 → 19.0 / 57.1 |

The runs:

| N | run wall (s) | contention | 4x step-downs to 2x | stalls lifted | largest routing window (after) |
|---|---|---|---|---|---|
| 9 | 33.3 → 27.9 | 1.02 / 1.03 | 0 → 0 | 0 → 0 | 3.6 ms |
| 25 | 47.9 → 40.3 | 1.02 / 1.01 | 0 → 0 | 0 → 0 | 4.7 ms |
| 50 | 142.6 → 48.3 | 1.01 / 1.01 | 29 → 0 | 0 → 0 | 4.2 ms |
| 100 | 316.5 → 96.5 | 1.01 / 1.01 | 427 → 0 | 1 → 0 | 6.8 ms |
| 256 | 573.7 → 156.3 | 1.01 / 1.01 | 1744 → 0 | 3 → 0 | 8.2 ms |

## Route plans

Plans charged to residents over the whole run (the desk's tally): how many, the mean, and the longest. A plan the desk
carries over counts once, with all its slices.

| N | before: plans / mean ms / max ms | after: plans / mean ms / max ms |
|---|---|---|
| 9 | 578 / 1.28 / 9 | 581 / 0.42 / 6 |
| 25 | 816 / 5.35 / 44 | 1119 / 0.95 / 11 |
| 50 | 4148 / 19.77 / 188 | 4511 / 0.70 / 13 |
| 100 | 6230 / 36.13 / 437 | 9810 / 1.76 / 48 |
| 256 | 6180 / 63.29 / 383 | 3957 / 3.32 / 24 |

- **Why the mean fell.** The plan no longer rings and tests every standing resident (the 2026-10-01 note's hot spot
  1). The obstacle tests read a disk grid instead of a 7.3 m pad. A goal ringed by a crowd, or tucked where no route
  reaches, is known shut in from its own side. At 50 and 100 most plans go to such goals: the supper table ringed by
  diners, the hall's door at dusk.
- **Why the counts rose at 25–100.** Residents set off sooner and so plan more often.
- **The same routes.** `test_demo_route_planning.gd` plans the village both ways (the old planner is kept in
  `test/fixtures/`) and finds the same waypoints for 144 trips with crowds of 0–100 standing.
- **The desk's own counts after** (served late / windows that ended with a plan carried / fields built):
  - 9: 15 / 6 / 0
  - 25: 179 / 47 / 6
  - 50: 263 / 66 / 19
  - 100: 3422 / 1969 / 42
  - 256: 1814 / 745 / 20

  A plan carried across frames costs no frame more than its window.

A micro-benchmark on the village, 20 random trips each (`ms per plan, new vs old`, before the disk grid and the shut-in
look were added): 1.4 vs 1.8 at 9 standing, 2.9 vs 13.7 at 50, 4.2 vs 32.2 at 100, 5.5 vs 59.0 at 200. The same set of
30 slow plans from a live 50-resident run took 1.6 ms each against the old planner's 48–73 ms, with identical routes.

## The bursts

Frame work in the burst window, p95 / max (ms), and the most residents waiting for a route at once:

| N | supper call 17:00, before | after | bed at dusk 20:00, before | after |
|---|---|---|---|---|
| 9 | 3.7 / 9.9, 7 | 3.4 / 6.1, 2 | 3.0 / 6.8, 5 | 3.1 / 5.5, 6 |
| 25 | 7.6 / 28.5, 21 | 6.5 / 9.6, 16 | 6.5 / 19.4, 24 | 6.2 / 10.8, 17 |
| 50 | 53.0 / 96.7, 44 | 8.1 / 10.5, 1 † | 16.4 / 34.6, 48 | 10.2 / 13.6, 45 |
| 100 | 175.4 / 247.5, 96 | 21.8 / 42.4, 89 | 142.5 / 274.5, 97 | 22.0 / 25.9, 93 |
| 256 | 189.6 / 268.6, 254 | 38.8 / 46.5, 2 † | 137.0 / 334.9, 255 | 51.6 / 78.4, 248 |

† Nobody was called to supper in these runs: the kitchen had nothing on its way. See
[What the village did differently](#what-the-village-did-differently).

Waits for a route (virtual ms) p50 / p95 / max, before → after:

| N | 4x day | 1x supper | 4x evening | 1x dusk |
|---|---|---|---|---|
| 25 | 50 / 298 / 374 → 17 / 250 / 267 | 50 / 300 / 350 → 33 / 167 / 183 | 17 / 50 / 50 → 17 / 50 / 50 | 203 / 403 / 420 → 133 / 183 / 183 |
| 50 | 236 / 1,281 / 5,174 → 17 / 67 / 67 | 144 / 597 / 963 → 17 / 17 / 17 † | 737 / 4,819 / 9,529 → 33 / 67 / 67 | 67 / 502 / 882 → 50 / 1,050 / 1,067 |
| 100 | 117 / 16,086 / 31,527 → 17 / 33 / 33 | 3,321 / 7,179 / 7,971 → 629 / 2,178 / 2,623 | 12,701 / 36,510 / 55,877 → 3,388 / 11,017 / 14,351 | 2,267 / 3,649 / 4,822 → 396 / 2,030 / 15,503 |
| 256 | 55 / 179 / 511 → 18 / 98 / 274 | 8,695 / 19,173 / 21,080 → 17 / 50 / 74 † | 23,148 / 48,389 / 76,614 → 17 / 163 / 199 | 12,462 / 110,571 / 132,949 → 5,302 / 6,898 / 7,048 |

- **Day at 4x.** The waits are now a frame or two at every N.
- **The meal and bed bursts.** They no longer cost the frame. The kitchen calls eight diners a frame and dusk sends
  eight residents a frame.
- **Dusk still queues at 50–256.** Residents still wait seconds there: most of their plans go to the hall's five door
  places, ringed by those who arrived first. Each plan is cheap (it is found shut in), but they are retried.
- **One long wait at 100** (15.5 s at dusk) is a resident retrying a door place that stayed shut.
- **The per-system costs** behind these tables are in the harness's `tables_hl.md` for each run.

## The other changes (decision 1004)

Mean / p99 ms in the 4x day, before → after:

| N | brains (their walking step) | people and affinity | work board |
|---|---|---|---|
| 50 | 10.29 / 102.78 → 0.95 / 3.79 | 0.05 / 0.44 → 0.04 / 0.28 | 0.05 / 0.22 → 0.04 / 0.19 |
| 100 | 13.54 / 200.26 → 2.44 / 4.75 | 0.10 / 1.06 → 0.05 / 0.43 | 0.25 / 7.87 → 0.06 / 0.26 |
| 256 | 62.12 / 203.45 → 2.77 / 7.75 | 0.39 / 4.96 → 0.08 / 0.80 | 0.19 / 0.45 → 0.11 / 0.38 |

The brains' "before" includes the route plans they made inline. Their walking step alone shows at dusk with a crowd
walking: at 256, `cast.brains` was 6.62 / 14.73 before and 5.41 / 34.17 after. Twice as many residents were walking
at once after, because they had their routes. The neighbour questions read the cells round each walker, and in the door
crowd the cells are full.

## The shared-goal field (decision 1002), measured on its own

Two runs at 100, side by side, the same code but the field switch:

| | dusk's bed plans: mean | dusk route wait p95 | fields built |
|---|---|---|---|
| no field | 2.23 ms | 1.61 s | 0 |
| field away from the goal (as committed) | 1.45 ms | 0.97 s | 20 |

The first version used the field everywhere and made guided plans dearer than plain ones: 3.3 ms against 1.75 ms. It
led the search into the crowd round the goal, which the field does not know. That version was dropped for this one. The
supper and evening phases of the A/B are not comparable: the kitchen called diners in one run and not the other. The
gain is real but modest, because a plan in this village is already short. Decision 1002 asks Brendan whether to keep it.

## What the village did differently

At 9 and 25 residents the village did the same before and after: the same meals eaten (supper 8 of 9 and 22 of 25),
the same bedless count, the same off-POI starts.

At 50 and above it did not. **Supper fed 0 after, against 8–10 before.** This was traced in instrumented runs, outside
the measured matrix. It is the kitchen's own round, not routing:

- **At 50 and 100** the cook, with all the supper's food at the cauldron, cooks batch after batch (25 or 50 of them)
  straight through the supper window, and carries the pot to the table only after it ends. `kitchen.gd _cook_next`:
  cook while a batch may start, then take the pot.
  - In the before runs the cook happened to run short of fetched food early, carried a first pot of 8 out, and those
    8 were eaten.
  - With routes now served in a frame or two, the cook's fetching is done before cooking starts, and nothing goes out
    until the window has closed.
- **At 256 (and one 50 run)** the cook was never handed its round. The next morning's slot was re-chosen to a dish
  before its oats were fetched (`_fetch_location` -1, `cook_has_work` false all day). Not traced further.

Both are the kitchen's capacity and order, which the scale test already listed under "Limits that are not CPU" ("the
kitchen feeds about ten"). They are left to the kitchen's owners. **For Brendan:** should the cook put out what is in
the pot when its meal is called, rather than cooking the whole meal first? Recommendation: yes, a kitchen-lane change.

## What is next, in order

1. **The skeletal actors (hot spot 3, deferred by Brendan).** At 256 the engine's own frame work is 5 ms and the actors'
   drawing 1.5 ms before rendering. The crowd path is still the only way to 256.
2. **The UI's group status.** At 256 `demo/control/group_select.gd` takes 2.4 ms a frame on average, with p95 spikes of
   29–32 ms, before and after: the largest single item in the 256 frame now. At 100 its p95 is 10 ms.
3. **Plans to goals no route reaches** are now cheap, but they are most plans at 50+ and are retried. Fewer residents
   sent to one point (more door places, seats, cooks) would cut them: the scale test's content limits.
4. **The dusk crowd's walking step** at 256 (`cast.brains` p99 34 ms).
5. **The routing window** may run one expansion past its budget, and a crowd expansion is up to about 4.7 ms. A window
   at 256 reached 8.2 ms against 3.5 ms.

## Raw data

The runs live in the session scratchpad, not the repository. Regenerate them with the commands above. Each run's JSON
carries the desk's counts (`desk`) beside the 2026-10-01 fields.
