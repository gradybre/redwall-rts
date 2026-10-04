# PR230 CI checkpoint at2f29ffd1

GitHub Actions run[37143315382](https://github.com/gradybre/redwall-rts/actions/runs/37143315382)
checks synthetic merge9dc8ac5091aa86e9d754019ee0c7e4b9ebba944b of head
2f29ffd121658a047e1887c1aff4eac9342bd8d7 into master82d60ba86dcecf6e7c6184eeaf77a389e8b2b5c2.
All eight strict shards, analyzer, three metadata gates, specification contracts
and the aggregate gate succeeded. Excerpts are retained verbatim with job/time
prefixes; checks.json records the returned check objects.

The aggregate verifies355 suite files executed exactly once across8 shards:
10249 tests,953898 assertions,0 failures;272 expected and353 tolerated
diagnostics;0 unexpected errors,0 unexpected warnings,0 leaked objects and
0 leaked resources. The slowest suite run was485seconds. Whole required-job
span was18:12:16–18:21:53UTC (9minutes37seconds, including setup and aggregate).
The analyzer excerpt supplies its exact warning/file count.

`baseline_matches:false` means this run supplied no single-run comparison
artifact; it is not a claimed equality proof for this head. The earlier local
no-argument full checkpoint remains independently pinned to3e891a41. Added
profile-path, claim and planar-contact tests explain why later counts differ.
Neither result closes the unimplemented playable requirements.

Reproduce aggregation evidence retrieval with
`gh run view 37143315382 --job 111263779315 --log` and analyzer evidence with
`gh run view 37143315382 --job 111262061649 --log`. Local integration testing
still uses the mandated assets/cache/import/full-suite procedure at assembled
milestones.
