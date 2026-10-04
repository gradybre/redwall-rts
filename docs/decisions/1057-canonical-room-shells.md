# 1057 — Fitted room shells derive from explicit canonical cells and heights

Date: 2026-10-02 · Status: Accepted presentation foundation; production integration pending

## Decision

`demo/burrow/modular_shell.gd` derives one room's interior finish meshes from
decision 1052's canonical footprint and explicit fixed integer geometry.
It accepts actual per-cell floor/ceiling heights, caller-supplied construction
stages and deliberate openings. It owns no construction, excavation, movement,
room service, inventory or save state. The existing demo entry point and
template renderer are unchanged by this foundation.

One `ModularShell` instance caches one room identity. Its public
`rebuild(revision, spec)` returns `ok`, `error`, `revision`, four category
`ArrayMesh` resources (`floor_mesh`, `wall_mesh`, `ceiling_mesh`,
`frontier_mesh`) and packed quad counts in that order. `clear()` releases the
cached identity before rebinding. Inputs are:

| Field | Required type and meaning |
|---|---|
| `cells` | Canonical `PackedInt32Array` `[x,z]` pairs; same finite operation guard as 1052 |
| `cell_size_u`, `origin_u` | Positive integer pitch and `Vector2i` X/Z origin, in fixed 1/1024 m units; no inferred pitch |
| `floor_u`, `ceiling_u` | `PackedInt32Array`, one actual world height per cell |
| `minimum_headroom_u` | Positive owner-supplied minimum; missing/unbound clearance refuses |
| `state` | `PackedByteArray`: `SOLID=0`, `CUT=1`, `FINISHED=2`, one caller-supplied state per cell |
| `openings` | Packed quintuplets `[cell_x,cell_z,N/E/S/W,bottom_u,top_u]`; explicit empty array if none |
| `floor_open`, `ceiling_open` | Optional 0/1 byte masks with one entry per cell; absence means no aperture |

Mesh positions are emitted in world metres at the presentation boundary;
their scene instances must use an identity transform. Floor/ceiling and
wall UVs are projected from the same physical positions, in metres. Expansion
cannot normalize old UVs against a new room bounding box, stretch planks or
move existing material detail. Float32 conversion that would move a fixed
corner or collapse a thin cell refuses with `SHELL_RENDER_PRECISION` rather
than drawing plausible but incorrect geometry. A future large-world view
may implement an explicit render-origin rebase; this helper does not guess one.

## One boundary, including height changes

Each supplied void cell produces exactly one floor patch and one ceiling
patch, less intentional apertures. No triangle fan crosses a concave corner
or retained solid island. Neighbors with matching height intervals have no
interior wall. At a changed floor/ceiling, walls cover the interval difference
between the two voids. Thus a raised section has its actual riser and a lower
ceiling its actual soffit, with neither duplicate coplanar walls nor a tall
wall across the shared usable opening.

An exterior wall opening removes real wall geometry between its supplied
heights. The remaining sill/lintel meet the neighboring floor/ceiling without
shader-only hole approximations. Duplicate edges, internal edges, missing
cells, reversed heights and openings outside the wall refuse. Apertures and
wall openings cannot refer to a `SOLID` cell.

Ceiling planes are visible from above and below using one two-sided material
plane, not a second overlapping set of triangles. Walls/floors keep their
intended interior/upward front faces. The view can hide the ceiling mesh or
set its existing cutaway height without regenerating geometry or changing
authoritative walk space. These are **thin interior finish surfaces**: they
do not stand in for a priced structural roof, shoring, wall thickness,
cross-level support envelope, stair piece or settlement cap.

## Stages and caching

Only caller-supplied `CUT`/`FINISHED` cells become visible void. A boundary
against a planned `SOLID` neighbor receives a separate raw-earth work face.
Cut cells retain raw-earth surfaces; only `FINISHED` cells use the chosen
finish. No elapsed wall time, work percentage, artificial drying timer or
visual interpolation completes an excavation cell.

A repeated revision with equal input reuses all mesh resources. Changed input
under the same revision, including an in-place packed-array edit, refuses;
older revisions also refuse. A failed build preserves the previous snapshot.
Returned counters are copies; the view intentionally shares mesh resources
so material assignment does not need a geometry rebuild. Those `ArrayMesh`
resources are **borrowed cached presentation resources**: callers may assign
materials and attach meshes to view nodes, but must not clear, replace or edit
their surfaces/vertex arrays. Copying the result dictionary does not isolate a
mesh mutation. A caller needing modified geometry must provide a new valid
specification/revision or make its own independent resource copy.

The helper must be called on actual changed cell/height/opening stages, never
per resident. Large mesh rebuilds are cold work; revision caching alone does
not establish a 256-resident frame-time guarantee. The integration owner must
batch changed cells and budget or incrementally publish large revisions.

## Material study and provenance

`modular_materials.gd` offers whole-floor, whole-wall and whole-ceiling
presentation selections: earth, timber and stone. `set_finishes()` changes
those three categories atomically; `apply()` changes material references,
not mesh arrays, footprints or construction state. Room compatibility,
default combinations, ordering, delivery and installed selections remain
the integrating catalog/project owner's responsibility. No cost, work,
durability, temperature, preservation or service bonus is invented here.

The procedural shader is an **authored look-development study**, using
matte clay/earth variation, subdued timber grain/joints, and warm masonry
with physically scaled courses/flags. It uses no downloaded textures or paid
generation. Its visual feature sizes are presentation authoring choices,
not room dimensions, material recipes or clearance rules.

References actually inspected:

- DEC-038's approved
  [grounded expressive example](../art-reference/visuals/grounded_expressive_rts_example_v1.png):
  warm practical timber, weighty masonry, restrained earth tones and readable
  elevated composition. Its geometry is not a measured gameplay catalog.
- `mossflower::MF_place_brockhall_domestic_chambers`, narrative blocks 576–785,
  source `Jacques, Brian - Redwall 02 - Mossflower.htm`, unit blocks 576–785:
  root-framed domestic interiors with clay surfaces and readable storage/
  meeting use. The material study borrows the inhabited-earth intent; root
  models, props and exact finishes remain authored, not claimed source facts.
- `mossflower::MF_place_brockhall`, narrative/source unit blocks 506–521:
  an underground household/refuge and communal kitchen. No fictional place
  geometry or historical era is transplanted into the live settlement.
- [Whole-game visual direction](../art-reference/visual_direction_alignment.md)
  and the content-library authoring contract retain their stated authority.

The gallery includes finer **synthetic 256-unit** shapes to inspect stepped
curves; other specimens use synthetic 1024-unit cells. Neither activates a
production paint pitch or rounds fine shapes into ECON-001's paid 1 m³ cuts.
The physical cut ledger and finish accounting remain mandatory integration
predecessors.

## Evidence and remaining limits

The [native gallery and provenance](../design/underground-planning/evidence/modular-build/shell/validation.md)
cover rectangle, concavity, stepped rounding, bent passage, actual height
joins, an explicit wall opening, a ceiling aperture and distinct supplied
construction stages at 1280×720. All captures are native Godot frames;
none is a concept image or a village playthrough. Dedicated tests check
coverage, triangle winding, opening intervals, stage masks, UV anchoring,
headroom/refusals and revision/material independence.

Still required elsewhere: production geometry and material catalogs;
paid-cut mapping; supports and fixed stairs; save/job/room services;
actual village integration; final authored art, curved vertical profiles
and close-up material polish; streamed/incremental large-room publication;
Windows and 256-resident qualification. This foundation closes none of
MOVE-G01–05 by itself.

The parent independently reviewed source and all three native images before
commit. No blocking geometry issue was found. The visibly stepped curved
outlines and measured cold rebuilds exceeding a frame remain explicit UG09/
UG17 integration and quality work; a finer synthetic preview grid is not a
resolution of the physical excavation pricing contract.
