# CI checkpoint 84acf740

[Run 37228134131](https://github.com/gradybre/redwall-rts/actions/runs/37228134131)
passed all 14 jobs in **13m23s**, including initial queue and aggregate.
It includes ordinary phase refresh 1153 and the reviewed measured-weight
refresh. All 398 suite files ran exactly once across eight shards.

The unchanged verifier independently read the eight downloaded manifests,
reports and raw logs. Their aggregate is:

```text
11043 test(s), 1021242 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

The full analyzer job reported:

```text
0 GDScript warning(s) in 0 of 1232 file(s)
```

`verified-shards.txt` retains the actual aggregate JSON and exact-once check.
`run.json` records every job and timestamp. The complete analyzer job log is
losslessly compressed, with decoded SHA-256 and byte length in its JSON sidecar.
The eight manifests, reports and raw shard logs are unchanged downloads.

Suite-runner wall times were 374–572 seconds; the longest entire shard job was
11m08s. The final limiting job was metadata-b at 12m57s; all its existing steps
remain mandatory. The preceding complete run took 16m24s. This observed run
meets the 15-minute target; it is not a guarantee for every future runner.

A same-head clean-import/no-argument full run is now running in the root-owned
checkpoint worktree. Its outcome and local/CI count comparison are not yet
available. The verifier therefore records `baseline_matches: false`; no
same-head full-run equivalence is claimed here. The independently developing
1152/1154 candidates and the new source/host-retirement packets are outside this
exact checkpoint. No playable Kitchen or whole-system qualification is implied.
