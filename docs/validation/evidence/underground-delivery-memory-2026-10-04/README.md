# Integrated Delivery accounting and regression

The accepted Delivery source is `eec1002b`, integrated as `fa017ba4`.
This packet reconciles its fixed packet and Work binding with the real shared
registry and memory pack. No temporary registry appendix was used here.

The measured source census is 753 numeric/packed bytes plus one Work boolean,
1,024 logical helper bytes and a separate provisional 2,048 native allowance:
3,826 declared within a new 4,096 contribution. The borrowed 216-byte Transfer
belongs only to ADR1141. Live plus reserve is 99,998,782, leaving 1,218 under the
unchanged decimal 100 MB limit. This is source-derived admission, not measured
runtime qualification. Stair/motion storage must fit the existing profile arena.

`normal-v1` preserves all eight initial gate runs: 184 memory tests, 190 capacity
tests, exact generated artifacts, READY07, merge gate, registry and decision
checks passed. Independent review then found a checker gap for an extra `_init`
allocation call and a large local packed image; the current runtime source did
not contain either. The corrected guard checks the complete reviewed allocation
entry and growth vocabulary. `normal-v2` passes 193 memory tests, exact artifact
and READY07 checks with all seven source pins unchanged. The review and original
mutants are under `../underground-delivery-memory-review-2026-10-04/`.

`focused-v1` uses the clean-assets/cache/import procedure followed by the three
official strict single-suite shards against the integrated shared registry:

```text
13 test(s), 4370 assertion(s), 0 failure(s)
34 test(s), 185 assertion(s), 0 failure(s)
77 test(s), 9283 assertion(s), 0 failure(s)
```

For each suite, the exact diagnostic and raw-log footer is:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The combined result is 124 tests / 13,838 assertions / zero failures.
The analyzer reports `0 GDScript warning(s) in 0 of 6 file(s)`.
Invocation records contain exact commands, hashes, restoration and elapsed
times. Source, project and registry remained unchanged. These are focused
post-checkpoint results; the last full suite remains the separate 32db348a run.

Reproduce the changed accounting checks using `verify_accounting.py <new-dir>`.
`reproduce.py --out <new-dir> --suite <suite> ...` reproduces the strict focused
engine procedure in an owned checkout. Both scripts create new output paths.
