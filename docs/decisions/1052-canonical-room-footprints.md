# 1052 — Canonical integer room footprints, with explicit grid identity

Date: 2026-10-02 · Status: Accepted engineering foundation; demo integration pending

## Decision

`scripts/core/room_footprint.gd` supplies stateless, deterministic cold-path
geometry for the approved room and tunnel planning tools. A footprint is a
`PackedInt32Array` of `[x,z]` grid-cell pairs, strictly sorted by Z then X,
without duplicates. Grid pitch, origin, level and room identity belong to the
caller. A cell covers its complete unit square; the helper never treats a
bounding box, center point or decorative curve as usable floor.

The existing fixed-position convention remains 1024 units per metre. The
helper accepts an explicit positive integer `cell_size_u` when deriving world
corners and refuses int32 overflow before packing the result. It does not
select a production paint spacing, level spacing or room height.

## Shapes, boundaries and openings

Rectangle, ellipse, rounded rectangle, round brush, connected add/erase and
width-bearing tunnel-route operations all return canonical cells. Raster tests
use integer cell centers and exact squared/product comparisons. Tunnel routes
use a cardinal supercover: when a line goes exactly through a grid corner,
both neighboring cells are included. Reversing a route therefore produces the
same footprint. Its disk radius is explicit; its full nominal width is
`2 * radius_cells + 1` cells. Future even-width or differently profiled route
tools must specify their raster convention rather than silently shifting this
one.

Shape/edit/transform results are cold value dictionaries containing `ok`,
`error: StringName` and `cells`; refusal returns no partial cells. Edits may
temporarily produce an empty or disconnected draft, but confirmation must use
`validation_error()`. It requires canonical cells, one cardinally connected
component and an unambiguous wall boundary. Diagonal contact alone is not
connectivity. A connected shape with a diagonal boundary pinch also refuses;
no surface generator should resolve that zero-width intersection by guessing.

Holes are an **explicit caller policy**, passed to validation. When allowed,
an enclosed absent cell remains absent, with its own inner wall loop. It is
not filled, excavated or made into walkable space. This helper does not adopt
an unrestricted gameplay pillar/island policy. The integrating room catalog
must expose the policy it actually validates.

`boundary_edges()` returns exposed `[cell_x,cell_z,side]` triples in canonical
cell order and N/E/S/W order; north is negative Z. Shared internal edges cancel.
`boundary_loops()` joins the same edges into closed packed corner chains,
retaining every grid step. Each chain starts at its lowest Z/X corner. Outer
winding is clockwise in X/Z plan and hole winding counterclockwise. Thus one
geometry source can own floor, wall, ceiling, picking and placement coverage.
Presentation may derive rounded profiles, but may not extend occupied floor
or excavation outside the confirmed footprint to conceal the grid.

`opening_edges()` names a complete straight run of exposed cell edges. N/S
runs advance in +X and E/W runs in +Z. Every edge must exist; a correct anchor
with a wrong width refuses. This descriptor alone supplies **no** doorway
height, support, landing, resident/cargo clearance, connector or safe-exit
approval. Those checks remain with the movement/construction owners.

`transform_cells()` rotates whole cells clockwise around grid vertex `(0,0)`
in 90-degree increments, then translates by cell indices. One quarter turn
maps `(x,z)` to `(-z-1,x)`, preserving the cell square rather than rotating
only its lower corner. Full-item containment checks every occupied cell.

## Engineering bounds and runtime use

An operation accepts a caller limit between 1 and **16384 input/result cells**.
This finite cold-operation guard is an engineering envelope, **not** an adopted
maximum room area, settlement extent, number of levels or old 12-cell template
limit. It takes the existing room-tile arena's order of magnitude as a safe
starting guard without claiming that arena already owns expanded underground
space. The maximum scalar shape span is 32767 cells so the integer ellipse
products stay within int64. Cells stop at `INT32_MAX - 1`, reserving their far
corners in int32; all signed negative coordinates remain distinct.

Raster bounds may visit at most four times the supplied cell limit. Route
center traversal also permits at most four times that limit; width expansion
permits at most sixteen times that limit in stamp visits. Excessive repeated
work refuses with `FOOTPRINT_CAPACITY`, without truncation. This bounds work
even when a hostile route repeatedly retraces the same area. A caller should
simplify its pointer history into route control points before calling it.

The module owns no persistent arrays, caches, entities, nodes or frame loop.
Temporary dictionaries serve membership lookups only; every emitted cell set
is explicitly sorted. At 16384 cells, each packed cell or key stream is at
most 131072 payload bytes, and exposed edge triples at most 786432 bytes.
Temporary Godot dictionary overhead is not certified by that payload
arithmetic. Callers must cache the result of each changed draft and must not
rebuild whole-room topology every render frame or once per resident.

## Integration boundaries

This helper does **not** map a paint cell to a paid excavation quantum. ECON-001
owns immutable physical **1 m³** paid cuts. In particular, using 256 fixed
units for a preview grid cannot authorize finer physical cuts or round such
cells into free excavated volume. The integrating geometry/construction
contract must provide the exact physical cut set, shape/support envelope and
finish accounting before admitting production work.

No room, service, traversal, construction, inventory or save state is mutated.
Confirmed/draft footprints and their grid/level identities still need the
integrating owner's bounded packed storage, versioned saves and canonical
hash treatment. Multi-level envelope checks, reachability, fit by body and
load, surface UVs/materials, animated workers and demo controls are later
integration work; this module does not close MOVE-G01–05 or the whole approved
underground feature.

## Verification

The dedicated suite covers exact shapes, signed coordinates and overflow,
deduplication, connected concave rooms, hole policy, boundary pinches, full
rotated item containment, opening widths and physical corner conversion. It
exhaustively checks boundary area and unit-edge conservation for all 511
nonempty 3×3 cell masks, tests every reversed route endpoint in an 11×11
neighborhood, and exercises a 16384-cell room.

After removing this isolated worktree's import cache and running the documented
headless editor import (demo assets absent), the existing strict runner selected
the new suite as a single-file shard. It reported:

```text
36 test(s), 4038 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`python3 tools/gdscript_warnings.py godot/scripts/core/room_footprint.gd
godot/test/test_room_footprint.gd --max 0` reported
`0 GDScript warning(s) in 0 of 2 file(s)`. The registry guard reported
`PASS -- 93 modules, 438 rows, 747 packed columns checked`.

This is focused module evidence, not a full-suite or integrated demo claim. The
integration owner still runs the complete no-argument suite on the composed
candidate. The focused invocation used the normal shard planner with one shard
per discovered suite; its numeric index must be recomputed because weights
change when a new test file changes size.

A Mac headless debug spot measurement used 12 repetitions at each square size:
time `rectangle(0,0,side,side,16384)` and then separately
`validation_error(cells,16384,false)` with `Time.get_ticks_usec()`, sort each
12-sample set and report element 6 plus the maximum. No frame loop or residents
participated. Native allocations and Windows/reference-floor timings were not
measured.

| Cells | Raster median, µs | Validation median, µs | Validation maximum, µs |
|---:|---:|---:|---:|
| 16 | 4 | 69 | 91 |
| 64 | 14 | 237 | 252 |
| 256 | 50 | 871 | 921 |
| 1024 | 198 | 3374 | 3420 |
| 4096 | 790 | 13100 | 13818 |
| 16384 | 3091 | 51557 | 54399 |

Using one temporary integer-key membership set for whole-boundary extraction
reduced the 16384-cell validation median from 126757 µs to 51557 µs on this
host. That is still too large for per-frame validation. Cache by draft revision
and validate topology on completed strokes/confirmation; do not present this
maximum as an interactive frame-time guarantee. `contains_cell()` retains its
allocation-free binary search for individual placement queries.

## Source

- Approved D01, D03, D05–D07, D09 and D11–D13 in
  [underground planning](../design/underground-planning/README.md).
- [Shape and surface requirements](../design/underground-planning/shape-and-surface-requirements.md),
  especially UG-SHAPE-001–005 and UG-SURFACE-001–006.
- [Movement amendment](../movement_direction_amendment.md),
  [ECON-001](../underground_economy_hazard_amendment.md) and
  [systems architecture](../systems_architecture.md), including ARCH-MEM-005.
