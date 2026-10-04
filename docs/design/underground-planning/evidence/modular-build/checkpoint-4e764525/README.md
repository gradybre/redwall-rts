# Integrated checkpoint 4e764525

Frozen source: `4e7645255c45fad5585120e232e375480319ed23`.
Reproduce the local run with the existing `../checkpoint-499bfd73/reproduce.py`,
passing a fresh output directory. The invocation, per-source SHA-256 pins and
unmodified logs are retained here. Assets were absent; cache was removed, editor
import completed, the no-argument suite ran, and the zero-warning analyzer ran.
Source, HEAD and asset state were unchanged at completion.

```text
10562 test(s), 967905 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1174 file(s)
```

Import took 10.825 seconds, the suite 1317.438 seconds, and the analyzer 261.231
seconds. All 35 specification commands passed; their commands and raw logs are
in `docs/validation/evidence/underground-spec-4e764525/`.

[CI run 37168842549](https://github.com/gradybre/redwall-rts/actions/runs/37168842549)
passed every existing gate and all eight shards, with 368 discovered suite files
executed exactly once. Its complete critical path was 736 seconds (12m16s).
The downloaded artifacts were checked against their raw logs with
`tools/ci_test_shards.py`; aggregate counters are in `ci-aggregate.json`.
CI ran 10562 tests / 967891 assertions / 0 failures, with the same diagnostics
and leak totals as the single local run. Its analyzer also reported 0/1174.

The exact assertion-equivalence comparator **refused** the 14-assertion delta;
`ci-baseline-comparison.txt` preserves that refusal. It has not been weakened.
Matching tests and diagnostics do not imply matching assertions.

These are integrated component tests. They do not close playable Kitchen,
complete room/furniture workflows, native 1280x720 acceptance, persistence, or
256-resident timing/memory qualification.
