# CI checkpoint6da6deb9

Run37251846477 completed successfully on the exact corrected commit6da6deb952ebfce5d748563c1c1166f0f6b15dd3. All14 jobs passed. Downloaded original shard reports and raw logs were independently passed through the unchanged `ci_test_shards.aggregate`, using the frozen same-commit qualification checkout for discovery:402 suite files, exactly once across8 shards.

```text
11156 test(s), 1026355 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1243 file(s)
```

Those totals are the eight-shard aggregate, not a claim that the single-run summary printed them. Shard execution times:537,493,419,428,337,470,610,528 seconds. Original reports/manifests and the analyzer job log are retained. Lossless gzip logs have compressed and decoded hashes in `log-archives.json`. The [same-commit no-argument full run](../full-6da6deb9/README.md) passed11,156 tests/1,026,365 assertions with the same402 files, exact named test-case set and diagnostic/leak totals. Local assertions are10 higher; cause unattributed and strict all-counter equality is not claimed. Neither run qualifies later-source changes.

Run: https://github.com/gradybre/redwall-rts/actions/runs/37251846477
