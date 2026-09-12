---
name: asset-pipeline
description: Generate, normalise and import 3D unit and building assets for Redwall RTS via Meshy AI, Blender and Godot. Use whenever creating a new creature, unit, building or prop model, importing a GLB/FBX into the Godot project, fixing a model that imports lying down or sunk into the terrain, or deciding unit scale. Covers Meshy credit costs, the Z-up axis correction, feet-at-origin pivots, and the size-tier scale table.
---

# Asset Pipeline — Meshy → Blender → Godot

## Before spending anything

Meshy generations cost credits from a shared pool. **Always present the cost and
wait for explicit confirmation before calling any Meshy tool that spends.**

| Operation | Credits |
|---|---|
| `meshy_text_to_3d` (meshy-5) | 5 |
| `meshy_text_to_3d` (meshy-6 / latest) | 20 |
| `meshy_text_to_3d_refine` (adds texture) | 10 (15 at 8k) |
| `meshy_image_to_3d` + texture | 15–35 |
| `meshy_rig` (includes walk + run) | 5 |
| `meshy_animate` | 3 |
| `meshy_check_balance`, printability analysis | free |

A full unit — generate, texture, rig, animate — costs roughly **38 credits** at
meshy-5 quality. Check `meshy_check_balance` before a batch.

Use **meshy-5 (5 credits)** for silhouette tests and throwaways. Reserve
meshy-6 for units that ship.

## Scale tiers

Godot units are metres. Every creature is normalised to its tier height so
squads read correctly beside each other.

**The anchor is fixed**: `docs/crowd_rendering_architecture.md` §9.1 specifies
prototype mouse height **1.0 m gameplay scale — "fantasy relative scale, not
biological meters."** Do not substitute a biologically plausible mouse.

| Tier | Height | Source | Species |
|---|---|---|---|
| Small | **1.00 m** | crowd doc §9.1 | Shrews, mice, moles, voles, rats, squirrels, bats, sparrows |
| Medium | 1.49 m | **derived, unconfirmed** | Otters, hares, ferrets, weasels, hedgehogs, lizards, kestrels |
| Large | 2.55 m | **derived, unconfirmed** | Badgers, foxes, wildcats, monitors, wolverines |
| Giant | per-creature | **undefined** | Falcons, snakes, eels, water rats, shrikes |

> Only Small is sourced. Medium and Large are the small anchor scaled by 1.49
> and 2.55 — ratios chosen for readability, confirmed by nothing. No document
> states a height for any species but the mouse. Settle the remaining tiers by
> eye with two side by side before bulk generation; re-running every asset later
> is the expensive alternative.

## Coordinate and naming conventions

From crowd doc §9.1, and **not optional** — these are project conventions that
deliberately differ from the usual Godot/glTF defaults:

| Field | Required value |
|---|---|
| Blender units | Metric, unit scale 1.0, 1 unit = 1 m |
| Simulation convention | Godot **+Y up, −Z forward, +X right** |
| Authoring convention | Blender +Z up, +Y forward, +X right |
| Axis conversion | `(x_g, y_g, z_g) = (x_b, z_b, −y_b)` |
| Origin | Ground contact centre between the feet |
| Transforms | Applied; scale exactly (1,1,1); no negative determinant |
| Topology | Triangulated before bake |
| Naming | `species_mouse_body_a_lod1`, `rig_mouse_v1`, `clip_attack_a`, `socket_main` |

**Facing is the one thing the script cannot verify.** glTF's common convention
is +Z front; this project uses −Z forward. The crowd doc requires applying the
conversion once and validating against a "face north" fixture, and using
`use_model_front=false` on presentation roots — do **not** let `look_at()` add a
second 180° rotation. Check facing by eye after import; a model that is upright,
correctly scaled and backwards passes every automated check in the script.

Crowd doc §9.2 also fixes the generation order: **produce one body and one sword
first and validate the bake before generating further species.** Do not batch.

## The workflow

### 1. Generate

Always pass these, or you inherit defaults that fight the pipeline:

- `pose_mode: "t-pose"` — required for anything that will be rigged
- `target_formats: ["glb"]` — Godot's native path; fewer formats completes faster
- `topology: "triangle"` — real-time target, not subdivision
- `target_polycount` — 8000 is a reasonable base for a hero unit; crowd units want far less
- `ai_model` — ask which; the cost difference is 4x

Output is an untextured **preview** mesh. Texturing is a separate paid refine.

### 2. Download to `assets/source/`

Raw Meshy output is kept out of the Godot project — it is the unprocessed
original, and Godot should never import it directly.

```
save_to: /Users/brendan/Developer/redwall-rts/assets/source/<name>.glb
```

### 3. Normalise

One command. Runs headless, needs no Blender MCP connection:

```bash
blender --background --python .claude/skills/asset-pipeline/scripts/prep_unit.py -- \
  assets/source/<name>.glb \
  godot/assets/units/<name>.glb \
  --height 1.00
```

It rotates the model upright, scales it to the tier height, moves the pivot to
the feet, exports a Y-up GLB, and verifies all three. **Exit code 1 means a
check failed — do not proceed.** Pass `--no-rotate` for input already Y-up.

### 4. Import into Godot

```bash
godot --headless --path godot --editor --quit
```

Use `--path godot`. Running `godot` from the repo root opens the project
manager and silently imports nothing.

### 5. Verify it loaded

Confirm the scene actually instantiates rather than trusting a clean exit:
load `res://assets/units/<name>.glb`, instantiate, and check the
`MeshInstance3D` AABB — `size.y` should be the tier height and `position.y`
should be 0.0.

## Gotchas, each one confirmed the hard way

**Meshy GLBs are Z-up, violating the glTF spec.** glTF mandates Y-up. Blender's
importer applies its standard Y-up→Z-up rotation anyway, so the model arrives on
its back — and Godot does the same. This affects every Meshy model, not some.
The prep script's +90° X rotation is not optional.

**`origin_at: "bottom"` is silently ignored** unless `auto_size: true` is also
set. Without a pivot at the feet, units sink into terrain. Fix it in Blender;
do not rely on the API parameter.

**Blender's `matrix_world` is stale after a transform.** Reading bounds straight
after `origin_set` or a location change returns pre-move values and reports a
false failure. Call `bpy.context.view_layer.update()` first.

**Arm span can exceed height in a T-pose**, so "largest axis is height" is not a
safe way to detect orientation. The script applies a fixed correction based on
Meshy's known behaviour instead of guessing.

## Binary assets

`*.glb`, `*.fbx`, `*.blend`, and texture formats are tracked with **Git LFS**
(see `.gitattributes`). New binary asset types must be added to LFS tracking
*before* their first commit — converting existing history later means a rewrite.

## Directory layout

```
assets/source/          Raw Meshy output, unprocessed originals
godot/assets/units/     Normalised, Godot-ready creature GLBs
godot/assets/buildings/ Normalised structure GLBs
```

## Supplied-reference authorization

Brendan authorizes direct use of supplied images/material, including IMG-25,
for image-to-image and reference-guided builds (DEC-036 in `docs/setting_decisions.md`).
Do not reduce supplied references to observe-and-describe-only because creator
metadata is unknown. Record provenance; source mechanics and paid generation
authorization remain separate. UI art follows `docs/design/ui_refinement/asset_generation_lock.md`.
