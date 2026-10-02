# CI sharding validation — 2026-10-02

Source commit: `d07dabb7629be8a7721b87fdd5b9532e3568a963`.
Engine: `4.7.2.stable.official.ed1daf0bf`, macOS Apple Silicon.
Only CI/tools, decision 0991 and this evidence directory change. Production
scripts and the 240 existing suite files remain unchanged.

## Full baseline

`godot/demo/assets/` was absent. Removed only this worktree's `.godot/`, imported
with `godot --headless --path godot --editor --quit`, then ran the original
`./tools/run_tests.sh` before editing the wrapper. A temporary `override.cfg`
selected a unique user-data directory and was removed in `finally`; no shared
Godot user-data was changed. Import took 4.122 seconds; tests took 783.548 seconds.

```text
7974 test(s), 577345 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`baseline-run.json` records commands, exit codes, timing and runtime cleanup.
`baseline-summary.json` records independently parsed counts and the sorted
suite-list digest. The auditor also checked the raw expected/tolerated lines
against the reported diagnostic counts.

## Weighted shards and exact method coverage

The final eight shards execute all **240 files exactly once** and the identical
**7,974 test methods**. Expected diagnostics remain **268**, tolerated diagnostics
**353**, and failures, unexpected errors/warnings, and object/resource leaks are
all **0**. `required-equivalence.json` compares every per-suite method list and
every required test/diagnostic counter with the original single run. A separate
review independently confirmed the method-list SHA-256
`2ceb1be606ccbfd53545350cb1f260cd379f72ad96ecdf8b8c01811f5788c66c`.

The initial allocation provided timing weights; the final measured allocation
ran in private project copies with a fresh import and unique user-data name
per copy. At most **three shards ran concurrently alongside one full diagnostic
run**, keeping local test concurrency at four. Shards took **103.678–113.548
seconds**, with imports of **4.312–4.963 seconds**. The entire local three-worker
batch, including import/setup, took **346.630 seconds**. These are local timings,
not a hosted eight-worker wall-clock measurement. `weighted-run.json` retains
each timing and `weighted-summary.json` the audited aggregate.

**Assertion totals are not claimed equal.** The original full run made 577,345
assertions, the initial shards 577,344, the instrumented full run 577,344, and
the final weighted shards 577,346. The instrumented comparison isolates the
entire difference to `test_demo_lens_kit.gd`: 34 methods in both runs, with
211 versus 213 assertions. All other 239 suite counts match.

The existing `test_a_trace_is_sliced_and_the_old_outline_stays_until_done`
([test source](../../../../godot/test/test_demo_lens_kit.gd#L325)) asserts once
per `contours.step(1)` iteration. `step()` budgets against `Time.get_ticks_usec()`
([implementation](../../../../godot/demo/lenses/lens_contours.gd#L137)), so the
number of one-microsecond slices—and therefore assertions—varies with scheduling.
This changes neither method coverage nor diagnostic totals. No test changed,
no allowance was raised, and the optional `--baseline-log` comparison remains
strict: it correctly rejects the differing assertion totals. See
`assertion-investigation.json` and `instrumented-comparison.json`.

The instrumented full pass took **797.284 seconds** and passed every gate in the
test wrapper. All temporary overrides and runtime project copies were removed
after their processes completed; `cleanup.json` verifies this and confirms that
the protected game/test paths remain unchanged.

## Guards and unchanged gates

`tool-validation.json` records the original gate commands and their one group
each. Every original gate command is unchanged, the contracts job is unchanged,
and the required check name remains **Godot headless suite**. Its `always()` job
fails on a failed, cancelled or skipped shard/gate/contracts prerequisite.

`python3 tools/test_ci_test_shards.py --godot` passed all 17 tests in 11.942
seconds. The faults cover absent/duplicate/unknown/empty suite allocation,
invalid shard indices, added tests missing from an old manifest, missing/extra
reports, altered counters, mismatched raw execution, missing summaries,
misclassified diagnostics and baseline counter divergence. Actual Godot fixture
runs prove full/sharded equality, inherited handling of expected/tolerated
diagnostics, and failure on an unexpected warning, an aborted test and a leak.
The new runner subclass is also checked through the real GDScript analyzer in
a disposable project; the regular analyzer only scans `godot/`.

The full existing `gdscript_warnings.py --max 0` gate passed with **0 warnings in
816 files**, in 185.331 seconds. It used a separate editor-project copy and an
unused LSP port to avoid other agents' editors. See `analyzer-run.json` and
`analyzer-diagnostics.json`. All **38 other existing gate steps** replayed
successfully; `gates-run.json` records commands, durations and exit codes.

## Hosted baseline for the later B7 merge

Master advanced while local validation was pinned to `d07dabb7`. The preserved
[B7 hosted full run](https://github.com/gradybre/redwall-rts/actions/runs/37006524569/job/110835991389)
at `4eb8e3c04669cbfdcc14460502502a2ded6763f0` has the same game tree as its merge
`d75d9d89d7a7b08fc2dac1de2c50567ea66b0b77`. It ran **275 files**, **8,644 test
methods**, **589,136 assertions**, **268 expected** and **353 tolerated**
diagnostics, with every failure/unexpected/leak counter at **0**. The job took
**54m38s** and its suite **29m46s**. `hosted-b7-baseline.json` records the exact
method-list digest for comparison with the rebased PR's hosted shard artifacts.
This later baseline does not replace or relabel the pinned local measurements.

The CI branch was rebased onto that merge before publication. The contracts job
is byte-identical to the new base, including both B7 report self-tests (18 balance
tests and 28 soak tests, both passing). All 24 original engine gate commands
remain unchanged and occur once each. The allocation automatically includes all
35 new B7 suite files, for 275 files total. No protected game/test file or existing
decision changed. `rebased-validation.json` records those integration checks.

## Reproduction and retained evidence

Run each shard in its own checkout/import/user-data environment, as CI does:

```bash
godot --headless --path godot --editor --quit
./tools/run_tests.sh --shard 0/8 --output-dir artifacts/test-shards
# Repeat indices 1 through 7 in their isolated jobs, then merge the artifacts.
python3 tools/ci_test_shards.py verify --reports artifacts/test-shards --count 8
```

For an equivalence check on the same source and asset state, save the output
of a full `./tools/run_tests.sh` and append `--baseline-log full.log` to the
verify command. That compares tests, assertions, failures, expected and tolerated
diagnostics, unexpected errors/warnings, and object/resource leaks.

Raw local logs and per-shard artifacts stay available locally but are ignored
by this directory's `.gitignore`; the compact JSON records are committed. CI
uploads raw logs, manifests and audited reports for 14 days, including failed
shard logs. `hosted-before.json` records the original hosted job's step timings.
Hosted wall-clock time for this change remains to be measured by its PR run;
local timings are not a claim about hosted runners or queue latency.
