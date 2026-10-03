# 1070 — Fixed connector geometry and material surfaces

2026-10-03 · UG08 engineering increment · independently reviewed cold helper

## Context

Approved underground D04/D05 includes earth/timber steps, stone stairs, ramps,
spiral stairs and timber ladders with hatches. Players place a complete authored
variant at its exact rise; no dimension may be stretched to hide a mismatch.
Decision 1058 transforms full integer volumes but does not author or draw the
actual treads, ramps, rails, central posts, rungs or moving hatch.

The measured 1063/1067 source spheres are conservative source bounds, not useful
production connector dimensions. Actual runtime capture in
`profiles/runtime/` now measures final staged imports and their pose/attachment
implementations, while retaining continuous residual and state-binding gaps.
No numerical connector size, slope, stair/rung spacing, load permission, recipe
or labor constant is adopted by this increment.

## Decision

Add a bounded cold integer geometry compiler over explicitly authored convex
prism parts. Top polygons have exact integer XYZ vertices and a common vertical
thickness. Flat treads, stone blocks, timber risers, shaped spiral treads,
sloping ramps, rails, posts, ladder uprights/rungs and a hinged hatch share this
representation. A ramp's top remains an actual slope; a spiral is authored with
integer ring-sector vertices and a central support. No trigonometric float
chooses authoritative geometry.

The row retains the existing fixed connector metadata and complete authored
RoomSpace contact/opening/landing/support/cut contract. The compiler adds each
physical part's conservative integer SOLID box and the moving hatch's complete
quarter-turn sweep. Geometric outward enclosure does not round or create a paid
1024u excavation cube. All cuts remain explicitly authored against the actual
immutable datum and are validated later by RoomSpace and the live authority.

The renderer consumes exactly those compiled triangles. Material IDs and repeat
periods are explicit inputs; UVs use distance in metres along the face, including
sloping surfaces, rather than fitting one texture to any arbitrary room size.
Surface triangles end at the authored polygons. A hatch has its real pivot and
a presentation-only open fraction; its whole motion envelope remains reserved.
Materials themselves come from the caller's reviewed assets, not a new default
palette or invented gameplay material effect.

Compiler triples retain their canonical outward cross-product orientation.
The Godot renderer emits the clockwise front-face order while retaining the
outward normal. Material copies clear their next-pass chain, vertex growth,
billboard and fixed-size options, and use back-face culling. The caller's source
material remains unchanged; a second shader pass cannot escape the compiled
boundary or silently alter the UV contract.

All inputs have finite, caller-selected capacities under hard cold-operation
ceilings. Integer bounds are checked before packing/narrowing; malformed,
nonplanar, concave, missing-contact or incomplete family content refuses with
no partial candidate. These engineering caps are not production dimensions or
a measured frame-time budget. The compiler has no persistent world state,
inventory, paid work, route publication or accepted movement permission.

## Qualification boundary

Synthetic test variants exercise all five families and never become shipped
production catalog rows. Actual production rows still need authored dimensions
grounded in qualified required travel/turn/load states, support truth, complete
recipes and live owner binding. The library/compiler being present does not
close UG08 or the movement gates. Raised/sunken room offsets and main level
spacing remain with their owning numerical authoring contract.

## Verification

The isolated worktree's assets were moved aside, its `.godot` directory was
deleted, and `godot --headless --path godot --editor --quit` completed before
the strict focused shards. Assets were restored afterwards. The unchanged
strict runner reported:

```text
13 test(s), 101 assertion(s), 0 failure(s)
8 test(s), 16536 assertion(s), 0 failure(s)
```

For **each** suite it reported both:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer on port 6149 reported `0 GDScript warning(s) in 0 of 4 file(s)`.
Tests cover all five families, exact integer plan retention, malformed and
nonplanar inputs, bounded refusals, clockwise fixed/leaf rendering, physical UV
distances, immutable material sources and the complete hatch sweep at every
hinge edge. The root agent independently reviewed the source and accepted the
final four source/test hashes after its winding and next-pass findings were
fixed.

The native Godot 4.7.2 OpenGL Compatibility renderer also produced and was
visually checked at an actual 1280×720 viewport: all five synthetic families
are visible with back-face culling and metre-scale checker materials. It
reported `connector capture: 5 synthetic families, 1280x720, save 0`, with no
error, warning or leak lines. This checks renderer behavior; these intentionally
synthetic fixtures are not production visual-quality or traversal acceptance.

Raw import, strict suite, analyzer and native evidence, including hashes, live
under [the runtime evidence directory](../design/underground-planning/evidence/modular-build/profiles/runtime/connector-verification/evidence.json).
The earlier failed `grow_enabled` amendment is retained there: its nonzero
diagnostic/leak counts are a failure, not part of the passing claim. The final
source uses Godot's actual `grow` property. The separate sampled runtime actor
capture remains a following implementation and review scope.

## Follow-up: actual staged runtime profile capture

Add `tools/capture_underground_profiles.gd` and its adversarial Python tests,
with reproduction and evidence under the existing `profiles/runtime/` path.
Existing staging/import tools run unchanged against the read-only source
library, using only the isolated worktree's ignored assets/cache. No paid
generation or change to the original library is involved.

The capture reads actual imported bodies, remapped animation tracks, all
four/eight skin influences, final modifier poses and actual fitted held meshes.
It records the imported Skin name/index mapping and compares each captured
matrix against the native renderer's uploaded palette. The `skeleton_updated`
signal precedes that upload, so the comparison runs in the following deferred
callback using retained final matrices. The next pose cannot advance until
that comparison completes. This ordering was measured, not inferred from a
matching node name or a rest-pose bounding box.

Every directly loaded import, generated scene, literal script-load dependency,
project autoload and capture/staging implementation is source hashed. Missing
species, clip, life-stage binding, imported-scene pin or attachment refuses
rather than borrowing another state. The whole output bundle is preflighted before any write, then input, report,
log and verification are create-only. A fresh output directory is required
for another batch; refusal preserves manifests and source bytes through aliases.
Body and attachment vertex/surface budgets bound the offline workload.

An intermediate run exposed an ArrayMesh-only API being called on the demo's
actual CylinderMesh log. Godot emitted script errors, continued with omitted
attachments and exited zero. That run is preserved as rejected evidence. The
corrected helper explicitly handles ArrayMesh and PrimitiveMesh, and a strict
outer verifier now requires complete identities/attachments, native palette
observations and zero raw diagnostics/leaks before accepting any batch.

Independent review also found that the warm-up had completed both non-looping
hammer clips before sampling. That rejected batch and its old verification are
preserved separately. The tool now restarts the source clip at sample zero,
records its observed timeline and checks exact expected pose/palette totals.
Both actual hammer cases span all 58 expected samples from zero to the source
endpoint and prove nonzero bone-pose changes. This is an explicit reset; it
does not qualify the reset transient or continuous intervals.

The corrected candidate completed **47 cases / 3736 sampled poses / 522 source
pins / 107040 exact observed native matrix comparisons**, with **zero unexpected
diagnostics and leaks**. The 30 adversarial tests pass; the tool's analyzer
reports `0 GDScript warning(s) in 0 of 1 file(s)`. Raw command/output/source
evidence is retained in the runtime directory for independent review.

These are presentation measurements only. They do not establish continuous
motion or GPU numerical residuals, transition/recovery coverage, actual
resident life-stage and gear/cargo identities, authoritative state costs,
root/support contacts or an accepted profile revision. Sampled bounds never
become integer gameplay clearances or catalog dimensions. This follow-up does
not close UG08 or MOVE-G01–05 and adds no new gameplay policy.
