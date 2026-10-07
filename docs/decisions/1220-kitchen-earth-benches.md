# 1220 — Kitchen earth benches: the published rows support no bench (stopped for a decision)

Date: 2026-10-07 · Status: Proposed. The planner names the missing capability; the bench design waits on Brendan.

## Brendan's decision being implemented

Chat, 2026-10-07: **earth benches** for the 4 m Kitchen's upper cubes. Dig top-down by leaving temporary earth
steps or benches to stand on, then cut the benches away last, using existing strokes and walking.

Coordinates are relative to the ADR 1161 fixture datum. The Kitchen is columns A (x 2048, z 0), B (2048, 1024),
C (3072, 0) and D (3072, 1024), levels 0–3. The Corridor beside it is open void from y 0 to 4096.

## Findings (derived from content 6, `qualified-stone-v7`, 42 rows)

### 1. No published travel row climbs

- Every row's stance box (role 1) lies in y ∈ [−1, 0], and no row is `MODE_CLIMB`.
- WorldRoutes qualifies level ground only:
  - `WORLD_ROUTE_GROUND_HEIGHT` refuses any route whose points differ in y;
  - `WORLD_ROUTE_GROUND_CONTENT` refuses `MODE_CLIMB`;
  - `WORLD_ROUTE_FIXED_CONNECTOR_SOURCE_REQUIRED` refuses connector paths.
- The 232 u short step (rows 10/11) is a horizontal advance (ADR 1209).
- The only authored rise is the 128 u stair gait (`stair-descent-v7` / `stair-motion-v15`), at a 512 u going. It is
  source-only (`underground_motion_catalog.gd` `activation_refusal` = `MOTION_SOURCE_ONLY`), and it holds the pick
  (M7 pending, ADR 1217). The 256 u descent refuses (`DESCENT_LEG_REACH_FRAME_28`).
- **The smallest bench rise the published rows climb is therefore 0 u.**
- Half-height or 128 u steps cannot be cut either. Sites and the excavation contract are 1,024 u cubes
  (`Contract.QUANTUM_SIDE_U`), so a step smaller than a cube is not representable as earth. Eight 128 u risers at a
  512 u going would also need a 4,096 u run, and the Kitchen is 2,048 u long.

### 2. Even with a free 1,024 u climb, no whole-cube bench can exist

A bench is a solid cube with open air above it. The cube above it must already be dug.

**How level-1 cubes are reached.** A level-1 cube is reached from a floor stance only by a HIGH row (14, 18, 22 or
26; anchor 1,039 u up). Each HIGH row's turn box `[536..732] × y [514..878]` (yaw 49152; the other yaws are
rotations) crosses the struck face by 196 u at heights 514–878. That puts it inside the cube under the target. So a
level-1 cube can be dug only after the cube beneath it.

**The only other reach.** FRONT (707 u) reaches level 1 from a stance 1,024 u up, which needs a bench that already
exists.

**Result.** There is no first bench. This is independent of climbing.

**Search.** `bench_solver.py` was a scratch search, not committed. It enumerated every WORK row 13–28 at stance
heights 0, 1,024, 2,048 and 3,072, with lateral roots every 16 u. It assumed:

- a free 1,024 u ascent between adjacent standing cells;
- footing on undug cubes.

Each station's boxes were checked against the cube grid: air in void or in the Corridor, the stroke also allowed
into the target, and below-plane boxes on solid. A breadth-first search over all 2^16 dug sets reaches **at most
the same 8 cubes**, levels 0–1. Capping every box at 1,024 u above the stance (a hypothetical low-profile body)
still reaches only 8, because of the HIGH intrusion above. Cubes A3 and B3 have no station at all with these rows.

**Also missing at runtime.**
- An unpaid Kitchen cube is a Room reservation marker (`OBSTACLE`, `CLAIM_ROOM`), not `SUPPORT`, so a Location
  cannot prove footing on a bench top.
- The planner plans only on `FLOOR_DATUM` sections at the gateway level.

## What was built

`underground_room_station_planner.gd`:

- **`ROOM_STATION_BENCH_ASCENT_MISSING`.** It replaces `ROOM_STATION_REACH_MISSING` when an eligible WORK row would
  reach the cube from a bench top a whole number of cubes above the floor but no certified `MODE_CLIMB` row with the
  retreat row's identity exists.
  - The rise is derived from published boxes, with no new constant. It is the smallest positive multiple of
    1,024 above `origin.y − start.y − anchor.y` that keeps the anchor strictly inside the cube's band.
- **`ROOM_STATION_BENCH_FOOTING_MISSING`.** A climbing row exists, but no bench footing or section does.
- **`bench_into(...)`.** It writes `[rise, work row, climb row]`; a floor-reachable cube gives rise 0.
  - It is content-agnostic: when claw rows replace the pick rows, the rise follows their anchors.
  - `plan_into` and `bench_into` share one validation prologue (`_open`).

**Loop on content 6.**
- 8 of 16 cubes are paid with exact ledgers, unchanged.
- The 8 cubes at levels 2–3 refuse `ROOM_STATION_BENCH_ASCENT_MISSING`, each asserted exactly:
  - level 2: `[1024, 26, -1]`, HIGH 26 from a 1,024 u bench;
  - level 3: `[2048, 26, -1]`.
- A negative-only test turns row 0 into a climbing row and gets `BENCH_FOOTING_MISSING`, with climb row 0 named.

**Budgets (measured, unchanged).**

| Preparation | Route checks | Location checks |
|---|---:|---:|
| Publication peak | 71,640 | 173 |
| Phase peak | 459,742 (43.8 %) at 40 edges | 979 |

- Stations are published 2, 2, 3, 3, 3, 3, 2. No new station is published, so no retirement is needed (the
  ADR 1213 limit is about 94 edges).

**Memory.**
- `Query` gains two int scalars inside its declared 1,024 B scalar allowance. `CONTROL_BYTES` stays 45,752.
- `tools/underground_memory_budget.py --check` passes (headroom 92,369 B before DEC-053 raised the gate).

## Options for Brendan

1. **Recommended now: accept a 2 m Kitchen (levels 0–1, 8 cubes) as the first Kitchen**, which digs completely
   today. Keep the 4 m Kitchen for when bench content exists. In addition, give claw M2 (the high-wall stroke,
   ADR 1217, not yet authored) a constraint: its air must not cross the struck face below the target's floor plane.
   That is cheap now, and it is what makes a first bench possible.
2. **Earth benches as decided, with new content and code.** All of these are needed:
   - an M2 that meets the constraint above;
   - a claw climb row pair for a 1,024 u ledge (`MODE_CLIMB`), with a rise field in Profiles;
   - vertical WorldRoutes/Routes edges;
   - a temporary bench `SUPPORT` over a reserved cube, retired by that cube's own CUT;
   - bench-top `FLOOR_DATUM` sections with planner and publication support for them.
   Even then, A3 and B3 need re-checking against the new rows.
3. **Earth steps with the 128 u gait.** This needs sub-cube excavation Sites (a contract change), activation of the
   stair gait (M7, `MOTION_SOURCE_ONLY`) and switchback turns, because a 4,096 u run does not fit.
4. **A timber scaffold in the Corridor** (an assembly like L0). It still needs a climb row, but it does not depend
   on the M2 constraint.

## Not done

No content, no Routes change and no bench retention. The loop still digs the lower levels first. Bench retention
only matters once option 2 exists, so it waits on the choice.
