# Astra follow-up — 2026-09-12

Task: 05_movement_first_playable.md
Date: 2026-09-12


PATH-R02 replaces mandatory anchor composition with exact-start A*; MOVE-DEP-R01–05 explicitly bind the five missing owners. Full05.1b and movement gates remain open.
Read [the current executor handoff](../rulings/2026-09-12_executor_followup.md) before dispatch.

- [x] **PATH-R02 — implemented in `navigation.gd`, 2026-09-12.** Engineering record: [decision 0091](../decisions/0091-exact-start-astar-replaces-macro-anchor-composition.md). Exact-start A* on every exact-start cache miss; no threshold, no nearest-point splice; the 2048 quota unchanged and no new packed column, so the memory ledger is untouched. The `(100,100)→(104,102)` fixture is now 48 with Dijkstra agreement, and the obsolete 160 acceptance is retired with its historical evidence preserved in the replacing test. Readiness remeasured: ARCH-PATH-008's 256 short routes improve from p95 7 ticks with 2 storage refusals to p95 3 ticks with none, while 64 starts sharing one macro regress from p95 1 tick to 24 and are disclosed as a failure scene. **Closes no MOVE gate and claims no ARCH-PATH-007/008 pass.**
