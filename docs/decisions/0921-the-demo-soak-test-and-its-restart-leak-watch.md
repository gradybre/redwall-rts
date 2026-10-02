# 0921 — The demo's soak test: twenty game days at 4x, hourly monitors, daily floors, and a leak watch around Restart
Date: 2026-10-01 · Status: Accepted

Brendan approved the soak test on 2026-10-01 (feature #14): overnight runs of 20+ game days, checking memory growth,
leaks and slowdown, before the Windows playtest build. Numbered 0921 from the range the coordinator assigned
(0921–0929). The results are in [`docs/performance/2026-10-01-soak-test.md`](../performance/2026-10-01-soak-test.md).

## Decision

1. **A headless soak runner on the scale test's harness** (`godot/tools/soak/soak_test.gd`). It boots the real
   `demo/demo_village.tscn` and runs it at 4x for `--days` game days (20 by default). It reuses the scale test's
   per-system driver and the cast's probe (decision 0561), its fixed step (`--fixed-fps`, refused without it) and its
   way of lifting an unasked pause. Nothing of the scale harness is copied.
2. **Sampled every game hour**: static memory and its peak; the engine's object, node, resource and orphan-node counts;
   video, texture and buffer memory (0 headless); the errors and warnings heard; and the village's own capped books
   (notices, incidents, pantry lots, batches cooked). Every frame the village ran at 4x is reduced, per game day, to
   p50/p95/p99/max/mean of its work and of each system's time.
3. **The harness's own memory does not grow while it measures.**
   - The hourly table is sized for the whole run before the first sample (`soak_table.gd`).
   - A day's frames sit in buffers sized for one day (`soak_days.gd`).
   - Each day's summary goes into a packed column sized for every day.
   - A first 20-day run kept its day summaries as Dictionaries. They added about 30 KB a day, more than half of the
     static-memory slope that run showed. Hence the packed column.
4. **Errors are counted from inside.** The runner registers a `Logger` (`soak_errors.gd`, `OS.add_logger`, Godot
   4.5+). It counts every engine error, script error and warning, and keeps the first eight of each. The suite's
   runner (decision 0004) says a script cannot see its own errors. That was true before 4.5; on 4.7.2 a Logger hears
   them (probed). The Python runner still counts the log's error lines too, and sees exit-time reports.
5. **The harness also acts, as a player would.** At the village's own hours:
   - 04:00: the pantry topped up to 3 U each of oats and carrots per resident, and the water butt filled.
   - 10:00: a work party of up to eight ordered to the square.
   - 11:00: the party let go.
   - Every `--restart-every-hours`: the game menu's Restart demo.

   The top-up is the scale test's stock, kept up. Left alone, the demo's farm runs out of food by day 9 (decision
   0911), and a kitchen that never cooks churns nothing.
6. **The restart leak watch** (`soak_leaks.gd`). Just before the restart, it walks everything reachable from the old
   village and keeps a WeakRef to each object found. The walk covers:
   - its nodes;
   - their script members, through Arrays, Dictionaries, and the objects and bound arguments of Callables.

   It leaves out Resources, nodes outside the village and the main loop. Once the new village is open, every watched
   object still alive is a survivor. Each survivor is labelled by its script and sorted into two kinds:
   - **unreachable**: nothing alive in the tree reaches it, so it is a leak;
   - **held**: something alive still reaches it. That is an autoload, the new village, or a script's **static**
     member (a cache such as `forest_root_field.gd`'s baked fields).

   The weak references are released after the check. Each WeakRef is an engine object, and 4 300 of them first read
   as the village's growth.
7. **The end is a restart without the reopening.** After the last hour the runner watches the village, frees it, waits
   30 frames and checks it as after a restart (`exit_record`, judged like a restart). Quitting with the village in
   the tree would leave the engine's exit report to say whether anything leaked. That report also counts every sound
   still playing as the process quits: an AudioStream and its playback each, seen under `--verbose` as
   `amb_stream_01.ogg` and `amb_wind_01.wav` "still in use" (3, 13 or 21 "resources" depending on what was playing).
   Freed first, the village leaves an empty exit report.
8. **The report tool** (`tools/soak_report.py`, thresholds and their reasons in `tools/soak_thresholds.json`). It
   writes markdown and a small verdict JSON. Its tests:
   - **Memory growth.** Each game day is reduced to its **floor**, its smallest hourly sample. A column is flagged
     only when all three hold:
     - a least-squares line through the floors after the warm-up day rises faster than the threshold;
     - the floors rose on at least 60 % of the day-to-day steps;
     - the net change exceeds one day's allowance.
   - **Frame-time drift.** The relative slope of the daily p50 and p95. It is flagged only when the Godot process's
     own CPU time per frame drifts too, so a busier machine is reported as load, not as a slower game.
   - **Each system's daily mean.**
   - **Errors and exit-time leak reports.**
   - **Restarts.** Anything unreachable, and objects or static memory that rise restart after restart.

   `tools/soak_test.py` runs the harness and samples the load average and the process's RSS and CPU time every
   5 s. It folds those samples into the JSON.
9. **The suite** (`test/test_soak_harness.gd`):
   - unit tests of every piece;
   - a 5-game-hour live run with a Restart, about 20 s, asserting no error and nothing unreachable;
   - with `REDWALL_SLOW_TESTS=1`, one game day with a Restart at hour 18, about 45 s idle. It also asserts the
     in-run growth check's short-run tolerances (`soak_growth.gd`) from hour 13 on.

## Why

- **Floors, not samples.** A day's busiest hour (supper, the night's walk) holds transient tasks and plans. What a day
  *retains* is its quietest point. Fitting the floors removes the daily cycle without a model of it.
- **Slope, monotonic share and net change together.** A slope alone flags one late step (a capped log filling for the
  first time). A net change alone flags noise. A leak is all three.
- **CPU per frame beside wall time.** The machine is shared. The first 20-day run had load 18–65, and its frame p95
  wandered 3–16 ms with the load, not with the game. The process's own CPU time separates the two, though not
  perfectly: contention raises CPU per frame a little too (hyperthreads, caches).
- **Restart rather than "exit" for leaks.** The engine's exit report sees what is alive at quit. That mixes a cycle
  with the sounds still playing (§7). The watch around a real Restart, and around freeing the village at the end,
  measures exactly what is left behind, names it, and needs no `--verbose`.
- **Static members of every watched script are walked at the check**, not only those of scripts with a live instance.
  At the end no new village exists, and without this `water_map.gd`, held by another script's static cache, read as
  unreachable.
- **Not `Performance.TIME_PROCESS`, not a frame cap**: as decision 0561.

## Consequences

- `python3 tools/soak_test.py --out-dir <dir> --days 20` takes 6–12 minutes on the development Mac at N=9 (about
  17 s a game day unloaded). `--residents 25` works; it is slower and was not run for 20 days here.
- **Proposal for Brendan: the harness's actions.** The top-up and the daily work party are harness choices, made
  where the documents are silent. A soak without them measures a village that stops cooking on day 9. The options:
  - keep the top-up (recommended);
  - add a light-touch policy run (decision 0911's) as a second soak;
  - run both.
- **The thresholds are first readings, not budgets.** REQ-SET-163's memory budget is for simulation-owned memory on
  the qualification floor; the demo is presentation and holds about 1.07 GB of staged assets. The thresholds catch
  growth and drift, and every one says why it sits where it does.
- The 0561 scale test's suite tolerance of one exit-time leak line (`test_scale_stress.gd EXIT_LEAK`) is left as it
  is. The cycle it covered is fixed (decision 0922), and the tolerance can come out once a run of that test confirms
  the line is gone. That is the scale test's owner's call.

## Source

Brendan's approval of 2026-10-01 (the soak-test brief); decisions 0561 (the scale harness reused) and 0911 (the balance
harness's deterministic headless runner and its slow gate); CLAUDE.md's performance targets; the measurements in the
performance note.
