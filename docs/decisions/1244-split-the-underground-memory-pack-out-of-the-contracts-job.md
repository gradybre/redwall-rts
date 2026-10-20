# 1244 — Split the underground memory pack out of the contracts job, in three shards
Date: 2026-10-20 · Status: Accepted

## Context

"Specification contracts" was cancelled at its 15-minute guard on master `1b71992b` (run 39360724357) and on PRs
#275 and #278. The cancellation also failed "Godot headless suite", which needs it. In that run the job's one step
"Joint underground allocation pack and refusal checks" took 13 min 13 s: `underground_memory_budget.py --check`
about 5 s, `test_underground_memory_budget.py` 285 tests in 765 s, `test_underground_current_census.py` 15 tests in
22 s. The other contract commands took about 1.5–2 minutes, so the job needed about 15.5 minutes. Under decision 1185
the same step took 4 min 32 s; it has roughly tripled in a fortnight.

Splitting by test class does not help: `JointPackTests` holds 234 of the 285 tests and nearly all of the time,
because each one rebuilds the whole pack.

## Decision

1. The step leaves the contracts job for a new job, `underground-memory` ("Underground memory budget shard N / 3"),
   a three-entry matrix with its own 15-minute guard. Shard 0 also runs `--check` and the census tests; every
   shard runs its third (95 tests) of the refusal tests. On this Mac, where the unsharded module took 390 s against
   the runner's 765 s (1.96x), the shards took 159 s (2 s `--check`, 143 s tests, 14 s census), 149 s and 152 s,
   which projects to about 5–5.5 minutes per runner job including checkout: about 63% headroom.
   The contracts job keeps every other command and its 15-minute guard and should take about 2 minutes.
2. `tools/unittest_shard.py` loads the unchanged test module exactly as `unittest.main()` does and runs the tests
   whose position in the sorted `Class.test_name` list is congruent to the shard index modulo the count. The shards
   are disjoint and exhaustive by construction, class fixtures still run once per class per shard, and a shard
   fails if it is empty, if any selected test does not run, or on any failure or error. No test or assertion
   changed. Its self-tests (`tools/test_unittest_shard.py`) run in the contracts job and also pin the workflow
   wiring.
3. The count comes from `strategy.job-total`, not a literal, so deleting a matrix entry redistributes its tests
   rather than dropping them.
4. "Godot headless suite" now needs `underground-memory` as well and requires its result to be `success`, so the
   same commands still gate a merge.

## Why

Decision 1185 raised the guard once; doing it again would only hide the next growth (the reasoning decision 1243
applied to the Godot shards). One parallel job of the unsharded step would run about 13.5 of 15 minutes, about 10%
headroom; two shards would leave about 50%, three about 65%, which buys room for the growth rate above.

## Consequences

- Three more cheap runner jobs per push (no engine, no LFS; about 15 s of checkout each).
- When any shard passes about 10 minutes, add a matrix entry. Do not raise the guard.
- Check names: "Specification contracts" and "Godot headless suite" are unchanged; three new checks appear. The
  repository had no branch protection or rulesets on 2026-10-20, and `tools/auto_merge.py` reads every check in
  the PR's rollup, so no GitHub setting needs to change. If "Godot headless suite" is ever made a required check
  it already covers the new jobs.
- Locally, nothing changes: `python3 tools/test_underground_memory_budget.py` still runs all 285 tests.

## Source

CI run 39360724357 (job 118426020800 log timings); decisions 1185 and 1243; local runs of the new job's exact commands at `1b71992b` + this change, sequential, on Brendan's Mac; the
union of the three shards' ids equals the 285 ids the unsharded run reported.
