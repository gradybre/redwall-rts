# Full assembled checkpoint9126ba2b

The frozen source commit was9126ba2be796c09cfbe27fe474bf0ed3bf0f733d.
This checkpoint includes the reviewed actual World/Terrain composition, exact
Room admission, Directory mixed-kind batches, actual SpaceOwner capacity and
snapshot freshness corrections, and native matrix actor adapter.

The worktree had no staged demo assets. The supervisor removed only this own
checkout's `.godot`, ran `godot --headless --path godot --editor --quit`, then
`./tools/run_tests.sh` with no arguments, then the complete zero-warning analyzer.
Its finally block preserves/restores the asset state on every exit. Recorded
source hashes and HEAD were unchanged throughout. Commands, timings and checks
are in `invocation.json`; full raw logs are adjacent.

```text
9827 test(s), 692679 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 9827 tests, 692679 assertions, 0 failures.
0 GDScript warning(s) in 0 of 1100 file(s)
```

Clean import took3.456s; the full suite1219.787s; the analyzer215.118s.
This is regression evidence for those exact assembled components, not completed
playable Room construction, production movement, save/load or hardware budgets.
It predates decision1088's composed phase-survey hook,1087's RoomLayout cold
lifetime correction, the Locations retention observer and the additional
Profiles broadphase reader. Those increments retain separate review/evidence.
