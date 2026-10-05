# CI at8f6bad86 — failed checkpoint

Run37275141498 completed eight suite shards with410 files exactly once.
Their observed aggregate is **11,282 tests / 1,082,433 assertions / 3 failures**.
All failures are in `test_demo_profile_pack.gd`: the export verifier retained
nine Script consumers while the published short-step package requires ten,
and its positive test expected the previous profile image size. Decision1186
records the correction and focused verification. These failures are retained.

Every shard reports zero unexpected errors, warnings and object/resource leaks;
expected diagnostics total272, tolerated353. The failed shard reports:

```text
1861 test(s), 199898 assertion(s), 3 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 25 expected, 27 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

The analyzer reports `0 GDScript warning(s) in 0 of 1264 file(s)`.
All three metadata jobs passed. Specification contracts were cancelled at the
five-minute timeout after the memory/refusal checks passed; later checks were
skipped. Decision1185 records the independently reviewed hang-guard correction.
The overall run and aggregate are **not accepted**. `observations.json` is an
arithmetic/discovery audit of a failed run, not a substitute green report.

The exact raw artifacts and job/analyzer logs are retained beside this file.
