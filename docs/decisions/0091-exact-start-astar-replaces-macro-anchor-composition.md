# 0091 — Exact-start A* replaces macro-anchor composition, and what that costs

Date: 2026-09-12 · Status: Accepted for the implemented ground slice. **Closes no
MOVE gate, and is explicitly not an ARCH-PATH-007/008 pass claim.**

Implements [PATH-R02](../rulings/2026-09-12_movement_dependency_rulings.md) as
dispatched by [the executor follow-up](../rulings/2026-09-12_executor_followup.md)
§2. Retires the finding raised by
[decision 0053](0053-movement-ground-slice-identity-and-storage.md) and adopted in
[decision 0089](0089-restore-layout-and-movement-followup.md).

## Decision

`navigation.gd` now runs unconstrained exact-start → exact-goal A* on every
exact-start cache miss. The `(start_macro, goal_cell, clearance_class,
map_revision)` bucket key and its `variant_start` field are unchanged; what
changed is that a stored route is reused **only** when its own start is the
requester's actual start. The one equivalence PATH-R02 allows is kept: a request
whose start already *is* the canonical macro anchor matches, and publishes, the
ordinary `variant_start = -1` descriptor, because that route genuinely begins at
that cell.

There is **no distance threshold and no nearest-point splice**. Both were the
options decision 0053 refused to invent, and the ruling rejects both outright —
a geometrically nearest join is not necessarily the cheapest one.

`PHASE_SEARCHING_LOCAL` is unreachable; the prefix-plus-bucket concatenation
(`_finish_local`, `_store_concatenation`, `_copy_join`, `_complete_with_bucket`)
is deleted. The **2048-expansion quota is unchanged** and no small-query budget
was added, exactly as the ruling requires.

## Why the phase constant stayed at 2 and a version constant appeared

`PHASE_SEARCHING_LOCAL` keeps its value even though nothing can enter it.
Renumbering would make a `_r_phase` byte written under the old semantics decode
as `SEARCHING_FULL` — a silent reinterpretation of exactly the state PATH-R02
says must be retired explicitly.

The explicit retirement is `ROUTE_SEMANTICS_VERSION = 2` with
`refuse_route_semantics()`. A version 1 descriptor table has the same sixteen
columns of the same widths as a version 2 one, so **shape proves nothing**; the
gate has to be a number. There is no §9 NAVIGATION writer yet (decision 0053
records ARCH-PATH-006 save/load as BLOCKED), which is why the version is
published by the owner now rather than invented by whoever writes that section.
There is no migration: re-keying a version 1 route would republish the same
detour under a new name.

## The fixture, and the evidence that replaced it

`(100,100) → (104,102)` on the authored map now costs **48** — two diagonals at
14 plus two orthogonals at 10 — against the **160** decision 0053 measured. The
independent `h=0` Dijkstra reference agrees at 48 for the same pair.

`test_the_macro_anchor_detour_is_measured_not_hidden` asserted
`_cost(request) == 160` and `_route(request)[4] == _cell(96, 96)`. That
acceptance is **obsolete, not relaxed**: the construction that produced it is
gone. It was not deleted quietly. `test_the_retired_anchor_detour_fixture_now_costs_the_exact_optimum`
replaces it and records in its docstring what the old assertion measured, why it
was correct when written and what supersedes it, so a reader who finds 160 in
decision 0053 can trace it. The replacement acceptance — exact optimum plus
Dijkstra agreement — is strictly stronger: 160 would fail it, and so would any
other value.

Decision 0053's second symptom, a goal lying back past the anchor being reached
by walking past it and retracing, is pinned separately at
`(110,110) → (98,98)`: 168 against the 224 anchor composition produced, with no
cell visited twice.

## Measured, both algorithms, same map, same fixtures

Tick counts are deterministic integers (2048 expansions a tick, deterministic
search), not wall-clock, so they are machine independent.

| Fixture | v1 anchor composition | v2 exact-start |
|---|---|---|
| ARCH-PATH-008 "256 distinct short routes" | p95 **7 ticks** (0.233 s), 14336 expansions, 256 descriptors, **2 requests refused storage** (254/256 ready) | p95 **3 ticks** (0.100 s), 6400 expansions, 256 descriptors, **0 refused**, 256/256 ready |
| 64 starts inside one macro → one distant goal | p95 **1 tick**, 1232 expansions, 127 descriptors | p95 **24 ticks** (0.800 s), 50064 expansions, 64 descriptors |
| 64 long cross-map routes from 64 macros | p95 927 ticks, 2035662 expansions, 192 descriptors | p95 910 ticks, 1997302 expansions, 64 descriptors |
| one short job hop, alone | 1 tick, 56 expansions | 1 tick, 25 expansions |
| one long cross-map route, alone | 20 ticks (0.667 s), 40075 expansions | 20 ticks (0.667 s), 39413 expansions |

**The regression is real and is one shape:** bodies standing in the same macro
heading to the same destination. Sixty-four of them used to cost one full search
plus sixty-three entry segments and now cost sixty-four full searches — 1 tick to
24 ticks, which **breaches REQ-SET-163's 0.25 s and ARCH-PATH-007's seven-tick
allowance**. It is disclosed as an ARCH-PATH-008 failure scene rather than hidden,
and `test_the_measured_price_of_losing_cross_start_reuse` pins the number so a
later change must restate it. PATH-R02 forbids the obvious patch.

Everything else improved or was unaffected. The improvement on the 256-route
colony burst is not only latency: anchor composition needed up to three
descriptors per non-anchor request (prefix, bucket, joined route) and exhausted
the 256-descriptor pool, leaving two residents with no route at all. Exact-start
needs exactly one, so the same burst no longer blocks.

## On the 2048 quota: sufficient for short hops, never sufficient for long ones

ARCH-PATH-007 derives a 14336-expansion deadline budget from the quota. A single
long cross-map route on this 512×512 map costs **39413 expansions**, 2.75× that
budget, *under both algorithms*. The quota is therefore adequate for ordinary
short job hops — which is what the measured colony burst consists of — and has
never been adequate for cross-map travel here. That is a pre-existing property of
the map size and the quota, not something PATH-R02 introduced, and PATH-R02
makes it marginally better rather than worse. No ARCH-PATH-007/008 pass is
claimed, and the quota was not touched.

## What did not change

- The octile heuristic, `10`/`14` costs, `N,E,S,W,NE,SE,SW,NW` order, the corner
  rule, the `(f, cell_id)` heap and the equal-g predecessor rule are byte-identical.
  The exact-start search runs on the **same** uniform lattice; no second traversal
  mode is enabled, so SET-MOVE-001 §4's expanded-graph comparison is not owed here.
- No packed column added or removed, no descriptor or arena capacity change, no
  `resize()` outside `_init()`. **The memory ledger is unchanged** — no row in
  `systems_architecture.md` §2.3 or §3 gains or loses a byte, so
  `ready07_arithmetic.py` needed no edit.
- `_r_start_cell` is retained although it is now always equal to `_r_exact_start`:
  ARCH-MEM-008 names it and a §9 writer must persist it. The redundancy is
  documented at the assignment rather than removed under another owner's registry row.
- `movement.gd`, `transforms.gd` and `spatial_world.gd` were not touched, so the
  persistent-id route cursor stamp and `_height_at()`'s refusal are intact.

## Source

- [PATH-R02](../rulings/2026-09-12_movement_dependency_rulings.md), and
  [the executor follow-up](../rulings/2026-09-12_executor_followup.md) §2 for the lane.
- [Decision 0053](0053-movement-ground-slice-identity-and-storage.md), "Finding for
  the ARCH-PATH-003 owner: the macro anchor detour" — the 160/48 measurement.
- `docs/systems_architecture.md` ARCH-PATH-007 (the 7-tick, 14336-expansion
  derivation) and ARCH-PATH-008 (the benchmark fixtures and the failure-scene rule).
- `docs/game_gdd.md` REQ-SET-163 and §5.1, the 0.25 real-second p95 gate.
- Measurements above: `godot/test/test_navigation.gd`, and the v1 column from the
  same fixtures run against the pre-change `navigation.gd`.
