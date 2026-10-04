# Exact WORK actor selection evidence

The strict Routes suite reports 49 tests / 9507 assertions / zero failures;
Profiles reports 25 / 601 / zero failures. Both strict/raw diagnostics and all
object/resource leak counts are zero. The four-file analyzer result is retained
in `../scoped-copy-4/analyzer.log` and reports zero warnings. The Routes pins
match the independent furnishing review and the final source unchanged check.

This checks the explicit WORK admission/refresh wrappers and committed contact,
current and occupancy lookup against actual Jobs/Work/Gear owner fixtures with
two synthetic qualified profile rows. No production certificate or first-entry
permission is asserted. The unfinished Placement source was held outside Godot
for these focused prerequisite checks and restored afterward.

Reproduce via the strict singleton shard wrapper:
`./tools/run_tests.sh --shard INDEX/COUNT --output-dir DIR`. The retained shard
manifest records each exact selected suite and full corpus. Analyzer command:
`python3 tools/gdscript_warnings.py godot/scripts/core/underground_space_owner.gd
godot/test/test_underground_space_owner.gd godot/scripts/core/underground_routes.gd
godot/test/test_underground_routes.gd --port 6237 --max 0 --json analyzer.json`.
