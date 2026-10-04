# Derived room cut map — component evidence

Source branch codex/underground-room-cut-map, base9d9fb9d9.
All six final source/test hashes are pinned in source-sha256.json.

Each recorded runtime invocation moved this worktree's demo assets aside,
deleted godot/.godot, ran the exact headless editor import, then used the
unchanged strict tools/run_tests.sh with a validated complete shard manifest
selecting each requested whole test file. Assets were restored afterward.
The no-argument full suite remains the integration owner's milestone gate.

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| Cut map |9|40164|0|
| Actual Room admission |24|821|0|
| Actual physical excavation, final narrow rerun |50|23926|0|
| RoomOrders regression |28|1457|0|
| RoomBindings regression |17|604|0|
| Total |128|66972|0|

The final five-suite pass initially contained23925 physical assertions.
The only later change was one explicit identity assertion reading the
otherwise unused strong test borrow; final-physical-assertion repeats clean
import and that affected whole suite. Other frozen sources stayed unchanged.
Every strict and raw summary reports zero unexpected errors, zero unexpected
warnings and zero object/resource leaks. Expected/tolerated diagnostics are
also zero. Analyzer:0 GDScript warning(s) in0 of6 files.

The rejected setup evidence is retained: a first test helper incorrectly
tried to replace an expired once-bound Construction physical owner. Actual
guards correctly refused; tests now replace the entire test composition.
The LSP unused-local diagnostic was fixed by the explicit identity assertion.
Neither rejected run is presented as a passing acceptance.

Cut map oracle checks all511 nonempty3x3 unions at pitches256/769/1025,
negative datum/half-open boundaries, one-cube duplicates, real gaps,
output/work exhaustion, rank overflow and huge sparse coordinate spans.
Actual Room preflight reaches the original entry-unbound refusal for the
full16384-cell ceiling, enumerating4096 unique history keys. All admission
refusals preserve actual Directory, Space, inventory and paid state.

The854016-byte logical cold peak is arithmetic, not native-memory or timing
qualification. Existing physical-suite timing diagnostics are retained as
observations and do not assert the whole2ms tick budget passes. Actual
entry/profile/route, reserved-key publication and playable activation remain
required and intentionally closed.
