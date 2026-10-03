# Full assembled checkpoint — 00573c3e

Date: 2026-10-03. Frozen source: `00573c3ef415bf425152ce6d26b9d1291d66cee1`.

The wrapper moved this worktree’s `godot/demo/assets` aside if present (absent
in this run), deleted its own `godot/.godot`, ran a clean editor import, then the
complete **no-argument** `./tools/run_tests.sh` and the zero-warning analyzer.
It restored the asset location in `finally` and verified the Git HEAD and every
tracked relevant source hash remained unchanged. See `invocation.json` and
`source-sha256.json` for exact commands, durations and pins.

```text
9748 test(s), 681366 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 9748 tests, 681366 assertions, 0 failures.
0 GDScript warning(s) in 0 of 1094 file(s)
```

The full suite took1195.525 seconds; the analyzer took212.474 seconds. The raw
logs are retained here. The clean import emitted no errors or warnings.

This checkpoint includes the independently reviewed finite actual Terrain,
Profile selection/streaming, prepared Locations endpoints, future Room identity
bridge, paid Furniture owner and required canonical/save-owner declarations.
It includes the narrow legacy Section1 fixture correction after the retained
rejected `e267eaec` run; no production codec/hash or diagnostics gate was weakened.

It predates the new RoomOrders confirmation integration, concrete WorldBindings
composition, real-capacity SpaceOwner validation correction and subsequent
Routes/profile-presentation/batch work. In particular, the full-capacity
validation defect found during actual composition is still a separate open fix;
this passing regression run does not prove that path works. The first playable
paint→confirm→worker-excavation Kitchen checkpoint and composed save, native
1280×720 quality and256-resident performance remain open. Component test coverage
is not evidence of completion of all107 player-facing requirements.
