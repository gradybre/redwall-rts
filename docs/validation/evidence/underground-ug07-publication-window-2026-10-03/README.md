# UG07 A0b — Synchronous physical publication attestation

This focused prerequisite was reviewed independently and tested against parent
`0bef602b` with only the two listed GDScript files changed. The uncommitted
Buildings A changes were parked before import and restored only after this
checkpoint. No demo assets were present. The Godot cache was deleted, then
`godot --headless --path godot --editor --quit` completed with no error or
warning lines. The unchanged strict test script ran the exact singleton CI
shard for `test_excavation_physical.gd`.

```
36 test(s), 22404 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Analyzer invocation used the two changed paths with `--max 0 --port 6156`.
The test retains actual Inventory/Construction/Jobs/Work/Gear transactions;
its spatial fixture remains explicitly synthetic. The callback cannot establish
production clearance or replace the spatial owner's prepared revision proof.
No full-suite or performance-budget pass is claimed; the retained measurements
predate the separate Gear optimization and are diagnostic only.
