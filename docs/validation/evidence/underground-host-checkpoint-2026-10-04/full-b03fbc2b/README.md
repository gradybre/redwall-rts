# Full local checkpoint b03fbc2b

The complete checkpoint **failed the zero-warning analyzer**. The strict full
suite passed, but that does not waive the independent analyzer gate.

The frozen own checkout and exact commit are recorded in `invocation.json`.
The wrapper parked demo assets if present, removed `godot/.godot`, ran
`godot --headless --path godot --editor --quit`, then the unmodified no-argument
`./tools/run_tests.sh`, followed by `tools/gdscript_warnings.py --max 0`.
Import took 11.506 seconds and the full suite took 1,799.688 seconds.

```text
11000 test(s), 1019580 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer took 290.465 seconds and exited 1:

```text
12 GDScript warning(s) in 6 of 1235 file(s)
```

All twelve warnings belong to historical rejected native capture snapshots
v1–v6, matching the same-head CI failure. Their later lossless archive correction
is commit `dc881589`; this old checkpoint does not qualify that correction.

`invocation.json` confirms source and HEAD unchanged and assets/project restored.
The three raw logs are losslessly compressed; `archived-logs.json` records their
original names, decoded SHA-256 values and sizes. `source-sha256.json` identifies
the tested source. Nothing in these retained logs has been rewritten.

The [same-head CI run](../ci-b03fbc2b/README.md) executed the same 396 suite files,
11,000 tests and every diagnostic/leak total. Its assertion count is eight lower.
The original full runner did not emit per-suite assertion counters, and this
difference remains unattributed. `../b03-test-comparison.json` retains the exact
all-counter verifier's refusal; exact assertion equivalence is not claimed.
