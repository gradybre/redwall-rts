# Full local checkpoint — 84acf740

The isolated own worktree `redwall-rts-codex-ug-checkpoint-host-20261004`
remained at `84acf74036484bd8ec4930895b7d0a96f8567937` throughout this run.
The committed wrapper required that exact commit, isolated Godot's user data,
verified source hashes, removed `godot/.godot`, ran the clean editor import,
then the unchanged no-argument `./tools/run_tests.sh` and entire analyzer with
`--max 0`. Demo assets were absent initially; asset presence and the original
project were restored. `invocation.json` records every command and check.

```text
11043 test(s), 1021246 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 11043 tests, 1021246 assertions, 0 failures.
0 GDScript warning(s) in 0 of 1232 file(s)
```

The suite took 1,809.017 seconds (30m09s); import, suite and analyzer together
took 2,098.983 seconds (34m59s). The analyzer's retained log records an editor
connection reset after 129 files and its supported restart before completing
all 1,232 files. The final result was zero warnings, not a partial scan.

## Same-head comparison with eight CI shards

[CI run 37228134131](https://github.com/gradybre/redwall-rts/actions/runs/37228134131)
passed all 14 jobs in 803 seconds (13m23s). The unchanged shard verifier and
raw-log parser confirm that both runs execute all 398 files exactly once,
with 11,043 tests and identical failure, diagnostic and leak totals.

CI recorded 1,021,242 assertions; local recorded 1,021,246. The difference of
four remains unattributed. Default local output has no per-suite assertion
counters. The unchanged all-counter comparator rejects exact equality, and
`same-head-comparison.json` retains its full refusal. No gate, allowance,
assertion or comparator has been changed to conceal the difference.

These results validate this exact checkpoint. Later access-editor and other
changes require their own complete CI and appropriate integration checks.

## Retained bytes

The three raw logs are losslessly compressed as `.log.gz`; the other original
JSON outputs are copied unchanged. `archive-sha256.json` records each original
filename, decoded byte count and SHA-256. Decompression was checked against
every original byte before recording this checkpoint. The unchanged source
manifest and restoration flags remain available alongside the logs.
