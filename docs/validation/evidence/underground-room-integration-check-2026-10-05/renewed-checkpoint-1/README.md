# Renewed coherent focused checkpoint

Exact commit `9dad696ddb6485e9a8c4b8efd8c8dcee52c9c4c0` passes the ten
requested actual singleton suites: **169 tests, 18,457 assertions, zero
failures**. Every strict and raw unexpected diagnostic and leak counter is
zero; these suites also emitted zero expected/tolerated diagnostics. Clean
import had no raw findings. The zero-warning analyzer passed all 29 selected
owning source/test files.

This is a fresh `codex/underground-room-integration-renewal` worktree, created
from freshly fetched `origin/master` at
`82d60ba86dcecf6e7c6184eeaf77a389e8b2b5c2` and fast-forwarded to the exact
checkpoint. The earlier `8003bfe1` failure and its evidence branch are preserved.
No source, shared registry, queue or production fingerprint was overlaid.

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| RoomComposition | 16 | 371 |
| Session | 15 | 225 |
| Host | 21 | 219 |
| WorldRetirement | 19 | 1,963 |
| RoomCatalog | 14 | 606 |
| ConnectorCatalog | 26 | 606 |
| MoleQualifiedProfiles | 10 | 353 |
| SupportClearance | 9 | 138 |
| RoomWorldPhases | 24 | 290 |
| MotionCatalog | 15 | 13,686 |

The evidence-only `../reproduce_renewal.py` invokes the original
`verify_profile_integration.py` unchanged, with every singleton runner gate
retained. It clears the cache, parks assets if present and clean-imports the
actual project before tests. The strict runner and analyzer took 104.760 and
25.067 seconds respectively. Original project, registry, asset presence,
sidecars, source bytes and HEAD all verified unchanged/restored.

`invocation.json`, `summary.json`, full strict logs/manifests, the original
runner snapshot, source hashes and analyzer report retain the exact result.
Analyzer port was 6465; user directories were explicitly isolated. No engine
or analyzer was left running by this focused procedure.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B \
  docs/validation/evidence/underground-room-integration-check-2026-10-05/reproduce_renewal.py \
  --out docs/validation/evidence/underground-room-integration-check-2026-10-05/renewed-replay \
  --port 6465
```

The separate full no-argument procedure starts only after this pass and remains
on the same frozen commit. Focused success alone does not qualify the whole
project, whole-room progression, native memory or the playable Kitchen workflow.
