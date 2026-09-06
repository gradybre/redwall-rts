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
squads read correctly beside each other. Tiers follow the roster in
`docs/game_concept.md`.

| Tier | Height | Models/squad | Species |
|---|---|---|---|
| Small | **0.55 m** | 40–60 | Shrews, mice, moles, voles, rats, squirrels, bats, sparrows |
| Medium | **0.82 m** | 30–40 | Otters, hares, ferrets, weasels, hedgehogs, lizards, kestrels |
| Large | **1.40 m** | 10–15 | Badgers, foxes, wildcats, monitors, wolverines |
| Giant | **2.40 m+** | 1 | Falcons, snakes, eels, water rats, shrikes |

> These heights are **provisional** — set once, by eye, in an actual scene with
> two tiers side by side. Changing them later means re-running every asset, so
> settle them before bulk generation. Giant is per-creature, not a single value.

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
  --height 0.55
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
