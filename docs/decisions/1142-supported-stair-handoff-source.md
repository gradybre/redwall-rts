# 1142 — Supported stair handoff source

Date: 2026-10-04. Status: approved source-authoring experiment; no runtime,
pace, physical-profile, budget or traversal qualification.

## Decision and ownership

Author and prove the missing finite motion around the accepted 128u stair
sources: L0 ready-to-descent approach, T0 reposition and half-turn, and
ascent-to-L0 retreat. Retain the original ascent, descent, meshes, rig lengths,
materials, grip, fourteen timber parts and eight bearing parts unchanged.
The approved DEC-038 visual reference remains the quality target.

This lane owns new `author_stair_handoffs.py`, `test_stair_handoffs.py`,
`prove_stair_handoffs.py`, `test_stair_handoff_proof.py` and
`stair-handoffs-v1/`, all under the mole worker's `contact-qualification/`
directory. Root owns publication and all eight current profile consumers.
No accepted 1139 table, live reader, renderer or profile is edited here.

## Exact episode and coordinate frames

The root-authored 1113 fixture is the fixed program frame. Its descent starts
at `(0,0,-1879)` facing yaw0 and ends at `(0,-128,-2391)`. The separately
accepted ascent starts at `(0,-128,-2217)` facing yaw32768 and ends at
`(0,0,-1705)`. Thus a return requires an actual 174u displacement and half-turn,
not a terminal rebase. The candidate also authors a 343u approach from a
safe L0 ready root `(0,0,-1536)` and a 169u retreat to that root. These are
source candidates, not permission to stand or move on unpublished timber.

Each finite key carries integer program-root XYZ, unwrapped integer heading,
local palette, grounding, and explicit per-foot plant/swing data. All readers
use one Q16 phase: adjacent keys ordinarily, identical terminal keys and
share0 at the end. Preserve stationary-root and stationary-heading intervals.
Source preview duration does not determine an authoritative movement rate.

The root track is in the fixed program frame. Evaluate signed componentwise
ceil of its rational interpolation once. Local skin/palette and grounding are
in the moving body frame; rotate them by the exact finite WorldBasis entry
selected by the integer interpolated heading. Add the fixed-frame root only
after that body rotation. Any separately certified Placement orientation and
world translation apply to the resulting program point. The moving heading
must neither rotate the root track nor be baked into and reapplied to the
palette. Tests must distinguish those erroneous equations.

All complete endpoint palette/grounding values, fixed root and heading must
match the adjoining accepted source exactly. A visually close pose or a
reset at a clip boundary is insufficient. Ordinary all-yaw ground stance is
812u deep and cannot stand in for supported travel on a 512u tread.

## Source construction and proof

Use the supplied rig's actual two-segment legs and original ankle/toe links,
proper joint rotations, an explicit finite footfall sequence, and whole-foot
sole solving. A planted foot stays at its authored fixed-frame station while
the pelvis turns; a moving foot lifts and places visibly. Source changes must
retain every original body, clothing and tool primitive. No whole-body AABB,
cropped triangle, shortened limb, invented contact tolerance or raised deck
can substitute for the complete proof.

Heading changes make the world equation nonlinear in source phase. Endpoint
linear hulls alone are therefore insufficient. The verifier must enclose
the complete finite heading table range and coupled source interpolation,
with bounded subdivision and refusal on exhaustion. Full triangle collision
against all exact positive fixture prisms and full anatomical foot projection
plus an actual continuous contact witness remain independent requirements.
All support is in the fixed program frame; full foot 3D geometry is retained.
Numeric residuals keep their exact inherited backend and root scope. Metal
input census1138 is not a Metal deformation certificate.

Keep missing proof, genuine collision, source drift and failed candidates as
explicit refusals. Historical source reconstruction may use only the unchanged
accepted 1139/1137 adapter and its exact pinned input tuple. Hash current files
before and after; never modify live sources to make old proof pass. Outputs
are bounded and create-only. Independent source review precedes any native
capture extension or runtime adoption.

## Memory and remaining gates

Emit actual new key, palette, root, heading, foot/support and primitive counts,
deduplication mappings, live/load/replacement/caller storage and presentation
decode overlap. No runtime arena is allocated. The reported 8,386-byte joint
headroom does not authorize these tables; 1139's 42,704-byte proposal already
exceeds it before native controls. Capacity reduction or reclaimed reservations
requires a separate reviewed owner plan. Whole-client native memory remains
unmeasured. No gameplay pace, wood cost or production flag changes here.

Actual paid part identities, default-backend arithmetic, native visual quality,
full episode support, authoritative Routes phase/save semantics and performance
remain required after offline source proof. A supported source candidate does
not by itself grant a first-prefix or return route.

## Authority

Root's explicit 1142 assignment and Geometry's finite-heading/shared-phase
contract; accepted 1113 fixture, 1139 source tables and the separately reviewed
ascent/descent evidence. Settlement integer movement and source/physical
qualification requirements remain unchanged.

## Candidate 6 source result and retained refusals

The finite candidate now has 91 approach, 271 turn/reposition and 91 retreat
keys. Complete triangles and full-foot support pass all 450 new intervals
against all 22 unchanged fixture prisms: 4,791 bounded terrain checks. The
accepted finite inverse-heading self-contact method also passes 2,610 checks
against the non-palm body. Exact source root/heading/palette joins to the two
accepted gaits pass. These are offline results pending independent review,
not a native or World traversal certificate.

The original approach overreach is retained: 256.48586u requested against
actual links totaling 253.52264u. Later rejected candidates retain higher-deck
intersections. The final flat-step source uses 32u rather than 64u foot lift,
with no change to the accepted ascent/descent, rig lengths, collision tolerance
or physical fixture. Candidate 6 preserves candidate 5's exact F32 palette and
grounding bytes while correcting the endpoint diagnostic metadata to reflect
the unmodified ready pose. Its right foot is slightly raised; only the actual
left-foot contact is declared at endpoints.

The separate offline helper `stair-handoffs-v1/summarize_program.py` checks all
four joins and emits only an unadopted column proposal and census. The measured
3 program rows, 453 keys, 450 intervals, 681 unique boxes, 306 support records,
450 support references and 22 solids cost 48,548 numeric bytes per bank;
simultaneous banks plus decode/caller scratch cost 101,368 bytes before native
controls. Root's latest logical headroom is 5,314 bytes after 1141 controls,
excluding pending 1140. Existing 1139's distinct 42,704-byte proposal is not
replaced or absorbed. No live owner is allocated; capacity/reuse needs its own
reviewed design. The source-presentation estimate and every refused iteration
are retained in `stair-handoffs-v1/README.md` and its pinned packet.

The new diagnostic `stair-handoffs-v1/diagnose_refusals.py` is sampled authoring
evidence only. It cannot grant a clear result or substitute for the full
continuous proof. The four primary author/proof/test files and these two small
helpers are new files inside the approved lease; no existing consumer changed.
