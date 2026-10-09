# CI checkpoint at32db348a — 2026-10-04

[Run37208054867](https://github.com/gradybre/redwall-rts/actions/runs/37208054867)
completed successfully at exact PR head
`32db348a1a8473461f832cc2b06b410aa97c898a`. Every one of the14 jobs passed.
The complete workflow took11 minutes34 seconds, including the original
Specification and all four Godot gate groups. The slowest suite shard took539
seconds; the unchanged full analyzer reported:

```text
0 GDScript warning(s) in 0 of 1210 file(s)
```

The downloaded eight raw shard logs, reports and manifests are retained under
`merged/`. The unchanged verifier re-read these logs and the exact checked-out
corpus:388 suite files executed exactly once. Aggregate totals are10,895 tests,
998,359 assertions and zero failures;272 expected and353 tolerated diagnostics,
zero unexpected errors or warnings, and zero object/resource leaks. Every shard
also has a zero raw-log diagnostic/leak footer. `aggregate.json` is the locally
reproduced result. No allowances or gates were changed.

`run.json` records exact source, job/step status and times. `run.log.gz` is the
lossless complete GitHub log; `log-archive.json` records original bytes/hash and
the archive hash. The downloaded artifact folder structure was flattened only
after comparing every file byte-for-byte; no raw report or log was discarded.

Reproduce the exactly-once audit at this source with:

```sh
python3 tools/ci_test_shards.py verify --reports docs/validation/evidence/underground-ci-32db348a-2026-10-04/merged --count 8
```

The same-head clean no-argument run passed10,895 tests/998,370 assertions.
All388 suite files and all10,895 passed test-case names match, as do every
diagnostic and leak total. Assertions differ by11; the unchanged strict
all-counter comparison exits1 and refuses equivalence (`exact-comparison.log`).
The no-argument output has no per-suite assertion counters, so this difference
is not attributed. `full-comparison.json` retains the comparison without
weakening any check. These passing component regressions do not establish
playable underground completion.
