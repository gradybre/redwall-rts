# Pending Furniture batch source verification

These are component tests of actual Directory/Router/Buildings/Construction
identity publication and the actual sparse source owner. Shell/placement boxes
are explicitly synthetic; this evidence grants no production profile, fitting,
service, paid-installation or navigation permission.

Own checkout `codex/underground-world-bindings`, prerequisites through
`5ccd1fd8`; candidate sources are pinned in `source-sha256.json`.
Godot4.7.2 on macOS. Before each strict run, demo assets were moved aside,
`godot/.godot` removed, and `godot --headless --path godot --editor --quit`
completed without diagnostics. The unchanged strict `tools/run_tests.sh`
singleton-shard path selected the two files shown below; assets were restored.

- SpaceOwner:72 tests,3217 assertions,0 failures.
- Actual paired core:18 tests,523 assertions,0 failures.
- Both strict and raw footers:0 unexpected errors,0 unexpected warnings,
  0 expected,0 tolerated;0 leaked objects/resources.
- Analyzer: `python3 tools/gdscript_warnings.py --port6153 --max0` on the
  two changed Owner source/test files:0 warnings in0 of2 files.
- A real small batch at R6144/O2048 spends59668 bounded Owner checks against
  unchanged MAX_CHECKS1048576. This is correctness evidence, not full-tick
  performance or a native memory qualification.

`rejected-development` preserves failed registry placement, fixture alias parse
and wrong-domain-capacity iterations. They are not qualifying evidence.
The final analyzer also corrects test-only naming/ternary warnings. All final
raw import/test/analyzer logs are retained under `final/`.
