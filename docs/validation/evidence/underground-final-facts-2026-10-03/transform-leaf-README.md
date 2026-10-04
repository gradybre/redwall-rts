# Final Resident pose leaf correction

The Contacts review found a late observer in the shared final source census:
`Transforms.read_into` could copy a valid old pose and then move the actual
Resident before returning. The final source proof accepted that copied pose.
The correction reads the exact Directory/PID-bound Transform columns directly,
retaining the existing idle and moving actor proofs.

`transform-leaf-rejected/` records the old production source with the two new
observer regressions: 27 tests, 1105 assertions, 2 failures and no unexpected
diagnostics or leaks. Both tests accepted the stale copied pose and invoked the
observer. Their initial byte-array equality assertion printed the full state
on failure; the raw logs are retained as lossless `.gz` files with original and
compressed hashes in `compressed-log-sha256.json`. The final test uses boolean
byte equality to avoid repeating that output, and adds PID/full-identity guards.
`negative-test.patch.gz` reconstructs the exact rejected test on base `634964e9`;
its reconstructed bytes were checked against the retained source manifest.

`transform-leaf-final-1/` pins the exact corrected source and tests. A clean
editor import and three strict suites passed:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| FinalFacts | 29 | 1132 | 0 |
| Transforms | 30 | 203 | 0 |
| Routes | 62 | 10393 | 0 |
| Total | 121 | 11728 | 0 |

All strict/raw error, warning and object/resource leak counts are zero. LSP
reports `0 GDScript warning(s) in 0 of 2 file(s)`. The invocation records a
dedicated `Redwall-ug-final-transform-tests` user directory, exact project bytes
before/after, restored assets and unchanged source pins. The inherited Routes
timing result remains a failed runtime gate; it is not part of this correction's
acceptance.

Run from the repository root with a new output directory:

```sh
python3 docs/validation/evidence/underground-final-facts-2026-10-03/reproduce-transform-leaf.py \
  --out /tmp/ug1100-transform-recheck --port 6268
```

The runner restores project settings and temporarily parked assets in a
`finally` block. It pins both owned files before execution and checks them
afterward. Final source review is recorded separately from these author runs.

Construction independently accepted both final source/test hashes after reading
the complete bounded delta, all four added regressions and the retained test
footers. That review found no high/medium issue and did not rerun the engine.
The review covers this pure Transform correction, not Contacts' separate
dynamic-worker or installed-bearing changes.
