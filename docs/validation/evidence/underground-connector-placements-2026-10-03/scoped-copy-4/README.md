# Sealed scoped snapshot lease evidence

The new Owner traversal and exact actual Sites readers preserve their existing
marker predicates while checking the original Budget token immediately before
snapshot allocation. This slice adds no retained state or permission.

`test_underground_space_owner.gd.log` is the unchanged strict wrapper result:
107 tests, 5359 assertions, zero failures, diagnostics or leaks. `analyzer.log`
reports zero warnings across the four pinned Owner/Routes source/test files.
Only the Owner pair belongs to this prerequisite; the independent exact-WORK
Routes change has its own evidence and review. Source pins are recorded here.

The unfinished new Placement draft was held outside `godot/` for these focused
prerequisite checks, then restored. No registry bypass, engine wrapper change,
permissive diagnostic allowance or production fixture was introduced.

Earlier scoped-copy-1 retains a refused test expectation that failed to charge
an already-retained output image; scoped-copy-2 is the corrected107/5358 run.
Scoped-copy-3 retains an accidental duplicate test-only assertion in an older
fixture; the final test removes that duplicate while preserving the intended
new missing-Construction case. Production source did not change in that fix.

Reproduce with the committed shard wrapper: generate the complete plan with
`tools/ci_test_shards.py`, select the singleton `test_underground_space_owner.gd`
shard, and run `./tools/run_tests.sh --shard INDEX/COUNT --output-dir DIR`.
The manifest under `shards/` records the exact selection and complete corpus.
Analyzer command: `python3 tools/gdscript_warnings.py
godot/scripts/core/underground_space_owner.gd
godot/test/test_underground_space_owner.gd
godot/scripts/core/underground_routes.gd
godot/test/test_underground_routes.gd --port 6237 --max 0 --json analyzer.json`.
