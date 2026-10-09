# Corrected frontier fixture CI — ae3c61e7

[Run 37260574688](https://github.com/gradybre/redwall-rts/actions/runs/37260574688)
is green at exactly `ae3c61e73bed2619a2b711bad62d461425320c53`.
All 14 jobs passed. The unchanged aggregate verified every one of 405 discovered
test files exactly once across eight shards; no missing or duplicate allowance.
The complete run took 861 seconds (14 minutes 21 seconds). This precedes the
later 1167 route composition source integration.

Aggregate, quoted from the successful CI aggregate job:

```text
11207 test(s), 1027795 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1250 file(s)
```

Each shard also has a zero raw-error/warning/leak footer; the original raw logs
are losslessly compressed beside their complete JSON reports and manifests.
The full aggregate/analyzer job logs, run/job metadata, original artifact files
and content hashes are retained. `summary.json` copies the real aggregate output,
with the exact commit, run and elapsed time added.

The preceding unchanged local 9dad full run executed the same 11,207 tests and
same expected/tolerated totals, but had the two documented stale expectations
and 1,027,804 assertions. This is not an exact full-versus-sharded assertion
comparison: the local and CI assertion totals differ by nine and the former
commit deliberately still had failing fixtures. The strict comparator remains
unchanged. No full no-argument run or whole-game acceptance of later source is
claimed by this evidence.
