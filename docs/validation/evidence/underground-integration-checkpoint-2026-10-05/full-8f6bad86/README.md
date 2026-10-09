# Frozen 8f6bad86 full local checkpoint

FAILED and retained. Clean import completed, then the unchanged no-argument full suite reported:

```text
11282 test(s), 1082441 assertion(s), 3 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

The three failures are the same obsolete nine-consumer export-verifier failures observed in CI; correction53541c91 is not part of this frozen candidate. The analyzer was not started after the strict suite failure. All tracked sources, original project, assets, existing sidecars and HEAD were restored/unchanged, as recorded in invocation.json. The 410 suite names and 11,282 cases match CI; CI asserted1,082,433 versus local1,082,441. No exact assertion equivalence is claimed and no gate is relaxed.
