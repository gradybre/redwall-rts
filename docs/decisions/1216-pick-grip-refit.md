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

## Brendan's decision (2026-10-07)

**A curled paw for the pick-holding sources only** (option 2). The tool-free haul sources keep the current closed
paw, so their certified wood and stone grips stand.

The work runs as reviewed steps:

1. Author the curled-claw paw. It is a fixed mesh change and a successor to `mole_grip_source.gd`'s closed paw. The
   claws curl around a bar across the paw at `lateral-1`'s shaft position, derived from the pick's shaft radius
   and the paw geometry, with no external art.
2. **Stop for Brendan's visual review** of the paw on the shaft. Close-ups from the front, side and top at one
   zoom: the current fit, the curled paw holding the pick, and the paw alone.
3. Only after approval:
   - re-bake the grip palette with the native Godot bake (`rebake.py` → `tools/bake_mole_grip_content.gd`) into
     `mole-grip-v4.ugpal` and its import archive;
   - add per-source paw presentation for sources 0 and 1;
   - write the successor grip exclusion and the exact grip proof;
   - run native capture;
   - re-run the tread install tap.

## Step 1 — the curled paw (authored; stopped for Brendan's review)

`author_curled_paw.py` writes `curled-paw-v1/`. It derives the shape from the paw before the accepted closing; the
closing inverts exactly per vertex, so the round trip is 0.0 m. Every step reuses an accepted number or measures
the mesh:

- **Thin the fingers.** The accepted closing's profile (start 0.025 m, span 0.105 m, 70%) narrows thickness only.
- **Rest the shaft on the palm.** It sits on the smooth +Z palm at the accepted socket's height (y = 0.078 m), with
  the pick's own radius of 0.028 m. Its axis is at z = 0.070 m. The pick fit follows as "lateral-2".
- **Curl.** Each finger cross-section turns about the shaft axis by its arc length over the neutral radius
  (0.050 m). The claws reach about 101°. 841 vertices move.

Float witnesses: 66 paw vertices touch the shaft's surface shell, covering 105° around it, and 8 lie inside it.

**Review packet:** `curled-paw-review-v1/`. It holds `grip.png` (the accepted grip beside the curled paw on the
pick, front, side and top at one zoom), `paw-alone.png` and `README.md`. `test_curled_paw.py` holds 4 tests.

## Plan after approval (not run)

1. **GDScript port.** A successor to `mole_grip_source.gd` that applies the approved deformation to the true
   original mesh, with analytic normals and tangents as the accepted one has. It refuses any other source
   fingerprint and pins the new derived fingerprint.
2. **Per-source paw.** `entry_worker_meshes.gd` and the mole presenter (ADR 1201) give sources 0 and 1 the curled
   paw. Sources 2 and 3 keep the accepted one. The memory census adds the second derived mesh.
3. **Native bake.** `rebake.py` → `tools/bake_mole_grip_content.gd` (native Godot) writes `mole-grip-v4.ugpal`
   and its import archive, with the curled paw and the lateral-2 fit. Proofs and authors for the pick sources get
   a successor source set; the haul authors keep v3.
4. **Grip exclusion and exact grip proof.** A successor to `prove_self_clearance.body_triangle_ids` for the
   curled region, plus an exact proof of palm contact on the shaft, claws around it, and no other penetration.
5. **Native capture and review, then the tread install tap re-run.** Rows 2–29 are re-authored later.
