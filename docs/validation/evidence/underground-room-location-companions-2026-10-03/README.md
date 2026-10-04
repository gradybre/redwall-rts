# Room-confirmation endpoint companion evidence

This is component evidence for decision1096. Real RoomOrders, Buildings,
Directory, Space, Locations, Inventory and the shared Budget execute the actual
pre-seal, post-seal and publication order. The fixture's pre-existing surface
geometry and inherited terrain/profile admission are explicitly synthetic. It
creates no production entrance, profile, contact, route or paid excavation.

The accepted source pins and complete successful import, suite and analyzer
logs are in `iteration-2/`. The first rejected test-fixture run remains under
`historical-fixture-probe/`, with its oversized assertion payloads explicitly
truncated. The corrected fixture arms the fault at the intended post-seal
boundary; production source did not change between these two runs.

From this checkout's repository root, reproduce the CI-style clean import and
strict singleton shards with the existing audited driver:

```sh
python3 docs/validation/evidence/underground-phase-structure-2026-10-03/natural-support/reproduce.py test_underground_locations.gd test_underground_room_orders.gd test_underground_routes.gd
python3 tools/gdscript_warnings.py --max 0 --port 6153 godot/scripts/core/underground_locations.gd godot/test/test_underground_locations.gd
```

The driver moves `godot/demo/assets` aside if present, deletes `godot/.godot`,
runs `godot --headless --path godot --editor --quit`, then uses the real strict
`tools/run_tests.sh` shard path and restores assets in `finally`.

The successful summaries were:

```text
36 test(s), 1148 assertion(s), 0 failure(s)
30 test(s), 1533 assertion(s), 0 failure(s)
40 test(s), 9175 assertion(s), 0 failure(s)
```

Every suite reported both complete diagnostic footers:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reported `0 GDScript warning(s) in 0 of 2 file(s)`. Independent
source review is recorded in the decision before commitment. These focused
results are not a full-suite, native-memory or playable-demo qualification.
