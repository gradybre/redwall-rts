# UG07 A — Actual spatial Room and pending Furniture boundary

The owned worktree had no `godot/demo/assets`. Its `.godot` cache was deleted
before `godot --headless --path godot --editor --quit`; the retained import
log contains no errors or warnings. Each listed suite used the unchanged
`tools/run_tests.sh` exact singleton CI shard, including registry, zero
unexpected diagnostic and zero leak gates. `summary.json` totals the final
per-suite results: 211 tests, 43554 assertions, zero failures. All six strict
and raw diagnostic footers report zero errors, warnings and leaks.

New spatial cases use an explicit test-only exact-operation authority. They
verify real Buildings/Directory behavior; they do not prove geometry, paid
installation or backfill. The physical suite separately retains actual paid
Inventory/Work/Gear behavior under its existing synthetic spatial fixture.
The final changed source pair was independently reviewed. Analyzer command:

```
python3 tools/gdscript_warnings.py godot/scripts/core/buildings.gd godot/test/test_buildings_spatial.gd --max 0 --port 6156
0 GDScript warning(s) in 0 of 2 file(s)
```

The final retired-spatial-pose save refusal was followed by rerunning the
changed spatial suite plus both affected legacy Buildings/S1 suites. Other
listed source did not change after its focused regression result. New source
hashes are in `source-sha256.json`. This is a focused acceptance checkpoint;
full integration, UG10 service consumers, UG16 composed save/load and runtime
qualification remain separate work. The retained microbenchmark predates the
separate Gear optimization and is not a performance-budget pass.
