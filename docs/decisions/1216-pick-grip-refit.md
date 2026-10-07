# 1216 — Re-fitting the mole's pick grip: a fit can move, a wrapped paw needs new art

Date: 2026-10-07 · Status: Proposed. A fit-only successor is authored. A true wrap is stopped for Brendan's
choice.

## Brendan's decision being implemented

In the ADR 1209 step 4 review of revision 3 (`tread-install-review-v3/grip-comparison.png`), Brendan chose to
**re-fit the pick grip**. He wants the paw wrapped around the shaft lower down, with the fingers and thumb around
it, instead of the handle's end butting into the palm. Applying the new grip to the accepted cut and install
motions (profile rows 2–29) comes **later**. Until then they keep the accepted fit.

## How the accepted grip was made (read from the sources)

| Piece | Where | What it is |
|---|---|---|
| Source pick fit | the cast's pick binding (`pick_binding` in the rig record) | Uniform scale 0.2892. The grip point is `prop_local_grip_m` (0.6846, 0.1948, 0) on the pick. Digest `3d61abcc…` (`mole_grip_source.gd FIT_DIGEST`). |
| Socket offset | `mole-worker/evidence/grip-authoring/README.md`, chosen from native comparisons in `grip-closed-v4` and `grip-angles-v1` | Hand-local translation `(-40, 80, 5)/1024` m applied before the source fit. |
| Closed paw | `godot/data/underground/mole-worker/mole_grip_source.gd` | The rig has one rigid hand bone and **no finger bones**, so the closed paw is a fixed mesh derivative. It moves the 845 hand-weighted vertices with hand-local y > 0.025 m: 70% narrower and 15% shorter, toward the socket's line along hand-local Y. Fingerprint goes from `a938d479…` to `29f8d321…`. |
| Grip palette | `grip-source-v3` (`rebake.py` → `tools/bake_mole_grip_content.gd`, a native Godot bake) | `mole-grip-v3.ugpal` (`08de5453…`) and its import archive. Every proof's source closure reads it. |
| Grip proof | `grip-proof-v2/envelopes.json` | Continuous palette envelopes for the gripped states. |
| Grip exclusion | `prove_self_clearance.body_triangle_ids` | Excludes only triangles wholly inside that 845-vertex patch. The vertex count is pinned (`SELF_AUTHORED_GRIP_PATCH_DRIFT`). |
| Presentation | `demo/cast/entry_worker_meshes.gd` | Applies the closed-paw derivative to the body of **all four** profile sources, including the tool-free haul sources (2 and 3), whose wood and stone two-hand grips were certified against this paw. |

**Measured.** In the accepted fit the shaft runs along the paw's finger axis, hand-local −Y, through the socket.
The handle's end sits at hand-local y ≈ 0.001 m, the base of the palm. The closed paw is shaped for exactly that:
its fingers close toward a line along Y. That is the end-in-palm look Brendan rejected.

## A fit-only successor (authored)

`author_pick_refit.py` derives a new hand-to-pick transform and changes no mesh, palette, rig, fit or evidence.
`pick-fit-v1/` holds the result:

- **Scale.** The accepted 0.2892.
- **Shaft centre line.** The binding's own grip line.
- **Crossing point.** The shaft crosses the paw through the accepted socket point along hand-local X, the paw's
  widest axis (0.191 m).
- **Head direction.** The head points forward along the finger axis (+Y).
- **Handle end.** It stands out one shaft diameter (0.056 m) past the paw's edge.

| Successor | Head toward | Grip point on the pick (x) | Ready carry, accepted self-clearance | Patch vertices inside the shaft | Wrap cover around the shaft |
|---|---|---:|---|---:|---:|
| `medial-1` | the paw's medial side (toward the body midline, the expected thumb side) | 0.553 | **refused**: the re-held pick meets the body | 263 | 255° |
| `lateral-1` | the lateral side | 0.298 | **clear** | 263 | 255° |

The accepted grip point is at 0.685, so both successors hold the pick lower down. `grip-refit-probe.png`
(`fb8cbd9f…`) shows the accepted fit and both successors at the ready carry, at one zoom.

**What it looks like.** The shaft passes across the closed paw's front and the claws stay extended past it. The
derivative's fingers close toward a line along Y, not around a bar along X. The fit moves, but nothing wraps:
fingers around the shaft need a different paw.

## What a wrapped paw needs (stopped here)

1. **New art.** A successor paw derivative that curls the distal paw (claws) around a cylinder along hand-local X
   at the new socket. Without finger bones this is a fixed mesh variant, authored the way the accepted contraction
   was, with its own fingerprint and normal and tangent rules.
2. **A presentation decision.** The paw derivative is shared by all four sources today. Changing it globally would
   change the paw that the wood and stone two-hand grips were certified on (ADRs 1198 and 1206). The alternative
   is a per-source paw, the curled one for pick sources 0 and 1 only, which extends ADR 1201's per-source
   presentation to the mesh.
3. **A new grip-palette bake.** `rebake.py` with the native Godot bake produces `mole-grip-v4.ugpal` and its
   archive. Every proof that reads `mole-grip-v3.ugpal` gets a successor source closure.
4. **A successor grip exclusion.** The self-clearance proof's 845-vertex predicate is pinned, so it needs a
   successor for the curled region. It also needs an exact grip proof: palm contact on the shaft, claws around it,
   and no penetration beyond the exclusion.
5. **Native capture and review.** Then the tread install tap is re-run on the new grip. Rows 2–29 come later.

## Options for Brendan

1. **Fit only (`lateral-1`, no new art).** The pick crosses the paw lower down and the claws stay straight. The
   tread tap can be re-run on it now. The descent and walk clips keep the accepted fit, so the pick visibly
   re-seats at the start and end of the install.
2. **Recommended: a curled pick paw for the pick sources only** (items 1, 2-per-source, 3, 4, 5). The fingers
   really wrap, and the haul grips stay as certified. It is new art plus a native bake and capture, done in its
   own steps with reviews.
3. A curled paw for every source. This re-opens the certified wood and stone grips. Not recommended.

## Scope

No accepted fit, palette, mesh derivative, proof or motion was changed. Rows 2–29 and the haul sources keep the
accepted grip.
