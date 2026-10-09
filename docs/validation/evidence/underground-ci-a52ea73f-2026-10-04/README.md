# CI checkpoint a52ea73f — 2026-10-04

[Run 37219153939](https://github.com/gradybre/redwall-rts/actions/runs/37219153939)
passed all 14 jobs at exact commit
`a52ea73f9669637b5e32ba0747e302040466f787` in **13m49s**.

The unchanged shard verifier proves all **394 test files ran exactly once**
across eight shards: **10,973 tests / 1,019,025 assertions / zero failures**.
Totals: 272 expected and 353 tolerated diagnostics, zero unexpected errors or
warnings, zero leaked objects or resources. The analyzer reports:

```text
0 GDScript warning(s) in 0 of 1225 file(s)
```

`merged/` preserves the 24 original manifest/log/report files downloaded from
the eight shard artifacts. `verify.py` replays the unchanged verifier against
the exact tested commit's suite corpus. `run.log.gz` retains the complete raw
GitHub log with compressed and decoded SHA-256 pins in `log-archive.json`.
`run.json` records the commit, all job results and timestamps.

This checkpoint includes Session, host Gear/Carry and the Natural stair Clock.
It predates the ordinary Room publication and Approach changes. No full local
run at this exact head is claimed; `baseline_matches: false` means no same-head
baseline was supplied. The stricter comparator remains unchanged.
