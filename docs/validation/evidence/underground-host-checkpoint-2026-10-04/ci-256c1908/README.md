# CI checkpoint 256c1908

[Run 37226172376](https://github.com/gradybre/redwall-rts/actions/runs/37226172376)
passed all14 jobs in16m24s including the initial queue and aggregate. The
unchanged verifier independently checked downloaded raw logs and reports:

```text
ok: 397 suite files executed exactly once across 8 shards
11027 test(s), 1020358 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1231 file(s)
```

`run.json` retains job outcomes and timestamps; all eight original manifests,
reports and raw logs are retained. `verified-shards.txt` records independent
aggregation. `analyzer-job.log.gz` preserves the original analyzer job log;
`analyzer-job.json` contains its decoded SHA-256 and byte length.

This qualifies the exact256c1908 approach/archive/inheritance corrections.
There is no same-head local full run, so no local/CI assertion equivalence is
claimed. The subsequent1153 phase refresh has separate focused evidence.

The run exceeded the15-minute target. Its weights still measured only240 of
397 suites, with newer files using the existing size estimate. Actual suite
times accumulated unevenly,259.609–817.081 seconds per assignment. Updating
only the timing table through the unchanged `weights` command estimates
439.877–439.879 seconds per shard from this same measured data. This is an
estimate, not a measured new wall time. `weight-refresh.json` records both
assignments' totals. Independent replay and continued discovery of unweighted
new tests are retained in
`../../underground-ci-timing-review-2026-10-04/`. No gate or count logic changed.
