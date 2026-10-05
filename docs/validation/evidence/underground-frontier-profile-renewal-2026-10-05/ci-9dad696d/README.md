# Current-source renewal CI at9dad696d

Run[37259107677](https://github.com/gradybre/redwall-rts/actions/runs/37259107677)
failed two stale expectations in `test_underground_room_frontier_publication.gd`.
Both still expected `MOLE_CATALOG_SOURCE_DRIFT` after1170 independently reviewed
and renewed that exact source closure. All other seven shards, all four other
Godot gates and Specification contracts passed. The aggregate correctly fails;
no valid shard0 success report exists.

Original job metadata, failure log, analyzer log and all eight shard artifacts
are retained here. `observed-summary.json` reads the raw counters and verifies
that405 planned suite headers appear once. This is observation of the failed
run, not a successful aggregate gate or full local/CI equivalence claim.

Observed totals:11,207 tests /1,027,796 assertions /2 failures;0 unexpected
errors/warnings,272 expected,353 tolerated,0 leaked objects/resources. The
failing shard reports:

```text
1224 test(s), 57718 assertion(s), 2 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 211 expected, 8 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

The unchanged shell stops on failed assertions before its success raw footer.
The analyzer gate reports:

```text
0 GDScript warning(s) in 0 of 1250 file(s)
```

The fix changes only those two expectations and their scope text. Geometry,
payment, conservation, callback and source-hash refusal tests remain unchanged.
The corrected strict three-suite run is retained in`../frontier-test-renewal-1`:
37 tests /1,149 assertions /0; all diagnostic and leak counters0; analyzer0/3.
It does not rewrite the result of this failed CI run.
