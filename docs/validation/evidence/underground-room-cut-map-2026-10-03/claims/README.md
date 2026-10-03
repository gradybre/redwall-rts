# Atomic Room cut reservations — component evidence

Date2026-10-03. Source base76a5a8bc; own branch
`codex/underground-room-claim-batch`. Final eight source/test pins are in
`source-sha256.json`. No full-suite, actual entry/work qualification,
native-memory or playable-room claim.

`final/import.log` records the CI-style clean import: this worktree's demo
assets were moved aside, its `.godot` removed, and the exact command
`godot --headless --path godot --editor --quit` ran. Assets were restored in
the wrapper's `finally` path. The unchanged strict runner ran each named
suite as one validated shard; the complete manifests and raw engine logs
remain beside their JSON results.

| Focused suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| Derived CutMap |11|40215|0|
| Actual claim batch |10|329|0|
| RoomOrders |31|1574|0|
| Furniture Work |15|4628|0|
| Paired Furniture batches |14|1364|0|
| Spatial Buildings |21|434|0|
| Physical excavation |50|23926|0|
| Actual static Room admission |24|821|0|
| Actual Room masks |17|604|0|
| Total |193|73895|0|

Every final suite prints:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer on port6156 reports:

```text
0 GDScript warning(s) in 0 of 8 file(s)
```

`rejected-initial/` preserves the initial RoomOrders failure. Its older
two-Room fixture put a second room inside a fine hole that shared a whole
physical quantum already reserved for the surrounding room. Retained-key
composition remains unqualified. The final positive fixture instead has a
wholly untouched cube in its hole, and an additional negative test preserves
the exact fine hole while rejecting unsupported physical-key reuse. Neither
geometry nor history guards were relaxed. That initial run is excluded from
the passing totals.

Permission-only terrain/contact fixtures are named explicitly. Actual
Directory, Buildings, Space, Sites, Budget, Inventory, claims, Jobs, Work and
catalog owners execute throughout. The final batch guard runs after every
provider callback and immediately before real identity publication. Existing
retained history, missing entry and unsupported productive permissions remain
explicit refusals.

Independent geometry-lane source review accepted all eight exact pins with
no high/medium blocker. The reviewer read the source and retained evidence;
no duplicate engine run or source edits were performed. See `review.md` for
the exact bounded verdict. Source hashes remained unchanged through review.
