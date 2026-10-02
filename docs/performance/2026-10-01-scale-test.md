# The live demo at 9, 25, 50, 100 and 256 residents — scale test, 2026-10-01

Brendan approved this test on 2026-10-01. The live demo has 9 residents; REQ-SET-163 targets 256. This note answers
three questions: does the demo hold at 50 and 100, what breaks first, and what would fix it. The harness and the stress
mode are in decision [0561](../decisions/0561-the-demo-scale-test-and-its-stress-cast.md).

## Read this first: what these numbers are

- **This measures the demo, not the settlement simulation.** The demo's residents are presentation-only actors: one
  full skeletal rig each, with an AnimationPlayer, a tail spring and a wandering brain (decision 0196). The adopted
  design caps skeletal actors at 24 and puts everyone else on the crowd path (CLAUDE.md). The demo has no crowd path,
  so every resident here is skeletal. That is measured as it is, and the crowd path is recommended below.
- **Debug build on a loaded development Mac.** The runs used the editor binary (debug GDScript) on an Apple M5 Pro
  (18 cores), headless, while several other agents ran Godot on the same machine. The 1-minute load average was 15–80.
  Each run records its wall time, its own CPU time and the load before and after. The ratio of wall time to CPU time
  is the **contention factor**: 1.34, 1.15 and 1.35 for the stocked runs at 9, 25 and 50, but **3.49 at 100** and
  **2.46 at 256**. So the N=100 and 256 stocked tails are inflated about 2.5–3.5 times, and there even O(1) systems
  show p99 spikes of 20–60 ms.
  Read means rather than tails at 100, and read the ranking rather than the absolute values. These are not a
  pass/fail against REQ-SET-163, which is defined on the qualification floor (Ryzen 5 3600, GTX 1660 Super) with a
  release build.
- **Headless.** No rendering is measured here. "Engine + render" below is the engine's own per-frame work outside the
  scripts: animation, skeletons, tail springs and scene processing. A windowed run measures render CPU and GPU
  (`--windowed`); its results are in [Windowed](#windowed).
- **Frames run uncapped at a fixed 60 Hz step** (`--fixed-fps 60`). Each frame hands the village 1/60 s of demo time,
  so a frame's duration is its work. "Work" is the frame's real duration less the harness's own time. Waits for a
  route are counted on a 60 Hz virtual clock (decision 0561 §4).
- **The pantry is stocked.** On day 1 nothing is harvested, so the kitchen would cook nothing and call nobody, and no
  meal burst would be measured. The harness puts in oats and carrots (3 U per resident each, as far as the covered
  store has room; at 256 only the oats fit) and fills the water butt. The unstocked runs (`--no-stock`) are kept for
  comparison.

Reproduce:

```
python3 tools/scale_test.py --out <dir> --residents 9 25 50 100 256 --csv     # ~45 min on an idle machine
python3 tools/scale_test.py --out <dir> --tables-only                          # re-tabulate
godot --path godot demo/demo_village.tscn -- --stress-residents 50            # look at it
```

### The plan each run follows

The calendar starts at tick 0, which is 06:00 on spring day 1. 1x is 25 s per game hour.

| Phase | Speed | Game time | Contains |
|---|---|---|---|
| 4x_warmup (not reported) | 4x | 06:00–06:50 | boot settling, the cook's 05:00 start |
| 1x_breakfast | 1x | 06:50–07:40 | breakfast call 07:00 (on day 1 nothing is cooked in time) |
| order | 1x | 07:40 | a group order, timed until the routing desk has served it |
| 4x_day | 4x | 07:40–16:50 | the working day |
| 1x_supper | 1x | 16:50–17:40 | supper call 17:00 |
| 4x_evening | 4x | 17:40–19:50 | supper eaten, evening |
| 1x_dusk | 1x | 19:50–20:40 | everyone to bed at 20:00 (the night routine) |

## Headline per N

Stocked runs at every N. Times are milliseconds of frame work. The targets are a frame p95 under 16.67 and a
sim tick at 1x p99 under 2.

| N | 1x breakfast p95 / p99 | 1x supper p95 / p99 | 1x dusk p95 / p99 | 4x day p95 / p99 | 4x evening p95 | 4x step-downs to 2x | Stalls (CRITICAL pauses) |
|---|---|---|---|---|---|---|---|
| 9 | 3.8 / 5.1 | 4.3 / 8.1 | 6.5 / 16.0 | 4.9 / 7.6 | 9.4 | 0 | 0 |
| 25 | 6.1 / 14.6 | 34.6 / 52.2 | 6.6 / 11.4 | 50.9 / 57.3 | 74.3 | 0 | 0 |
| 50 | 10.9 / 68.4 | 75.5 / 104.3 | 174.3 / 431.3 | 91.0 / 109.0 | 348.0 | 357 | 6 |
| 100 † | 85.7 / 143.3 | 1533 / 2004 | 610 / 889 | 1366 / 2043 | 2978 | 1976 | 325 |
| 256 † | 463 / 679 | 656 / 846 | 399 / 569 | 757 / 1064 | 497 | 2115 | 239 |

† Contention factor 3.5 at 100 and 2.5 at 256: divide by roughly 3 for an unloaded estimate. The unstocked runs, at a
lower load, gave at 100: 1x breakfast p95 45.8, 4x day p95 66.7, 1x dusk p95 99.8; and at 256: 1x breakfast p95
139, 4x day p95 164, 1x dusk p95 300.

**In short:**

- **9 holds** comfortably. Every frame p95 is under 10 ms, and the sim tick budget is met.
- **25 already misses the 16.67 ms p95** whenever many residents plan routes at once: the 4x working day (p95 51) and
  supper (p95 35). It is fine when few are planning, as at breakfast and dusk.
- **50 breaks.** The 4x clock steps down to 2x 357 times, and there are stalls. Bed time at dusk reaches p99 431 ms.
- **100 does not run.** Frames of seconds, 325 stalls, and the routing desk's queue is never empty.

Below roughly 25 residents everything scales gently. Above it one thing dominates: the cost of planning one route.

## Hot spots, ranked

Ranked by what fails first at 50 and 100, with the evidence.

### 1. A single route plan costs more as the village grows (cast_nav.gd) — first to break, at 25

The mean cost of one route plan, over the whole run, from the routing desk's per-resident tally:

| N | plans | mean ms per plan | max ms | by kind (mean ms) |
|---|---|---|---|---|
| 9 | 546 | 2.0 | 33 | kitchen 2.3, routine 1.9, bed 1.8, order 1.1 |
| 25 | 1969 | 16.1 | 119 | kitchen 17.7, routine 17.1, bed 2.3, order 3.0 |
| 50 | 4517 | 44.8 | 561 | kitchen 51.9, routine 48.0, bed 23.2, order 4.0 |
| 100 † | 5599 | 323 (≈100 unloaded) | 4220 | kitchen 366, routine 385, bed 86, order 13 |
| 256 † | 5814 | 240 (≈100 unloaded) | 1539 | routine 290, bed 48, kitchen 31, order 21 |

From 9 to 50, plans per run grow 8x and each plan gets 22x dearer. Together that is roughly 180x more planning for
5.5x the residents.

**Why.** `cast_nav.gd plan` builds a visibility graph per plan:

- `_prepare_search` rings **every standing resident** with 6 dynamic nodes (`_ring_standing`, STANDING_RING).
- Every node A* expands then runs `_link_dynamic` over **all** dynamic nodes, and each candidate edge runs
  `_standing_hit` over **all** standing residents.
- That is O(expanded × D × S) with D ≈ 6S, so **quadratic in the residents standing still**.

Most of the village is standing at any moment (2–5 walkers on average by day, even at 100). Diners standing at the
single overflow point by the tables (the kitchen has 10 seats), residents queued at the hall door, and off-POI
residents stacked at the origin all add standing circles to every plan.

**What it does to the frame.** The routing desk (decision 0361) bounds the *number of plans started* in a frame, not
a plan's length. "A window spends at most its budget, or one plan's time when that plan alone is longer" (route_desk.gd).
So from about 25 residents up, every frame that serves a waiter costs one whole plan: 50–120 ms at 25 and 50, and
seconds at 100. The `cast.route_spend` and `cast.route_serve` rows carry essentially all of the frame:

- 4x day mean at 50: cast 15.1 ms, of which route plans 13.8 ms.
- 4x day mean at 100: 208 of 218 ms.

### 2. Bursts that put the whole village on the routing desk at once: the meal call, bed time, dawn — at 25–50

Three moments make every resident plan in the same frame or two. Each is O(N) to issue, but N plans of hot spot 1
then follow.

| N | supper call 17:00: frame p95 / max, residents waiting | bed at dusk 20:00: frame p95 / max, residents waiting |
|---|---|---|
| 9 | 4.2 / 17.9 ms, 6 | 6.7 / 31.8 ms, 7 |
| 25 | 33.8 / 59.6 ms, 23 | 7.2 / 23.8 ms, 22 |
| 50 | 58.2 / 119.1 ms, 48 | 118.5 / 494.1 ms, 49 |
| 100 † | 1650 / 2450 ms, 97 | 359 / 889 ms, 99 |

- **The kitchen's call** (`kitchen.gd _call_diners`) gives every free resident an eat task in one `_hand_out`:
  `TaskScript.new` + `order_task`. That is the kitchen's own p99 spike of 8–35 ms at the call.
- **The night routine's dusk** (`night_routine.gd _at_dusk`) sends N sleep tasks at once. On day 1 nobody has a bed
  (`bedless` = N in every run), so all of them walk to the hall door. `hall_spot` is O(N²), with only five distinct
  door spots.

Residents waiting for a route at 4x, in 60 Hz virtual time:

| N | p50 | p95 | max |
|---|---|---|---|
| 9 | 67 ms | 117 ms | — |
| 25 | 67 ms | 69 ms | — |
| 50 | 133 ms | 333 ms | 344 ms |
| 100 † | 2.9 s | 37 s | 67 s |

At 50 the waits are still visible as hesitation. At 100 residents stand "finding a route" for tens of seconds.

### 3. Skeletal actors: one rig, clip and tail per resident — linear, and the crowd path's job

These costs grow linearly at about 45–60 µs per resident (CPU, headless, before any rendering), and are
independent of what the village does:

| N | engine + render (headless) | actors' drawing (scripts) |
|---|---|---|
| 9 | 0.5 ms | 0.11 ms |
| 25 | 1.0 ms | 0.25 ms |
| 50 | 1.8 ms | 0.46 ms |
| 100 | 6.1 ms (unstocked) | 1.8–2.2 ms |
| 256 | 14–26 ms (unstocked) | 4.4–8.8 ms |

- **Engine + render (headless)** is animation, skeletons and tail springs.
- **Actors' drawing** is `demo_actor.gd draw`: transform, stoop, strike and clip.

Each resident adds about 23 nodes (3,647 at 9, 9,331 at 256) and 0.19 MB of static memory (1,067 MB at 9, 1,115 MB at
256 at open). Rendering comes on top.

At 256 this alone is 20–35 ms a frame on this machine. That is over budget before a single route is planned. **This is
where the crowd path is needed**: past the 24 nearest or selected residents, a resident should be a crowd instance
(`scripts/presentation/resident_crowd.gd` already exists for the game) with no AnimationPlayer, skeleton or tail.

### 4. The brains' walking step: per walker, per resident — shows at dusk

`resident_brain.gd _step_walk` runs `cast_space.gd separation` / `constrain` / `standing_blocks`, each an O(N) scan, for
every walker on every sub-step (3 sub-steps a frame at 4x). This is the brain's time less the plans it made:

| N | 4x day (2–5 walkers) | 1x dusk (24–28 walkers) |
|---|---|---|
| 9 | 0.5 ms | 0.6 ms |
| 25 | 0.8 ms | 1.3 ms |
| 50 | 0.8 ms | 6.5 ms |
| 100 † | 5.4 ms | 10.8 ms |
| 256 † | 4.1 ms | 19.8 ms (22 walkers) |

This is O(walkers × N). It is cheap while the village stands still and second only to routing when everyone walks to
bed. With hot spots 1 and 2 fixed, more residents would walk at once, and this would become the next wall.

### 5. Songs: the context read scanned the board once per resident — fixed in this change

`demo_songs.gd read_contexts` runs four times a real second. It asked `_board_working(i)` of each resident, and each
call looped over every row of every board source, one of which (the kitchen's) has a row per resident. That is
O(N × rows), so O(N²). It now marks the working residents in one pass over the rows
([below](#the-fix-made-in-this-change)).

### 6. The work board's claim scan — spikes at 50 and up

Mean under 1 ms at every N, but p99 of 11–16 ms at 50 and 100 in the unstocked runs. This is `rebuild_index`
(O(rows + tasks × residents)) and `consider` per resident on the claim period (decision 0411). It is not first to
break, but it is a per-resident × per-task cost that grows with both.

### 7. People and affinity: the pair loop — the O(N²) one, still cheap at 100

`people_taps.gd _poll_shared_work` checks every pair every 25 ticks (decision 0491). At 256 that is 32,640 pairs a
poll; `ledger.midnight` and the end-of-supper pass are also O(N²), and the ledger holds N×N cells.

- 4x mean: 0.04 ms at 9, 0.07 at 50, 0.47 at 100 †, 0.98 at 256.
- p99: 8.8 ms at 256 at dusk.

It is cheap now, but it is the textbook quadratic, and it lands on the same frames as hot spots 1–2.

### Below the line (linear, cheap or bounded at 100)

- **The kitchen's per-frame work**: 0.04–0.09 ms mean up to 50.
- **Night routine per frame**: tunnels + night 0.27–0.30 ms mean up to 50.
- **Sound**: 0.09–0.14 ms; the event cap (64 a frame) and the voice pool (8) bound it.
- **Overlays**: 0.11–0.20 ms.
- **UI**: 0.20–0.26 ms mean, p95 0.33–0.43 ms up to 50, inside the 1.5 ms UI budget. The roster and party panel
  show only the selection or a pool of 12.
- **Woods**: linear, 0.12 → 2.9 ms at 256.
- **The settlement clock (GameManager)**: its cost follows frame time, because a slow frame owes catch-up ticks. It
  is a consequence, not a cause; note it runs on real time, not the fixed step.

### Limits that are not CPU but break above 9

Each of these makes the 50- and 100-resident village behave differently from the 9.

- **POI slots.** The world has about 19 POI slots. Residents beyond them start stacked on a 1.5 m ring round the
  origin, and they keep retrying departures. Off-POI starts were 2, 6, 31 and 81 at 9, 25, 50 and 100, and 237 at 256.
- **The kitchen feeds about ten.** It has one cook, 10 seats, a pot of at most 24 lots, and plans a day ahead. With
  food stocked, supper fed 7 of 9, 0 of 25, 0 of 50 and 10 of 100; breakfast fed nobody on day 1 at any N. The meal
  loop needs more cooks, more tables and a bigger pot before it can feed a village of 50.
- **Beds.** At most about 24 beds (8 rooms × 3), and none on day 1. Everyone else sleeps in the hall, via five door
  spots.
- **The group order.** A formation is capped at 8 m. Ordering the whole village to one spot is refused from 25 up
  (the harness falls back to a 16-strong party). The party's call takes 3.4–8.8 ms on the command's frame, and the
  desk serves it in 3–17 frames.
- **People's deed credit.** `people_taps.gd MAX_MASK_RESIDENTS = 62`: residents from index 62 up are never credited
  for a bridge or tunnel deed.
- **Others.** The roster lists 12 rows (`ROSTER_POOL`); the route overlay marks at most 16 blocking points; chip
  colours repeat after 8.

### Memory

| N | static MB at open | static MB at end | nodes | objects |
|---|---|---|---|---|
| 9 | 1,067 | 1,074 | 3,647 | 13,575 |
| 25 | 1,070 | 1,077 | 4,021 | 14,203 |
| 50 | 1,075 | 1,082 | 4,594 | 15,150 |
| 100 | 1,085 | 1,093 | 5,740 | 17,049 |
| 256 | 1,115 | 1,123 | 9,331 | 22,955 |

The process holds the demo's whole staged library, so about 1.07 GB is fixed. Each resident costs about 0.19 MB. This
is process memory, not the simulation-owned 100 MB budget (the demo is not the simulation). Nothing grows during a run
beyond about 8 MB of notices and ledgers.

## N=256

**256 boots** in 21–42 s under load, with 237 of 256 residents starting off-POI, and **runs the whole plan** with no
invariant broken. It is nowhere near budget:

- frame p95 is 400–760 ms in every phase;
- the 4x clock steps down 2,115 times;
- 239 stalls are lifted;
- the 16-strong group order is served after 25 frames (1.5 s of virtual time).

**Most of the work is routing.** 4,618 routine plans average 290 ms each (loaded). Most of the cast is off-POI and
keeps retrying its departures.

**Nothing was cooked.** Only the oats fitted in the covered store, so nobody was called to a meal.

**Even with routing fixed, skeletal work alone rules 256 out.** Hot spot 3 is about 18–26 ms of engine work and
4.4–8.8 ms of actor drawing a frame, before rendering.

## Windowed

A short windowed run, at 1920x1080 on the Mac's display (Forward+ on Metal, uncapped, vsync off), at the same machine
load. The command was `python3 tools/scale_test.py --windowed --plan short`.

| N | frame work p50 / p95 (1x) | render CPU p50 / p95 | draw calls | video memory |
|---|---|---|---|---|
| 9 | 10.1 / 11.5 ms | 0.7 / 0.9 ms | 702–708 | 1,311 MB |
| 50 | 12.0 / 13.2 ms | 0.9 / 1.1 ms | 975–983 | 1,326 MB |

- **Each resident adds about 6.7 draw calls**: body, clips and tail, a skinned mesh each. Extrapolated, that is about
  2,350 at 256.
- **The windowed frame carries about 8 ms of fixed engine and present work** on this machine, whatever N is.
- **No GPU time.** The engine's measured GPU time read 0 here; Metal reported no timestamp. GPU cost must be measured
  on the qualification floor's GPU.
- **Not yet done.** A full windowed matrix on an idle machine and a release export.

## The fix made in this change

**Songs' context read: one pass over the board** (`demo_songs.gd _mark_board_working`).

- `read_contexts` now marks every resident holding a WORKING or HAULING board task in one pass over the board's
  rows, and passes the mark down to each resident's context.
- `context_of`, called on its own, still scans for that resident.
- Both use one row predicate, `_row_busy`.
- It is tested through `read_contexts` against the per-resident scan (`test_demo_songs.gd`).

Before and after, unstocked runs with the same plan. The "after" runs had the higher machine load, so the gain is if
anything understated:

| N | phase | songs mean before → after (ms) | songs p99 before → after (ms) |
|---|---|---|---|
| 50 | 4x day | 0.60 → 0.11 | 10.1 → 0.9 |
| 100 | 1x breakfast | 1.23 → 0.15 | 19.6 → 1.9 |
| 100 | 4x day | 1.80 → 0.18 | 31.8 → 1.7 |
| 256 | 1x breakfast | 4.38 → 0.56 | 77.2 → 15.4 |
| 256 | 4x day | 3.22 → 0.21 | 59.8 → 1.7 |

Decision 0442's song-circle fix had measured the circle's step alone (34 µs at 256). This read, outside it, was the
remaining quadratic in songs.

## Recommendations

In order of what unblocks the next N. Estimates assume one engineer who knows the demo.

1. **Make one route plan cheap, and make it divisible.** This unblocks 25 → 50 → 100. Estimate: 3–5 days.
   - In `cast_nav.gd`, ring only the standing residents near the route: a grid query along the start→goal corridor,
     not every standing resident.
   - Index the plan's dynamic nodes in a grid, so `_link_dynamic` and `_standing_hit` are local rather than O(D)
     and O(S).
   - Give A* a node-expansion budget per frame, and resume the search on the next frame, so the routing desk's
     budget bounds time as well as starts. Decision 0361 noted that a plan is never cut in two; that is now the
     problem.
2. **Plan once for many residents going to one place.** This unblocks meal calls and bed time at 50+.
   Estimate: 2–3 days.
   - The supper call, dusk and dawn send N residents to a handful of goals.
   - One reverse search per goal (a distance field over the static graph, refreshed when the obstacles change) serves
     all of them. Each resident then needs only a short local plan near its start.
3. **Spread the bursts.** Estimate: 1 day.
   - The kitchen's `_call_diners` and the night's `_at_dusk` / dawn should call at most K residents a frame (for
     example 8), or a quota per desk window.
   - Make `hall_spot` a running count rather than O(N²).
   - The queue also wants more hall door spots than five.
4. **The crowd path past 24 skeletal actors.** This is required for 100–256. Estimate: 1–2 weeks with the LOD and
   selection hand-off.
   - Keep full rigs for the residents nearest the camera, selected, or doing a visible job. Draw the rest through
     the crowd presentation path (MultiMesh, no AnimationPlayer, no skeleton, no tail spring).
   - This removes hot spot 3, about 50 µs per resident before rendering, as the GDD's 24-actor cap intends.
5. **A resident spatial hash in `cast_space.gd`** for `separation`, `constrain`, `standing_blocks`, `room_ahead` and
   `oncoming`. `cast_grid.gd` already indexes obstacles. This turns hot spot 4 from O(walkers × N) into
   O(walkers × local). Estimate: 1–2 days.
6. **Bucket the people's pair loop** by site, crew and cell, so only residents who can be "together" are compared.
   Store the affinity ledger sparsely past about 64 residents. Estimate: 1 day.
7. **Budget the work board's index rebuild**: rebuild incrementally on owner revisions rather than over every row
   each claim period. Estimate: 1 day.
8. **Content limits before 50 is meaningful.** These are design calls, not CPU:
   - more POI slots, or an overflow ring sized by count;
   - kitchen capacity (cooks, seats, pot);
   - beds;
   - the 62-resident deed mask.

### What does not need work yet

- The UI and HUD: inside its 1.5 ms p95 at every uncontended N. It shows a pool of 12, or the selection.
- Sound: capped.
- Overlays, the farm, the fishery, water, the camera.
- The songs: after the fix.
- The kitchen's and the night routine's per-frame work: as opposed to the bursts they trigger.

## Also found

- **A RefCounted cycle.** Once the kitchen has cooked, the demo holds a RefCounted cycle across the cast's space, the
  brains and the kitchen. At exit the engine prints "40 resources still in use"; `--verbose` lists cast_space,
  cast_nav, route_desk, resident_brain, kitchen, kitchen_task, meal_store and farm_pantry among them. Runs in which
  nothing was cooked do not print it. If it survives the menu's "Restart demo", each restart leaks a whole cast. It is
  recorded here and in the suite test's one tolerated line (`test_scale_stress.gd EXIT_LEAK`); it was not fixed in
  this change.
- **The 4x clock steps itself down.** A frame slower than about 66.7 ms at 4x makes the settlement clock step 4x down
  to 2x. The demo then follows it. At 50 residents this happens constantly.

## Raw data

The runs live in the session scratchpad, not the repository. They are regenerated by
`python3 tools/scale_test.py --out <dir> --csv`: each run's JSON report, its per-frame CSV (one row per frame, every
column) and its log, plus `tables_hl.md`.
