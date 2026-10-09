# CI checkpoint b03fbc2b

[Run 37223870212](https://github.com/gradybre/redwall-rts/actions/runs/37223870212)
finished in 13 minutes 18 seconds. The overall result is **failed**: all eight
test shards, three metadata jobs and Specification contracts passed, but the
zero-warning analyzer failed and the aggregate correctly failed with it.

The original b03 test-sharding verifier independently checked the downloaded
reports and logs against that exact commit's corpus:

```text
ok: 396 suite files executed exactly once across 8 shards
```

Summing those strict reports gives:

```text
11000 test(s), 1019572 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

`verified-shards.txt` retains the verifier output. `run.json` records every
job's actual outcome. This was not a successful complete milestone.

The analyzer reported:

```text
12 GDScript warning(s) in 6 of 1235 file(s)
```

All twelve are integer-division warnings in historical rejected native capture
snapshots v1–v6. `analyzer-job.log.gz` preserves the unmodified job log and
`analyzer-job.json` records its decoded-byte SHA-256. The active capture and
accepted v7 source are clean. The correction stores those six historical
snapshots losslessly as data, with their original expected hashes and extraction
instructions; no warning threshold, diagnostic rule or executable source
changes. A subsequent all-project analyzer is required to verify the correction.

The [same-head clean-import/no-argument local run](../full-b03fbc2b/README.md)
has completed. It passed 11,000 tests / 1,019,580 assertions with the same
diagnostic/leak totals, then failed the same historical-source analyzer warnings.
Its original source and HEAD stayed unchanged; assets and project were restored.
All 396 suite files and test/diagnostic totals match CI. Local assertions are
eight higher; the no-argument runner did not retain per-suite assertion counts,
so that difference remains unattributed. The unchanged all-counter verifier
refuses exact equality; `../b03-test-comparison.json` retains its refusal.
