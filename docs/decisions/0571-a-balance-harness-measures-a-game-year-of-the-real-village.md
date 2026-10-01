# 0571 — A balance harness measures a game year of the real village, headless and deterministic
Date: 2026-10-01 · Status: Accepted

Numbered 0571: decisions 0531–0533 (demolition), 0541 (lighting), 0561–0562 (scale test), 0611 and 0621 were taken on
the branches and worktrees in flight when this was written; 0571 was free on all of them. The parallel ferry and regatta
work had no number on disk yet; if it takes 0571 first, this record is the one to renumber.

## The question

Brendan, 2026-10-01: build a balance simulation harness and "know, with numbers, whether a game year is too easy, too
hard or just busy under the 10-minute day" (decision 0421). This is **measurement, not tuning**: no gameplay value is
changed here. The first baseline is `docs/balance/2026-10-01-first-year-baseline.md`.

## Decision

### 1. The runner boots the real village and runs it as fast as the machine allows

`godot/tools/balance/year_runner.gd` (a thin main loop) loads `balance_run.gd`, which boots `demo/demo_village.tscn`
headless. On the first frame -- the village's `_ready` runs when the tree starts, after the main loop's `_initialize`,
and the demo's opening hold still pauses its clock -- it applies the settings of 2 and the seed. On the first frame the
demo has opened it sets 4x, and from then it measures every frame until the calendar reaches the requested day. The
meta records how many calendar ticks ran before the start (`ticks_before_start`; 0 in every run so far).

```
godot --headless --path godot --fixed-fps 30 --script res://tools/balance/year_runner.gd -- \
    --seed 1 --policy hands_off --days 48 --out /abs/run.json --csv /abs/run.csv
```

- **`--fixed-fps 30` makes the run independent of the machine.** Every frame is exactly 1/30 s whatever it really
  took, so the demo clock (which reads the frame delta, `demo_clock.gd`) advances 133 333 demo microseconds a frame at
  4x: 4 calendar ticks, handed to the walkers in the clock's own 33 ms sub-steps. That is what a player at 4x on a
  30 Hz frame sees, and the village runs as fast as the CPU allows instead of in real time. The engine does not pass
  `--fixed-fps` on to scripts, so the run takes `--fps` (default 30) and refuses, from the start, any frame whose delta
  is not 1/fps. (The boot frames before the demo opens are not checked: their clock is held.) A forgotten flag would otherwise give a real-time run whose numbers depend on the machine's load.
- **Why the run is not the main loop's script.** A main loop's script is compiled before the autoloads are registered,
  and `demo_village.gd` and `ui_shell.gd` name `GameManager`. A script that *preloads* the demo therefore fails to
  compile ("Identifier not found: GameManager"), so the main loop `load()`s the run at start-up.
- **Speed.** At 30 fps and 4x, a game year (48 days) took about 30 minutes of wall time per run on the development Mac.
  At that time the Mac had a load average of 30 to 45 from other agents, and three runs were going at once. Unloaded,
  a game hour takes about 0.6 s, so a year takes about 11 minutes.

### 2. Harness-only settings: no game code changed

The hooks the brief allowed for a headless run were not needed. Every setting below is a public setting or the
player's own control:

| Setting | Why |
|---|---|
| `demo_cast.set_route_budget(0)` | The routing desk's budget is real microseconds a frame (decision 0361). 0 is its documented "no budget": every route is planned at once. |
| `nav.advance_builds(huge)` inside the cast's frame and at the start of each frame | The navigation rebuilds (after a heap or a mound) are sliced by a real-time budget. The cast's own `window_tail` is wrapped so a rebuild queued during a frame is finished in that frame, after the cast's 1.5 ms slice, before any later plan; demo_routes' own tail still runs after it. |
| `GameManager.set_process(false)` | A guard only. The settlement clock adds REAL elapsed time into its ticks and could step the requested speed down on an overload, but the demo never calls `start_game`, so that clock does not run today and this changes nothing. It is kept so a later demo that starts it cannot make the run machine-dependent unnoticed. |
| The pause ledger's `resume()` on a pause | A critical incident autopauses (UI §8.1, default on). The run lifts it the next frame as the player's Space would, and counts it. |
| Re-seeding | See 3. |

The rest of the demo's real-time reads are presentation: the news clock, the panels' message timers, and the profile
counters of the work board and the route desk.

### 3. Seeds

`--seed` re-seeds the farm's WEATHER stream (`rng.gd seed_world`) right after boot. The first spring is forced (an
Ideal spell, no draw), so every later season's §5.10 event comes from the seed. It also re-seeds each resident's own
`rng` (idle wandering, bouts, social visits). The demo's threat schedule (`demo_events.gd` SEED) and deadfall keep their
fixed seeds. The demo's frost nights and blight outbreaks are a fixed schedule (`farm_weather.gd`), so they are the same
for every seed.

**Determinism.** Two 20-hour light-touch runs from seed 1 gave identical day records, and the suite's slow test (one
season, two processes at once) passes. Both ran on one machine under one load. That the result does not depend on the
machine's speed rests on the settings above: no real-time budget is left in the run's path, and the settings are
applied before the clock first moves. Two different machines have not been compared.

### 4. What is recorded, per day, and rolled up per season

Per calendar day (`balance_food.gd`, `balance_labour.gd`, `balance_farm_watch.gd`, `balance_events.gd`):

- **Food** by item: stored, withdrawn and spoiled (the pantry's ledger, decision 0451). Also the kitchen's food cooked
  and eaten raw, portions eaten, batches, table spoilage and a cancelled batch's food, and fish caught and landed.
- **Stock and reserve**: the pantry by item at midnight. The HUD's Ready food (`days_of_meals_milli`) is read at every
  farm hour (keeping the minimum) and at midnight.
- **Meals**: ate a portion, ate raw or went without, from the kitchen's meal log, booked to the meal's own day. The
  fed, peckish and hungry states are counted as resident-hours, one reading an hour.
- **Labour**: every 4 frames each resident is REST, MEAL, WORK, OTHER or IDLE (first match; the definitions are in
  `balance_labour.gd`). The totals are resident-ticks, per resident and for the village.
- **The work board**: scanned every frame, because a claim inside half a second would otherwise be missed. It records
  the queue length weighted by time, its maximum, and each task's wait from the frame it first waits to the frame a
  worker holds it (claimed) or it stops waiting without one (dropped).
- **Materials**: wood, planks, stone, earth and water. Each frame's rise counts as in and each fall as out, because
  the stores keep no ledger. The stock at the close is exact.
- **Weather and losses**: §5.10's event at noon, the demo's frost nights and blight outbreaks, the air temperature the
  crops felt, and waterlogged bed-hours. An hour crossing damages the hour just ended (`farm_sim.gd run_hour`), so each
  reading is of that hour. Bed-health falls are charged to blight (the bed is, or was the hour before, blighted: a
  withered bed loses its mark in the step that killed it), frost (the elapsed hour was a frost-night hour or at or
  below 0 °C) or other. A crop that withers is charged the same way, or as overripe if it stood ripe the hour before.
- **Incidents and threats**: every raise that is not a merged repeat (`occurrences`), each new incident by the first
  part of its key (`first_by_source`), every critical raise or recurrence (from the store's own `incident_cue`), the
  threats (flood and fire) by kind, rescues, and pauses lifted.
- **Orders**: the light-touch player's orders, by verb.

`balance_rollup.gd` rolls days into seasons and a run's totals by one rule on the field's name. Flows are summed;
`_min`, `_max` and `_end` fields and `stock` keep the least, the greatest and the last value. Flags count the days they
were true, and texts join their distinct values. Each run writes JSON (meta, days, seasons, totals) and a 47-column CSV.

### 5. The two policies

- **Hands-off**: the default crews and the automatic work board, with nobody ordered. The routine raises only the
  farm's harvests and clearings (REQ-SET-073/085), the woods' hauls and zone fells, and the kitchen's own work.
- **Light-touch** (`light_touch_policy.gd`): a scripted player that, at 06:00 each day, calls the panels' own verbs with
  nobody selected, so every order goes on the work board. It:
  - harvests ripe beds, drains waterlogged ones and waters dry ones;
  - sows each empty bed with the first crop its soil and today's window allow (even beds roots first, odd beds grain
    first);
  - saws planks below 4 U;
  - turns the North stand's auto-fell on below 30 U of wood and off above 60 U, and gathers deadfall below 30 U;
  - authorises one fishing trip (hand net, then trap, then ice) when none is open and less than 4 U of fresh fish is
    in store.

  At 13:00 it covers the beds with a living crop that a frost is due on, as a player reading the farm's noon frost
  warning would. A sowing already on the board keeps its crop. It does not
  mill or dry fish: neither flour nor dried fish is a kitchen input yet.

### 6. The report and its thresholds

`tools/run_balance_matrix.py` kills a run past its wall-clock limit and fails one whose log has a `SCRIPT ERROR` or
`ERROR:` line, even with its summary line; the runner itself fails on a pause Resume cannot lift that lasts 300 frames,
a calendar that stops advancing, a demo that never opens, and an unknown argument.

`tools/balance_report.py` (standard library only) reads the runs' day records and writes a markdown report. The report
has headlines per run, flags, a season table per policy (seeds side by side), each run's seasons in detail with text
sparklines, and, with `--svg-dir`, one SVG chart per policy of the Ready food. With `--summary-dir` it also writes each
run's season metrics as a small JSON. `tools/run_balance_matrix.py` runs seeds × policies in parallel. It counts a run
done only on its `BALANCE-RUN ok` line and its JSON, because a Godot exit status of 0 proves nothing
(docs/ENVIRONMENT.md).

**The thresholds are in `tools/balance_thresholds.json`.** Each one carries its reason:

| Threshold | Default | Basis |
|---|---|---|
| Ready food below | 2 days | GDD §5.3's urgency bucket 2, and BAL-RUN-008's stabilisation rule of 2 days or more |
| Spoilage above | 10% of the food available in the season (its opening stock plus what was stored) | No GDD target; provisional |
| …and at least | 1 U spoiled | So that a sliver spoiled is not read as 100% |
| Idle above | 50% of idle + work time | GDD §5.3: 10 work hours of about 14 waking ones; provisional |
| Meals missed above | 0% | REQ-SET-012 and decision 0381: everyone is fed at each meal |
| Hungry above | 5% of resident-hours | §5.2's urgent line; an occasional hungry hour is normal |

**The opening is not "running out".** The demo opens with an empty pantry and its first crops still growing. Food
"runs out" only on a day with no Ready food after the first midnight that had some; the days before that are reported
as the opening.

### 7. Tests, and the slow-test convention

- `godot/test/test_balance_harness.gd` covers the roll-up and CSV rules, the labour classes (with the kitchen's
  roles), and the board's claimed, dropped (removed, or blocked without a worker) and reused-row waits on hand-built
  residents and a hand-built source. It also covers the meal log booked to its own day once, the farm watch's blight,
  frost, overripe, sowing and harvest attribution and its elapsed-hour frost reading, and the material flows and
  incident counts on a real stores and incident store. It also covers the policy's tally,
  the day arithmetic, and the runner refusing a bad command line in its own headless process, which never boots the
  village. These checks take seconds.
- **The one-season determinism run is a SLOW test, skipped unless `REDWALL_SLOW_TESTS=1`.** It runs two village
  processes at once for 12 days from seed 7 (light-touch) and compares their day records. That is minutes of wall
  time, far over the suite's 30-second budget for a test. Skipped, the test still checks that its own command line is a
  season and is accepted. This is the first slow-test gate in the suite. A later slow test should use the same variable.
- `tools/test_balance_report.py` drives every flag both ways on hand-built runs. It covers the opening against running
  out, spoilage over the food available, the spoilage floor, idle over idle plus work, waits in game minutes, and the
  report and chart being written. It runs in CI's `contracts` job.

## Consequences

- Shared files touched: `docs/ENVIRONMENT.md` (the harness commands) and `.github/workflows/tests.yml` (the report
  self-test in `contracts`).
- The committed baseline keeps the report, its charts, each run's CSV and a summary JSON per run. The raw run JSON
  (about 110 KB a year) is not committed. It regenerates exactly from the command in the report, because the runs are
  deterministic.

## The review (code-reviewer, 2026-10-01), fixed

- **H1** a crop killed by blight was charged to frost or other (the bed's blight mark is cleared in the step that kills
  it): the stage before now counts.
- **H2** frost was tested against the hour reached rather than the hour damaged, and at the raw air temperature: both
  now follow `run_hour` (`elapsed_air`, `cold_hour`).
- **H3** about 25 frames ran at 1x on the real-time routing budget before the settings applied: they now apply on the
  first frame, while the opening hold keeps the clock still, and the run starts on the first frame the demo opens.
- **H4** the watchers had no unit tests: added (see 7), and the report's surviving mutants are killed by new cases.
- **MEDIUM** fixed: rebuilds finished inside the cast's frame; incident counts on stated bases; the matrix's timeout,
  error scan and closed logs; the runner's watchdog and null checks; the ledger read written once; covers only on
  living crops. **LOW** fixed: a queued sowing keeps its crop, the headline's spoilage honours the floor, CSV quotes
  doubled, unknown arguments and a non-integer seed refused, the tick rate from `SimClock`, the slow test kills its
  children, dead code removed, and the GameManager setting described as the guard it is.
- **Left as they are (LOW):** day 0 covers 18 hours (the demo opens at 06:00) and is not marked partial; the incident
  store evicts resolved rows by its real-time news clock (presentation; it only decides whether a long-resolved
  incident's return counts as new or as a recurrence).

## Open

- **Only one fps is measured.** The baseline runs at 30 fps × 4x. A 60 fps run would hand the walkers the same
  sub-steps, but the per-frame logic would run twice as often. Whether the numbers move with fps is not yet measured.
- The kitchen's after-the-fact meal correction (`kitchen.gd _served_but_missed`) is not seen once a meal is in the log,
  as decision 0451 already notes for the record.
- The material flows net out two moves of one stock inside one frame.
