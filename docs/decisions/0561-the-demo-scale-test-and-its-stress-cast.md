# 0561 — The demo's scale test: a stress cast, a harness that times every script, and the songs' one-pass board read
Date: 2026-10-01 · Status: Accepted

Numbered 0561: the batch's other lanes (lighting, the balance sim, the ferry and regatta, demolition) were working in
parallel, and the highest number on any branch was 0532. If a parallel lane took 0561 too, renumber this one at merge.

Brendan approved the scale test on 2026-10-01: the live demo has 9 residents and REQ-SET-163 targets 256. The results
are in [`docs/performance/2026-10-01-scale-test.md`](../performance/2026-10-01-scale-test.md).

## Decision

1. **A stress cast, off by default** (`godot/demo/stress/stress_cast.gd`). `--stress-residents N` (or a script's
   `override_count`) grows the cast to N by repeating the staged rows in order: resident *i* is row *i* mod 9. A clone
   keeps its row's **creature key**, so crews, homes, roles, the kitchen and the night treat it as they treat the
   original. Only its manifest key (`mouse_fieldworker__t012`, the node's name) and its display name differ. With
   nothing staged, the run uses N placeholders. Without the flag, `expand` returns the manifest's cast unchanged. A
   release export (the Windows demo) ignores the flag.
2. **Names come from data, are non-canon and are marked demo-test** (`stress_names.json`): a first name, then a
   surname built from two lists, picked by cast index so a run repeats exactly. The names are distinct up to 256. They
   are never authored people: interests, evening lines and dialect are the original's, read by creature key.
3. **The harness times every script without touching its code** (`godot/tools/scale_test/`). Once the village opens,
   `scale_driver.gd` turns off each processing script node and calls its `_process` itself, in the engine's own order
   (priority, then tree order). Each call is booked to a system named from the script's path. Inside the cast, one
   `probe` member (`demo/stress/scale_probe.gd`), null unless a measuring run sets it, books the frame's sections:
   serving the routing desk's waiters, the brains, the actors' drawing, the nav rebuild slices, the route previews'
   window tail, and what the frame's routing window spent. The cast has one code path either way: it steps each
   actor's `step_brain` and then its `draw` (`demo_actor.gd advance` is the two), and reads the clock only when the
   probe is set. The harness has a watchdog: past three times the plan's expected frames it fails rather than hangs.
4. **Frames run uncapped at a fixed 60 Hz step** (`--fixed-fps 60`, required). Each frame hands the village exactly
   1/60 s of demo time, so its real duration is its work. Route waits are counted on a 60 Hz *virtual* clock: each
   frame counts as its real length or 16.67 ms, whichever is longer. Otherwise an uncapped run would serve more of the
   routing desk's per-frame budget windows per second than the game ever gets. The fixed step is the demo clock's
   only: the settlement clock (`GameManager`) still runs on real time, so its per-frame cost is not comparable across
   runs of different speed and is reported only as context.
5. **One small fix, from the measurement**: the songs' context read (`demo_songs.gd read_contexts`) now marks who is
   working on the board in one pass over the board's rows. It used to make one pass per resident. The behaviour is
   identical: the read passes its mark down (no state is kept between reads), and `context_of`, called on its own,
   still scans for that one resident. Both share one row predicate (`_row_busy`).

## Why

- **Repeating the rows, not inventing new trades.** The demo's routines key on the nine creature keys (`HOMES`, the
  crews' `START_CREW`, `COOK_KEYS`, `BRIDGEWRIGHT_KEY`). A new key would become a Hauler with no home and no trade, and
  would measure a different village. Keeping the key measures the demo the player sees, with N people in it.
- **Taking over `_process` rather than adding timers to fifty scripts.** The brief asked for timers only where they
  were missing, and cheap and off by default. The driver adds no cost to the game, and nothing in the game changes but
  who calls `_process`. Only `demo_prewarm.gd` turns its own processing on and off, and it has finished before the
  driver takes over. Engine nodes (AnimationPlayers, skeletons) now run after every script rather than between them,
  which moves nothing by more than a frame.
- **Not `Performance.TIME_PROCESS`.** On 4.7.2 it refreshes about once a second, so per-frame percentiles taken from it
  are the same few numbers repeated. A first trial showed this. The harness timestamps the start of processing itself
  (the driver, priority −100000) and its end (`scale_end_mark.gd`, priority +100000).
- **A fixed step rather than a 60 fps cap.** Under a cap, every fast frame reads 16.67 ms and the percentiles hide the
  work. Running uncapped with a real delta would hand the village a smaller step and change what it does each frame.
- **The songs fix is small and safe.** Its result is the same mark the per-resident scan computed, built once. It
  matches how `people_taps.gd _read_contexts` already reads the board.

## Consequences

- `--stress-residents` is a test mode. Clones share their original's interest, evening line and dialect, the
  inspector shows the original's first name, and chip colours repeat past eight. None of this matters for
  measurement, and none of it ships.
- The harness's numbers come from the editor binary (debug GDScript) on the development Mac, not from the
  qualification floor or a release export. Read them as relative scaling and as a ranking of hot spots, not as a pass
  or fail against REQ-SET-163.
- A future native or crowd-path change should be re-measured with `python3 tools/scale_test.py --out <dir>`. The suite
  keeps a 25-resident short run (`test_scale_stress.gd`) so the stress mode cannot rot.
- **An open defect the test found, not fixed here.** Once the kitchen has cooked, the demo holds a RefCounted cycle
  across the cast's space, the brains and the kitchen. The engine reports it at exit as "N resources still in use";
  `--verbose` lists cast_space, cast_nav, route_desk, resident_brain, kitchen, kitchen_task, meal_store and
  farm_pantry. If "Restart demo" does not break the cycle, every restart leaks a whole cast.
  `test_scale_stress.gd EXIT_LEAK` tolerates exactly that one engine line, pinned to its full text. Remove the
  tolerance when the cycle is broken. **Removed by decision 0998 (2026-10-02):** the cycle was broken (0922), the
  residual line was sounds still playing at quit, and the exit report must now be empty.
- **The harness's ORDER of the demo's scripts is the engine's, its TIMING is not.** The settlement clock runs on real
  host time (§4), and engine nodes run after every script. Neither moves the ranking. Both are stated in the
  performance note.

## Source

Brendan's approval of 2026-10-01 (the scale-test brief); REQ-SET-163 and CLAUDE.md's performance targets; decisions
0361, 0381, 0210, 0411, 0442 and 0491 for the systems measured; the measurements in the performance note.
