# Integrated room-access component — dc6baa12

Root independently reviewed the frozen ADR1154 candidate, including the
configuration lifetime correction, actual-owner regression tests, source and
result manifests, source-derived view census and native 1280×720 states.
`room-access-review-2.json` records the scope and outstanding performance limits.
Author commit `8cb864f7` was integrated unchanged as `dc6baa12`.

The integrated run used the committed reproduction wrapper with a new output
directory and isolated user directory: assets absent initially, cache removed,
`godot --headless --path godot --editor --quit`, four official strict singleton
shards, and `tools/gdscript_warnings.py --max 0`. No prerequisite replacement or
registry relaxation was needed. This is a component integration check, not a
no-argument whole-project milestone.

The four actual suite summaries are:

```text
25 test(s), 768 assertion(s), 0 failure(s)
16 test(s), 227 assertion(s), 0 failure(s)
10 test(s), 116 assertion(s), 0 failure(s)
9 test(s), 149 assertion(s), 0 failure(s)
```

Total: 60 tests, 1,260 assertions, zero failures. All four diagnostic lines
match the first line below; the second line is the separate analyzer result:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 6 file(s)
```

`invocation.json` confirms source and HEAD stayed unchanged and project,
registry, prerequisites, assets and import sidecars were restored. Raw import
and suite diagnostic checks also passed. No engine rerun is inferred from an
exit status alone.

The fixtures use actual owners and RoomOrders with explicitly synthetic
physical/profile data. They do not establish installed demo activation, real
worker approach or paid Kitchen completion. The dense access proof still takes
about 69 ms and does not meet the 1.5 ms UI target. Full population, whole-demo
visual/input and native memory qualification remain open.
