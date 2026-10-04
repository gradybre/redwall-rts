# Integrated checkpoint b6545647

Frozen source: `b65456478ff8fb6e9cc297384a747e58de7ff465`.
The exact clean-assets/cache/editor-import/no-argument suite/analyzer procedure
passed. Assets were absent and their state restored; sources and HEAD remained
unchanged. Reproduce using the existing `../checkpoint-499bfd73/reproduce.py`
with a fresh output directory. Exact commands, pins and unmodified logs remain
beside this record.

```text
10620 test(s), 976657 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1179 file(s)
```

Clean import took10.846 seconds, the full suite1343.047 seconds, and analyzer
240.197 seconds. All35 specification commands passed; their full commands,
outputs and results are in `docs/validation/evidence/underground-spec-b6545647`.
This closes the earlier957f03d analyzer rejection caused by a historical capture
script. That rejected run and the byte-preserving archive correction remain
retained; its warning was not tolerated or removed from an allowance.

[CI37175318873](https://github.com/gradybre/redwall-rts/actions/runs/37175318873)
passed all14 jobs in722 seconds (12m02s). Downloaded raw artifacts pass the
unchanged verifier:370 suite files executed exactly once across8 shards,
10620 tests,976649 assertions,0 failures,272 expected/353 tolerated diagnostics,
zero unexpected errors/warnings and zero object/resource leaks. Analyzer0/1179.

The local and CI test/diagnostic/leak totals match. The exact comparator still
**refuses equivalence** because CI has8 fewer assertions; command, exit1 and
raw refusal are retained in `ci-baseline-comparison.*`. No comparator was
weakened. The complete CI jobs and original per-shard artifacts remain here.

These checks cover the integrated components at this exact commit. They do not
qualify newer1115 shared-surface changes, paid first-prefix composition, source
INSTALL/stair turning, the complete playable room/furniture flow, persistence,
1280x720 acceptance or256-resident native timing/memory.
