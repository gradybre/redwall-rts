# Full actual-source checkpoint 4972a96d

The owned frozen qualification worktree executed the exact integrated source
`4972a96d03ec01f31f90f9b29ca63934812782ea` with optional demo assets absent,
deleted its own `.godot` cache, performed a clean editor import, and ran the
unchanged no-argument `./tools/run_tests.sh`. The full all-file analyzer and
decision, memory, registry and queue checks followed.

```text
11293 test(s), 1082720 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1267 file(s)
```

The full suite took 1,957.878 seconds and executed all 413 files. Import and raw
analyzer diagnostics were empty. Every invoked check returned success.
`invocation.json` records source/HEAD, project, assets, override and original
import-sidecar restoration; the qualification worktree has no tracked changes.
All 8,941 recorded source inputs match before and after. The evidence was copied
byte-identically into the integration worktree after the process finished.

[Same-commit CI](../ci-4972a96d/README.md) passed all 14 jobs, all 413 files
exactly once across 8 shards, and the same 11,293 named tests and every diagnostic
and leak total. CI reports 1,082,710 assertions, ten fewer than local. The
no-argument local runner does not emit per-suite assertion counters; the delta
remains unattributed. No exact assertion parity, normalization or waived gate
is claimed. The comparison is retained in `../ci-4972a96d/local-comparison.json`.

This qualifies the committed actual-source excavation fixture and its existing
regressions. It does not qualify paid timber handling under development, demo
worker dispatch, a completed empty Kitchen, save/resume or 256-resident runtime
performance. Later reviewed documentation and metadata formatting are outside
this frozen executable checkpoint.
