# Actual-source checkpoint 4972a96d: CI

[Run 37288505753](https://github.com/gradybre/redwall-rts/actions/runs/37288505753)
passed all 14 jobs at `4972a96d03ec01f31f90f9b29ca63934812782ea`.
End-to-end time from the run timestamps was 906 seconds. The unchanged
exact-once verifier independently checked all 413 suite files against the
same source corpus and all eight downloaded raw shard logs.

```text
11293 test(s), 1082710 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1267 file(s)
```

Test and diagnostics totals are the eight real shard results summed by
`tools/ci_test_shards.py`. They are not a single-run claim. The original raw
logs, manifests and reports are flattened byte-identically under `reports/`.
Reproduce the audit from this checkpoint's source with:

```sh
python3 tools/ci_test_shards.py verify --reports docs/validation/evidence/underground-integration-checkpoint-2026-10-05/ci-4972a96d/reports --count 8
```

`run.json` records every step's result; `aggregate.json` retains all counters
and suite timings; `analyzer-job.log` retains the complete warning gate output.
Every specification, metadata and analyzer gate passed. No tolerance changed.

The matching [local clean-assets/cache/import/no-argument run](../full-4972a96d/README.md)
also passed, with the same 413 files, 11,293 named tests and every diagnostic/leak
total. Local has 10 more assertions; that delta remains unattributed, and exact
assertion parity is not claimed. See `local-comparison.json`.
This checkpoint includes the actual-source four-cube excavation fixture; it
is not complete paid stair handling, a playable empty Kitchen, persistence,
or measured 256-resident qualification.
