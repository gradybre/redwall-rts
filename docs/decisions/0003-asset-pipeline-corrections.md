# 0003 — Meshy output needs three corrections before Godot
Date: 2026-09-05 · Status: Accepted

## Decision
No Meshy GLB goes into `godot/assets/` directly. Everything passes through
`.claude/skills/asset-pipeline/scripts/prep_unit.py`.

## Why
Three defects, each found by pushing one 5-credit test model end to end:

1. **Meshy writes GLB Z-up**, violating glTF's Y-up convention. Blender's
   importer applies its standard Y-up→Z-up rotation regardless, so models arrive
   lying on their back — and Godot does the same. Affects every model.
2. **`origin_at: "bottom"` is silently ignored** unless `auto_size: true` is also
   set, leaving the pivot on the centroid. RTS units then sink into terrain.
3. **Meshy returns arbitrary sizes**, so units must be normalised per tier.

## Consequences
- The script rotates, scales, re-origins, exports Y-up, and verifies all three,
  exiting non-zero on failure. Both exit paths are tested.
- **Facing cannot be automated.** This project uses −Z forward; glTF conventionally
  uses +Z front. A model can pass every automated check and still face backwards.
  Check by eye, and use `use_model_front=false` on presentation roots.
- Blender's `matrix_world` is stale after a transform — call
  `bpy.context.view_layer.update()` before re-measuring or you get false failures.

## Source
Measured on task `01a07405-1408-7299-92a4-6b8cc7ea8de8`, 2026-09-05.
Conventions from `docs/crowd_rendering_architecture.md` §9.1–9.2.
