# Rejected full checkpoint60f22f11 and corrected focused checks

The exact source/HEAD60f22f11e9665d6790cfdf49977b74e966c915aa stayed unchanged
through the clean import and no-argument full suite. Demo assets were absent
before and after; the private import cache was deleted.

```text
10321 test(s), 956324 assertion(s), 2 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
error: 2 failing test(s).
```

This run is rejected. The test failure causes run_tests.sh to exit before its
raw-log summary and the orchestration does not run the analyzer afterward.
Do not count this as a successful full checkpoint. Full suite time1281.784s.

Both failures are independently asserted stale1102 expectations: the canonical
test still requires schema2/768 loss entries, and the physical benchmark still
requires Funding2379776 bytes. The accepted fourth domain requires schema3,
1024 entries and2048 additional live bytes. Correction changes only four test
expectations/messages, preserving exact independent reflection, shape and order
checks. Construction independently accepted final exact test pins in
correction-focused/source-sha256.json. No production code or allowance changed.

Fresh clean import and the two explicit unchanged strict singleton shards yield:

```text
UG06_PACKED S=256 R=512 sites_bytes=65808 funding_bytes=2381824 total_bytes=2447632
50 test(s), 23926 assertion(s), 0 failure(s)
60 test(s), 4724 assertion(s), 0 failure(s)
```

Each corrected focused suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Both tests retain their original total test/assertion counts. The corrected
source requires a new clean no-argument full checkpoint and zero-warning analyzer.
The focused result is not a substitute.
