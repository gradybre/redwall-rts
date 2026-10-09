# CI checkpoint1eb7a64d — 2026-10-04

[Run37216053405](https://github.com/gradybre/redwall-rts/actions/runs/37216053405)
passed all14jobs at exact commit1eb7a64d5b36c69081c5403e330f90f906ca2e65 in13m10s.
The unchanged verifier replay proves all391test files executed exactly once
across8shards:10941tests /1016683assertions /0failures;272expected and353tolerated
diagnostics, zero unexpected errors/warnings or leaked objects/resources.
Analyzer: `0 GDScript warning(s) in 0 of 1220 file(s)`.

`merged/` retains24original manifest/log/report files. `verify.py` replays the
unchanged verifier against this exact commit's suite corpus. `run.log.gz`
retains the complete raw GitHub log losslessly with compressed/raw SHA256 pins;
`run.json` pins all job results and the commit.

The separate stricter local import at this head refused a nested capture-project
warning before tests. The parent offline-subtree .gdignore fix is9ca21351; its
clean import and separate no-argument suite passed:10,941 tests/1,016,692 assertions,
the same diagnostic/leak totals and analyzer0/1220. The nine-assertion difference
is not attributed and the commits differ. CI success
does not erase that recorded local refusal, and no exact same-head local/CI
full-run equivalence is claimed by this packet. Existing comparator stays strict.
