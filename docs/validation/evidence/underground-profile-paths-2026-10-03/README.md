# Static profile-filtered path evidence

Decision1098 adds a read-only, pre-Job search over actual committed profile
certificates. These tests exercise actual WorldRoutes, Catalog, Profiles,
Space, Locations, graph and Budget owners. The reused physical/body content
remains explicitly synthetic; no production profile or entrance is qualified.
Negative observation callbacks may reject or invalidate a real certificate
but never manufacture a passing span.

The final source pins and complete successful logs are in `iteration-3/`.
Reproduce from this checkout's repository root:

```sh
python3 docs/validation/evidence/underground-phase-structure-2026-10-03/natural-support/reproduce.py test_underground_routes.gd test_underground_world_routes.gd
python3 tools/gdscript_warnings.py --max 0 --port 6153 godot/scripts/core/underground_routes.gd godot/scripts/core/underground_world_routes.gd godot/test/test_underground_routes.gd
```

The driver moves demo assets aside if present, deletes `godot/.godot`, imports
with `godot --headless --path godot --editor --quit`, then runs singleton shards
through the real strict wrapper and restores assets in `finally`.

```text
45 test(s), 9328 assertion(s), 0 failure(s)
26 test(s), 1711 assertion(s), 0 failure(s)
```

Both suites reported the complete zero-diagnostic and zero-leak footers:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reported `0 GDScript warning(s) in 0 of 3 file(s)`. Reused fixture
assertions are failure-propagated to the owning test but are not added to its
outer assertion count. No duplicate full-suite or native performance claim is
made. Independent source review is recorded in the decision before commitment.

The earlier green `iteration-2/` is retained as rejected review evidence: its
reentry assertion used insufficient output capacity and could hide a callback
fault escaping through a later detour. Iteration 3 uses eight output integers,
checks the exact first fault, verifies the whole output is unchanged, and proves
that no later permission callback runs. The shared operation fault is sticky;
ordinary clean span refusal still permits a certified detour.
