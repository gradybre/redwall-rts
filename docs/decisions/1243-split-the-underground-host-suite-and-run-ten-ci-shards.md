# 1243 — Split test_underground_host into three suites, and run CI on ten shards
Date: 2026-10-09 · Status: Accepted

## Context

PR #241's first CI run (37899240377, at `468e2edd`) cancelled "Godot suite shard 0 / 8" at the 30-minute job
guard. The plan (decision 1240's weights) had given shard 0 one suite, `test_underground_host.gd` (745 s on the
Mac at `6cc169f9`). Its suite step ran 1,699 s on the runner and had not finished: a suite cannot be divided
between shards, so this one alone bounded the run, and it no longer fit.

Measured alone on the Mac at `468e2edd` it now takes **1,002 s** (54 tests, 98,352 assertions). Five tests are
three quarters of it: the crew lost in each of seven installation stages (266 s), the whole entry restored along
the way (217 s), the descent to the sill (104 s), the entry restored every tick (82 s) and the crew lost while
handling (76 s); six more run about 38 s each; the other 43 are under 3 s.

From the same run's shard reports, the runner took a median 2.23x the Mac's time per suite (92 suites over 5 s,
range 1.06x to 3.19x); the cancelled suite was at least 1.7x. Shard 6 already ran 1,025 s at eight shards.

## Decision

1. **Three suites, one fixture.** The shared host fixture (inner classes, constants, `before_each`/`after_each`,
   and every helper more than one suite uses) moves to `godot/test/underground_host_case.gd`, which is not a suite
   (no `test_` prefix). Three suites extend it:
   - `test_underground_host.gd`: the 49 host-lifetime and short live-chain tests (257 s);
   - `test_underground_host_crew_loss.gd`: the two crew-loss chains (342 s);
   - `test_underground_host_whole_chain.gd`: the entry restored every tick, the descent, the whole entry
     restored (401 s).
   Each test's text is unchanged; helpers used by only one suite moved with it. Together they still run 54 tests
   and 98,352 assertions. `test_entry_worker_view.gd`, which used the old suite only as a fixture, now preloads
   `underground_host_case.gd` instead of instantiating a whole suite.
2. **Ten shards.** With the split, eight shards plan to 575 s locally each, which projects to about 1,150 s of
   tests on the runner (19 min plus about 2 min of setup) and about 1,525 s if the underground suites run at the
   slowest observed 3.19x: too close to the 30-minute guard. Ten shards project to about 900 s typical and
   1,280 s worst, back near the 15-minute target. The guard stays at 30 minutes; raising it would only hide the
   next growth.
3. Weights and the slow tier carry the three measured times (`tools/ci_test_shard_weights.json`,
   `godot/test/slow_suites.json`).

## Also fixed in the same run

metadata-a and metadata-b failed in `tools/test_buildings_allocation.py` and `tools/test_construction_allocation.py`
before running a case: each mutates the one `Columns.new(false)` line its probe reaches through `framed_refusal()`,
and the joint-bridge `apply()` bodies (d13ce3fe, a6003924) added a second, identical line. The needle now includes
the `return preflight` line before it, so it still names exactly the probed constructor; both discriminators again
show baseline PASS, the default-constructor mutant FAIL with `ALLOCATION_EXTRA_OWNER`, and restored PASS.

## Consequences

- Two more runner jobs per push (each about 2 minutes of checkout, LFS and import).
- When a live-chain test is added, put it in the suite that keeps the three nearest balance, or a fourth one;
  re-measure with `--suite` (`CI_SUITE_TIME`) and update both JSON files.

## Source

CI run 37899240377 (job logs and shard reports); local `./tools/run_tests.sh --suite` runs at `468e2edd`
(per-test times from a temporary, uncommitted timer in the worker); the caller's task for PR #241.
