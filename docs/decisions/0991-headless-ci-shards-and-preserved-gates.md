# 0991 — Shard headless CI and preserve every gate
Date: 2026-10-02 · Status: Accepted

## Decision

Run the existing Godot suite in eight file-level shards, and its existing
non-suite gates in four independent groups. Keep **Godot headless suite** as
the required aggregate check: it requires every shard, gate group and
specification-contract job to succeed, then audits the executed suite files.

`./tools/run_tests.sh` without arguments keeps its full-suite behavior.
`--shard INDEX/COUNT --output-dir DIR` opts into sharding, retaining the same
registry preflight, runner supervisor, nonempty test requirement, assertion
failure check, zero unexpected diagnostics and zero leaked objects/resources.
No production or `godot/test/` file changes are needed. A runner subclass under
`tools/` selects suites and records per-suite completion times.

## Why

[CI run 37001196751](https://github.com/gradybre/redwall-rts/actions/runs/37001196751)
took 58m28s. Its suite used 27m58s, analyzer 6m24s, and remaining gates about
23m30s. Sharding only the suite leaves a half-hour bottleneck. The three
metadata groups divide those measured gate durations into approximately eight
minutes each; the analyzer runs independently. The wall-clock target is 15
minutes, with 30-minute per-job timeouts retained as hang guards rather than
claims of measured performance. Hosted timing still depends on runner speed
and job queueing.

Suites are the sorted direct `godot/test/test_*.gd` files, matching the inherited
runner's discovery. Deterministic longest-estimate-first allocation uses
measured timing weights; new files receive a source-size estimate and are
automatically included. Timing estimates affect placement only. They can never
exclude a test. Whole-file selection preserves suite setup and teardown.

Both the complete allocation and actual execution must cover every discovered
file exactly once. Each shard uploads its manifest, raw log and audited counts.
The aggregate rejects absent, duplicate, empty or inconsistent results and
cross-checks JSON against raw logs. Local equivalence validation also compares
all test/assertion counts and expected/tolerated/unexpected/leak diagnostics
with a full single run; zero unexpected diagnostics alone is insufficient.

## Consequences

The original standalone engine gate commands remain unchanged and each runs in
exactly one gate group. The analyzer still uses `gdscript_warnings.py --max 0`. Matrices use
`fail-fast: false` to retain evidence from other groups when one fails.
The aggregate uses `always()` and explicitly rejects failed, cancelled or
skipped prerequisites, preserving the existing branch-protection check name.

Each engine job retains the existing LFS checkout, pinned Godot 4.7.2 binary
cache and project import. This duplicates setup work across isolated runners;
the measured original setup was about 31 seconds, while sharing a mutable
`.godot` cache would add correctness risk. Shards never run concurrently against
one project's user-data directory in CI. Local validation uses a temporary
`override.cfg` with a unique user-data name, restored in `finally`, and no staged
demo assets.

Refresh estimates from a successful artifact set with
`python3 tools/ci_test_shards.py weights --reports DIR --count 8 --output tools/ci_test_shard_weights.json`.
The exact-once checks and raw-log evidence remain mandatory after rebalancing.

Local validation on `d07dabb7` proved identical coverage of 240 files and 7,974
test methods, with 268 expected and 353 tolerated diagnostics and zero failures,
unexpected diagnostics or leaks. The weighted shards took 103.678–113.548 seconds
each locally; hosted timing remains a separate PR measurement. All 38 other
existing gate steps and the zero-warning analyzer passed.

Assertion totals are scheduling-dependent in an existing test, and are not
claimed equal: the original full pass reported 577,345, a second instrumented
full pass 577,344, and weighted shards 577,346. The second full/sharded comparison
isolates the difference to `test_demo_lens_kit.gd`, whose
`test_a_trace_is_sliced_and_the_old_outline_stays_until_done` asserts on each
one-microsecond `contours.step(1)` slice. `lens_contours.gd::step()` uses wall-clock
microseconds. All other 239 suite counts match. The strict optional
`--baseline-log` check still rejects this assertion difference; the evidence
separately proves the required equal test-method coverage and diagnostic totals.
No test, diagnostic allowance, leak allowance or existing gate was changed.

Before publication, the branch was rebased onto B7 merge `d75d9d89`. Its 35 new
suite files are included automatically, and its two additional contract commands
are preserved. Hosted run `37006524569` supplies a full baseline of 275 files,
8,644 tests, 268 expected and 353 tolerated diagnostics with no failures,
unexpected diagnostics or leaks; its game tree is identical to that merge.
The PR compares the hosted shards with this baseline separately from the pinned
local calibration above.

## Source

Brendan's CI-sharding task; the existing runner contract and decision 0501;
the measured hosted run above; executable fault tests in
`tools/test_ci_test_shards.py`; validation evidence in
`docs/validation/evidence/ci-shard-2026-10-02/`.
