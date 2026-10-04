# Atomic Furniture/Construction identity evidence — 2026-10-03

Decision1089's first core increment verifies the actual Directory, Buildings,
Construction and ModularProjects owners. Only the test's geometric/completed-shell
permission is synthetic. The actual RoomOrders/Sources/future-geometry bridge is
the following increment; these tests do not claim playable layout acceptance.

The accepted five source hashes are in `accepted/source-sha256.json`. Own demo
assets were absent; own `godot/.godot` was removed before the recorded clean
`godot --headless --path godot --editor --quit` import. Its log has no ERROR or
WARNING lines. The unchanged `tools/run_tests.sh` ran the recorded complete shard
manifests; no diagnostic, leak, analyzer or state-registry gate was bypassed.

| Strict suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Construction Furniture batches | 18 | 523 | 0 |
| Construction regression | 48 | 515 | 0 |
| Buildings spatial regression | 21 | 434 | 0 |
| Shared modular projects regression | 19 | 1816 | 0 |
| Paid Furniture work regression | 15 | 4628 | 0 |
| Total | **121** | **7916** | **0** |

Every accepted suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer ran on all five changed GDScript files with `--max 0 --port 6156`:
`0 GDScript warning(s) in 0 of 5 file(s)`.

The first rejected run had two assertion failures because the synthetic test
purpose owner did not implement its actual pending-project quote reader; real
Construction correctly refused the missing facts. That fixture was completed
against the protected catalog, and its rejected raw log is retained separately.
It is not counted as qualification.

Independent review found that legitimate final companion cleanup could invalidate
the borrowed batch before its count/ref were returned. The corrected Router pins
both scalar facts immediately after identity commit and before any callback. The
adversarial test observes both real typed stores, clears packet and entries, and
proves the truthful committed receipt and exactly-once allocation survive.

No full-suite, native memory, target hardware performance, spatial source, save
composition or live UI qualification is asserted by this component evidence.
