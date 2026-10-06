# 1208 — Kitchen off T0's far end: the authored data cannot carry it as stated (stopped for a decision)

Date: 2026-10-06 · Status: Proposed. Stopped before ADR 1202 step 2; nothing in `godot/` changed.

## Brendan's decision being implemented

ADR 1202 step 1: **the Kitchen opens off T0's far end, at the same depth.** Its first face sits at T0's far end, so
the corridor leads straight into it. Deeper rooms via stairs come later.

The planned steps 2–6 assumed a worker standing on T0 works the Kitchen's first face, then walks into the Kitchen
on cut floor (ADR 1161 stations), and that the Corridor's far opening targets the Kitchen. Reading the published
bundle (`qualified-landing-v4`) and the prefix artifact (`docs/design/underground-planning/first-entry-prefix-v1.json`)
shows three facts that stop that plan. All coordinates are source-local (surface y = 0, descent along −Z).

## Facts (measured from the published bytes)

### 1. Nothing stands past T0

- T0's LANDING datum is `[-1024,-128,-2560, 1024,-127,-2048]`: its walking surface is y = −128 and it ends at
  z = −2560.
- Cut group 1 (`CUT` row 1) removes `[-1024,-1024,-3072, 1024,0,-2048]`. The half metre z ∈ [−3072, −2560] is
  therefore open void down to the cut floor at y = −1024: an 896 u drop from T0.
- The only authored rises are the 128 u tread and the 232 u short step (ADR 1164/1172). No authored part,
  LANDING or descent spans that half metre. The artifact says so explicitly: "the residual half metre beyond T0
  remains nontraversable".

### 2. No authored work motion on T0 reaches a Kitchen face

Cubes are canonical 1024 u keys on the origin grid, so the nearest Kitchen cube at the same depth is
`[x, -1024, -4096, x+1024, 0, -3072]`, with its near face at z = −3072, the far face of cut group 1. The yaw-0
(−Z) work profiles of content 5 put their contact anchor (role 5) at the offsets below. Each root must keep its
whole stance (role 1) on T0 (z ≥ −2560):

| Profile | Stance z | Furthest root | Anchor (y, z) offset | Anchor reaches | Result |
|---|---|---|---:|---|---|
| 13 | −305…454 | −2255 | (0, −673) | z −2928, y −128 | 144 u short of the face |
| 14 | −171…454 | −2389 | (1039, −536) | z −2925, y 911 | short, and above the surface |
| 15 | −169…174 | −2391 | (707, −768) | z −3159, y 579 | crosses z −3072 only above the cube (cube top is y 0) |
| 16 | −169…174 | −2391 | (128, −448) | z −2839, y 0 | 233 u short |

So no BRACE/CUT/FINISH contact for the first Kitchen cube can be stationed on T0. The Corridor's own T0 cubes are
not worked from the deck either. Frontier stations 6 and 7 stand on the **surface** at (∓1536, 0, −2560) and work
the cubes' side faces with profiles 25 and 17 (anchor 673 u to the side, y 0).

### 3. The Corridor has no far opening to target

The structure catalog's variant has exactly one OPENING region: `[-1024,0,-128, 1024,1192,0]`, the stair top at the
surface (`V_OPENING_COUNT` = 1). `entry_plan` sends its one paired-null target, which Placements expands to the
Corridor itself. Making a far opening target the Kitchen therefore needs all of the following:

- **A new OPENING region in `structure.ugconn`.** The catalog digest is linked by grouping, recipes, Frontier and
  workpieces, so every bundle file changes. That is a full successor, not a Frontier-only one like
  `qualified-landing-v4`.
- **An existing Kitchen when the entry is confirmed.** An admitted opening's Room/section never changes:
  `Placements._update_opening_pin` only advances its revision. The current order (entry first, Kitchen after the
  prefix) cannot target the Kitchen.

## Options

1. **Recommended: cut the Kitchen the way the Corridor's own cubes are cut, from the surface.**
   - **Footprint.** The Kitchen keeps the fixture's 2 × 2 footprint at the Corridor's depth, cubes
     `x ∈ [−1024, 1024]`, `y ∈ [−1024, 0]`, `z ∈ [−5120, −3072]`. Its near face is the far face of cut group 1.
   - **Height.** The height is derived, not taken from the fixture: 1024, the trench's depth. The fixture's 4096
     would rise 3 m above the surface at this depth.
   - **Work stations.** Each of the four cubes has two exterior side faces. Its work station is Frontier station
     4/5 (or 6/7) translated by −2048 (or −3072) in z: (∓1536, 0, −3584) and (∓1536, 0, −4608). They use the same
     profiles 25/17, yaw and endpoint travel 12, and are published as surface Locations through SurfaceAnchor and
     work-area paths (G1's mechanism).
   - **Existing motion only.** Every cube uses authored motion that the T0 cubes already prove. No ADR 1161
     underground station, cut-floor standing or 232 u step is needed for this Kitchen.
   - **Limits.**
     - The Kitchen is not walkable from T0 until stairs reach the cut floor.
     - A 1 m Kitchen is open to the sky above y = 0. Whether it needs a roof belongs to later room completion.
     - The Corridor's far opening stays as authored, so the link is physical adjacency only.
   - **Optional extension.** Add a far OPENING through a catalog successor and confirm the Kitchen before the entry,
     so the opening can name it. The surface stations exist after G1, so the ordering becomes possible. This costs
     a full bundle successor and a reordering of the runtime chain.
2. **Author the descent first.** Add treads after T0 down to the cut floor, then a Kitchen 4 m tall worked from
   inside through ADR 1161 stations, as planned. This needs new assemblies, recipes and install and
   repeated-step motions that do not exist, so it stops at authored motion content.
3. **Add a same-level extension landing over the half metre past T0.** This needs a new assembly with its own
   install motion, which does not exist. Even then, profiles 13 and 16 reach past z = −3072 only in the cube's
   top band (y ≥ −128).

**Recommendation: option 1**, without the far opening for now. It is the only option that every authored motion
supports today. It also matches how the Corridor itself is dug. The opening and walk-in access come with the
stairs ("deeper rooms via stairs come later").

## What is not done

ADR 1202 steps 2–6 wait on this choice. No bundle successor was published, no runtime or foreman code changed, and
no budget was measured. Under option 1 the station planner (step 5) becomes the translation of Frontier stations
2–7 described above, and step 6 runs the existing ground-station phase loop over the Kitchen Sites. Budgets to
measure as stations land:

- SurfaceAnchor: about 434k checks, plus 57k for each Location the new air touches (ADR 1207).
- Routes: ADR 1205.
