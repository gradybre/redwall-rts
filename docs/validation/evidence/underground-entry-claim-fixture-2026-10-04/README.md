# Entry claim fixture migration — 2026-10-04

CI run [37221084815](https://github.com/gradybre/redwall-rts/actions/runs/37221084815)
at `f44efa7d0e29177bb97c499442078565099b3f12` failed seven assertions in
`test_excavation_entry_claim_batch.gd`. All other suite shards and independent
gates passed; the aggregate correctly failed. The failed job log, exact old
test source and run metadata are retained in `ci-f44efa7d/`.

The earlier component fixture inserted a non-flat entry batch beneath
`confirm_room()`. Ordinary Room publication now correctly requires its exact
flat input and cursor. The fixture therefore reached `UNDERGROUND_ROOM_PLAN_INVALID`
before publication. This correction changes only the test: non-flat cases use
the actual `confirm_entry()` path and its unchanged final guards, retaining the
existing explicit synthetic Terrain/frontier/Placement permission. The test no
longer overrides the final claims guard. The one flat control and the non-Corridor
negative case keep the flat path. A new regression proves that injecting an
entry batch into flat admission refuses without any Room, Site, Space or goods
write. Oversized entry input now refuses at the earlier whole-request boundary.

The strict clean-import focused run covers entry claims, flat claims, actual
entry orders and ordinary room orders:

```text
16 test(s), 529 assertion(s), 0 failure(s)
10 test(s), 331 assertion(s), 0 failure(s)
19 test(s), 797 assertion(s), 0 failure(s)
38 test(s), 1803 assertion(s), 0 failure(s)
```

Total: **83 tests / 3,460 assertions / 0 failures**. Every suite reported:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 8 file(s)
```

`focused-1/invocation.json` records the exact commands, stable source pins and
restored project, actual shared registry and assets. The harness uses the official
strict singleton shards after parking assets, deleting `.godot` and importing.
These focused results do not retroactively make the failed CI run pass. A new
integrated CI run remains required. Independent review is recorded separately.
