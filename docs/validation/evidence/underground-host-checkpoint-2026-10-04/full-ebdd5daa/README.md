# Retained failed full checkpointebdd5daa

The clean-cache/import/no-argument full suite on ebdd5daa2b723a63dd71e2018d2bed9b279cf894 reproduced the same nine outdated support-clearance fixture failures as CI. This result was not accepted or rewritten. The corrected fixture and its independent review are in `../support-clearance-v3-2/` and commit6da6deb9.

```text
11156 test(s), 1026346 assertion(s), 9 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
error: 9 failing test(s).
```

Full suite elapsed1868.570 seconds. Clean import passed; no analyzer ran after the failed suite. Source and HEAD stayed unchanged; project settings and asset presence were restored. See `invocation.json`. Original logs are losslessly compressed with original and archive SHA256s.

All402 suite files,11156 tests, failure count and diagnostic/leak totals match failed CI37250182343. Local assertion total is11 higher than CI1026335; the cause remains unattributed. The strict all-counter comparison was not weakened and exact equality is not claimed.
