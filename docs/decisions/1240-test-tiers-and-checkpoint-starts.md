# 1240 — Fast and slow test tiers, and checkpoint starts for long chain tests
Date: 2026-10-08 · Status: Accepted

## Brendan's decision

> Speed up test turnaround with (1) fast/slow test tiers and (2) checkpoint test starts. (chat, 2026-10-08)

(1240, not 1237: numbers 1237-1239 were left to the stairs lane, which was writing records at the same time.
Gaps are allowed; see `docs/validation/decision_numbers.py`.)

## Measured

One complete run on this Mac at `6cc169f9` (load average about 3; `--shard 0/1`, so every suite's
`CI_SUITE_TIME` was recorded): **3,881 s wall, 3,874 s of suites, 11,713 tests, 0 failures, clean log.**

| Suite | s | | Suite | s |
|---|---:|---|---|---:|
| test_underground_host | 745 | | test_settlement_save_underground | 120 (250 at `686b948c`, ten checkpoints) |
| test_settlement_save_parity | 575 | | test_save_underground_columns | 106 (6 after this record) |
| test_underground_paid_assembly_handling | 360 | | test_underground_connector_delivery | 74 |
| test_demo_care_live | 165 | | test_underground_entry_world_bindings | 62 |
| | | | test_underground_connector_workpieces | 61 |

Next below 60 s: test_demo_camera_live 42, test_underground_workpiece_spatial_lifecycle 41. Twenty-one suites exceed
30 s (2,705 s together).

## Decision

### 1. Tiers

- The slow tier is a declared list, `godot/test/slow_suites.json` (suite -> measured whole seconds, threshold 60 s),
  read by `tools/ci_test_shards.py tier fast|slow`. A list in one JSON file, not a marker inside each suite, because
  both the GDScript runner and the Python shard planner already select suites by name
  (`REDWALL_TEST_SHARD_SUITES`), and a marker would mean loading every suite to learn its tier.
- `./tools/run_tests.sh --fast` runs every other suite, `--slow` only the list; both go through the same runner and
  the same zero allowances. The default run and CI are unchanged: CI's eight shards run every suite.
- The plan and both tier commands refuse a list naming a suite that does not exist, so a renamed slow suite fails
  CI instead of silently joining the fast tier.
- Shard weights (`tools/ci_test_shard_weights.json`) are re-measured from the same run (they were CI timings for
  397 of 457 suites). `test_underground_host` alone (745 s) bounds an 8-shard run's wall time.
- Guidance (docs/ENVIRONMENT.md, "Test tiers"): per commit `--fast` plus focused `--suite` runs; the complete run at
  milestones, before merges and in CI.

Result, measured at `cda8d64f` on this Mac: `./tools/run_tests.sh --fast` ran 450 suites (11,578 tests, 0 failures,
clean log) in **1,580 s wall (26 min) against 3,881 s (65 min) for the complete run, 2.5x faster**.

### 2. Checkpoint starts

- A checkpoint is a recipe's state saved once by `test/generate_checkpoints.gd`
  (`./tools/regenerate_test_checkpoints.sh [name]`) and committed under `godot/test/fixtures/checkpoints/`: the exact
  save bytes gzipped per named point, plus a manifest. The save format stays uncompressed (DEC-055); the gzip is
  only the fixture's container. A 67 MB mounted save is 0.33 MB.
- The manifest's **source fingerprint** is the SHA-256 of the engine version, the name, and every `res://` file
  reachable from the recipe's roots through quoted `"res://..."` literals (preloads, loads, data and scene paths; a
  literal with a placeholder or a trailing `/` stands for its whole directory). The roots are the recipe script and
  the GameManager autoload; the UI, economy and entity autoloads are left out because nothing in `scripts/core` or
  `settlement_system.gd` names them (238 files, no UI). A checkpoint whose fingerprint differs is **refused** with
  the changed files and the regenerate command; it is never used stale and never silently replaced by a replay.
- `test_checkpoint_store.gd` (fast tier) fails as soon as a committed checkpoint is stale, so a per-commit run says
  so first. `test_checkpoint_equivalence.gd` (slow tier) replays every recipe from tick 0 and requires each point
  to be byte-identical to its file, and to load into a fresh settlement and resave identically. That proof also
  covers what the literal walk cannot see (a path assembled at run time).
- One recipe, `underground_entry`: the live entry chain driven by the GameManager autoload as the settlement save
  suites drive it, saved at `first_install` (tick 2298) and `first_brace_after_2000` (tick 2574); about 30 s.
- Converted: `test_save_underground_columns` (replayed the chain in each of four `before_each`: 106 s -> 6 s) and
  `test_save_installed_geometry` (25 s -> 1.6 s).

### Not converted, and why

- `test_settlement_save_parity`: its prologue (generated settlement to tick 3000) replays in 1.7 s, no more than a
  load. Its 575 s are the uninterrupted 15,000-tick reference run and the reloaded runs it compares against, which
  are the test itself.
- `test_underground_host`: its long tests assert properties of the whole run from tick 1 (the finishing tick 8,348,
  "never returns to M" over every tick, restores every 11 ticks). Starting mid-chain would drop exactly what they
  prove. They also drive `run_tick` directly, not through a clock a save could record.
- `test_settlement_save_underground`: its goal test's second half (load at each of ten checkpoints and run on) is
  the property; only its uninterrupted half could come from files, and that replay would move into the equivalence
  test (net about 30 s for CI, 3.6 MB of checkpoints). Not worth it.
- `test_underground_paid_assembly_handling`, connector delivery/workpieces, entry world bindings: harness worlds,
  not settlements, so the settlement save cannot checkpoint them.

## Consequences

- **Every change to a fingerprinted source stales the checkpoint.** 64 of the last 100 commits on this line touched
  one of the 238 files. The fix is one ~30 s command; when the simulation did not move before the saved ticks (as for
  `686b948c`), the gzip members are byte-identical and git stores nothing new but the 30 KB manifest. When it did,
  each regeneration adds about 0.66 MB to history. If that grows too large, the alternative is an uncommitted cache
  keyed by the same fingerprint (rebuilt on first use after a change), at the cost of one replay per CI shard.
- A new recipe must earn its keep: a replay much longer than a load, used by more than one test, at a point the
  tests need only the state of (not the path to it).

## Source

Brendan, chat 2026-10-08; measurements above; `tools/ci_test_shards.py`, `godot/test/fixtures/checkpoint_store.gd`.
