---
name: asset-pipeline
description: Generate, normalise and import 3D unit and building assets for Redwall RTS via Meshy AI, Blender and Godot. Use whenever creating a new creature, unit, building or prop model, importing a GLB/FBX into the Godot project, fixing a model that imports lying down or sunk into the terrain, or deciding unit scale. Covers Meshy credit costs and service quirks, measuring the up axis (Z-up vs Y-up), feet-at-origin pivots, triangle budgets, and the DEC-039 species heights.
---

# Asset Pipeline — Meshy → Blender → Godot

## Before spending anything

Meshy generations cost credits from a shared pool. **Always present the cost and
wait for explicit confirmation before calling any Meshy tool that spends.**

| Operation | Credits |
|---|---|
| `meshy_text_to_3d` (meshy-5) | 5 |
| `meshy_text_to_3d` (meshy-6 / latest / lowpoly) | 20 |
| `meshy_text_to_3d_refine` (adds texture) | 10 (15 at 8k) |
| `meshy_image_to_3d` / `meshy_multi_image_to_3d`, meshy-7 / latest or meshy-6 | 20 mesh only · 30 textured · 35 with 8K texture |
| … with `ultra_mode: true` (meshy-7, single image only) | **+5** |
| … meshy-t2 (`model_type: "smart-topology"`) | 5 · 15 · 20 |
| … meshy-5 | 5 · 15 · no 8K |
| `meshy_text_to_image` / `meshy_image_to_image` | nano-banana 3 · nano-banana-2 **6** · nano-banana-pro **9** · gpt-image-2 9 text / 12 image |
| `meshy_retexture` | 10 (15 at 8k) |
| `meshy_remesh` | 5 |
| `meshy_rig` (includes walk + run) | 5 |
| `meshy_animate` | 3 |
| `meshy_convert`, `meshy_resize` | 1 |
| `meshy_check_balance`, printability analysis | free |
| Any task that **fails** | 0 — see gotchas |

Prices are from the Meshy MCP server's own instructions as of 2026-09-24. The
server's list wins if the two ever disagree; re-read it rather than trusting this
table when quoting a spend.

A full unit — generate, texture, rig, animate — costs roughly **38 credits** at
meshy-5 quality. At meshy-7, a textured image-to-3D creature plus remesh, rig and
three clips is 30 + 5 + 5 + 9 = **49 credits**, before any concept image. Check
`meshy_check_balance` before a batch.

Use **meshy-5 (5 credits)** for silhouette tests and throwaways. Reserve
meshy-7 (meshy-6 where meshy-7 fails, see gotchas) for units that ship.

## Scale tiers

Godot units are metres. Every creature is normalised to its species height so
squads read correctly beside each other.

**The anchor is fixed**: `docs/crowd_rendering_architecture.md` §9.1 specifies
prototype mouse height **1.0 m gameplay scale — "fantasy relative scale, not
biological meters."** Do not substitute a biologically plausible mouse.

**The five founding species are approved per species, not per tier** — DEC-039 in
`docs/setting_decisions.md` (`USER_CONFIRMED`, 2026-09-12). Integer units are
1/1024 m, the simulation's authoritative form; pass the metre column to
`prep_unit.py --height`.

| Species | Height | Units (1/1024 m) | vs mouse |
|---|---|---|---|
| Mouse | **1.00 m** | 1024 | 1.00× — the crowd doc §9.1 anchor |
| Mole | **0.90 m** | 922 | 0.90× |
| Squirrel | **1.15 m** | 1178 | 1.15× |
| Otter | **1.49 m** | 1526 | 1.49× |
| Badger | **2.55 m** | 2611 | 2.55× |

The mole and squirrel are **not** 1.00 m — the old "Small tier" grouping put them
at the mouse's height, and DEC-039 raised the squirrel specifically so the two
would separate.

Every other species is **unapproved**. The earlier tiers remain only as a
starting guess for them, with no authority:

| Tier (guess) | Height | Species |
|---|---|---|
| Small | 1.00 m | Shrews, voles, rats, bats, sparrows |
| Medium | 1.49 m | Hares, ferrets, weasels, hedgehogs, lizards, kestrels |
| Large | 2.55 m | Foxes, wildcats, monitors, wolverines |
| Giant | per-creature, **undefined** | Falcons, snakes, eels, water rats, shrikes |

> Settle a new species' height by eye beside the approved five, and record the
> approval in `docs/setting_decisions.md` the way DEC-039 was, before bulk
> generation. Re-running every asset later is the expensive alternative.

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
(Decision 0188 overrode this once, on 2026-09-24, because credits expiring at
midnight are wasted by not spending them. The rule stands; nothing that batch
produced is accepted.)

## The workflow

### 1. Generate

Always pass these, or you inherit defaults that fight the pipeline:

- `pose_mode: "t-pose"` — required for anything that will be rigged. **T-pose is
  Brendan's choice** (decision 0188, 2026-09-24), and it suits Meshy's
  auto-rigger. It supersedes the `pose_mode=a-pose` still written in
  `docs/planning/creature_generation_batch.md`.
- `target_formats: ["glb"]` — Godot's native path; fewer formats completes faster
- `topology: "triangle"` — real-time target, not subdivision
- `target_polycount` — do not pick one by taste; the budget is a contract (see
  *Remesh targets* below). Decision 0188's route is to generate high-poly with
  `should_remesh: false`, keeping the untouched source, then `meshy_remesh` down
  to the target as a separate 5-credit step
- `ai_model` — ask which; the cost difference is 4x

Output is an untextured **preview** mesh. Texturing is a separate paid refine.

#### Remesh targets

Triangle budgets come from the contract, never from taste:

- **Static families** (building assembly, furniture, small prop, tree / large
  vegetation, ground-cover cluster) — GAP-04's `FAMILY_TRIANGLE_CEILING` in
  `godot/assets/lookdev/lookdev_dimensions.gd`, indexed
  `family * STATIC_LOD_COUNT + lod`. Crops use `CROP_MODULE_TRIANGLE_CEILING`
  (per 2 m tile) and stockpiles `PILE_ASSEMBLY_TRIANGLE_CEILING` in the same file.
- **Creatures** — the L0 row of the LOD table in
  `docs/crowd_rendering_architecture.md` §2.7 (12,000 triangles including
  equipment). `FAMILY_TRIANGLE_CEILING` does not cover creatures.

Read the ceilings from the file each time rather than copying numbers here, and
aim a little under them. Decision 0188 records the targets it used, including why
its crop remesh (1,200) is a bake source and not the 256-triangle runtime module.

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

It rotates the model upright, scales it to the target height, moves the pivot to
the feet, exports a Y-up GLB, and verifies all three. **Exit code 1 means a
check failed — do not proceed.** Pass `--no-rotate` for input already Y-up —
which, as of 2026-09-24, is current Meshy output. **Measure the input's axis
first** (see the first gotcha); the rotation is fixed, not detected.

### 4. Import into Godot

```bash
godot --headless --path godot --editor --quit
```

Use `--path godot`. Running `godot` from the repo root opens the project
manager and silently imports nothing.

### 5. Verify it loaded

Confirm the scene actually instantiates rather than trusting a clean exit:
load `res://assets/units/<name>.glb`, instantiate, and check the
`MeshInstance3D` AABB — `size.y` should be the species height and `position.y`
should be 0.0.

## Gotchas, each one confirmed the hard way

**Meshy's up axis has changed — measure every artifact, never assume.** This
skill's original rule came from the 2026-09-05 test model
(`assets/source/test_mouse_warrior.glb`, commit a54041f): Meshy GLBs were Z-up,
violating glTF's Y-up rule, and imported lying on their backs in Blender and
Godot. The prep script's fixed +90° X rotation was written for that.
**The 2026-09-24 meshy-7 output is glTF-compliant Y-up** (decision 0188): the
high-poly sources are tallest along +Y with an identity node transform, and every
creature remesh measures exactly its DEC-039 height along +Y with feet at y = 0.
Rotating those lays them on their backs, so run `prep_unit.py --no-rotate`. The
script's `upright` check usually fails such a mistake, but not for a model that
is deeper than it is tall — many buildings are.

Measure from the GLB's JSON chunk, before Blender touches it — `POSITION`
accessor bounds, and any `rotation`/`matrix` on the mesh's node:

```bash
python3 -c 'import json,struct,sys;f=open(sys.argv[1],"rb");f.read(12);n=struct.unpack("<I",f.read(4))[0];f.read(4);j=json.loads(f.read(n));[print(j["accessors"][p["attributes"]["POSITION"]]["min"],j["accessors"][p["attributes"]["POSITION"]]["max"]) for m in j["meshes"] for p in m["primitives"]];[print(x) for x in j["nodes"] if "rotation" in x or "matrix" in x]' <file>.glb
```

**`origin_at: "bottom"` is silently ignored** unless `auto_size: true` is also
set. Without a pivot at the feet, units sink into terrain. Fix it in Blender;
do not rely on the API parameter.

**Blender's `matrix_world` is stale after a transform.** Reading bounds straight
after `origin_set` or a location change returns pre-move values and reports a
false failure. Call `bpy.context.view_layer.update()` first.

**Arm span can exceed height in a T-pose**, so "largest axis is height" is not a
safe way to detect orientation. The script applies a fixed correction instead of
guessing, which is why choosing `--no-rotate` from a measurement is your job.

### Meshy service behaviour (decision 0188, 2026-09-24)

**Failed tasks cost 0 credits.** A failed task reports `consumed_credits: 0`, so
retrying a failure risks nothing if it fails again.

**meshy-7 fails on thin geometry** with `RepairDidNotCloseError` — nets, poles,
open frames (the fisher shelter had 6,922 open edges and failed twice). **meshy-6
on the same concept succeeded.** Some failures are transient: the well, log stack
and hearth each failed once and succeeded on regeneration. Retry meshy-7 once,
then fall back to meshy-6 at the same price.

**The rate limit is roughly 10–14 requests per burst.** Beyond that, calls return
"Rate limit exceeded"; a few seconds' wait clears it. Pace batches.

**Long robes defeat the auto-rigger.** `meshy_rig` returns `422 Pose estimation
failed` when the legs are hidden (the robed badger steward). The same species in
trousers rigged first time. Design anything to be rigged with visible legs.

**The Meshy rig is a generic 24-joint humanoid** (counted from the rigged GLB's
skin): no tail bones, no fingers, and none of the crowd doc's sockets
(`socket_main`, `socket_off`, `socket_head`). It is a head start and an animation
reference, not the production `rig_<species>_v1`.

**Meshy's automatic remesh shatters foliage and thin woven geometry** at game
budgets — bramble, fern, wildflower patch, birch, apple tree, bean poles and a
basket rim all broke apart while their high-poly sources were sound. Do not pay
to remesh foliage; build its L0 in Blender as alpha leaf cards (the GAP-07
vegetation question).

**Rig and animation downloads save no file.** For those task types
`meshy_download_model` returns signed URLs only, and they expire in about 28
hours. The task persists, so asking again produces fresh URLs; fetch them yourself
and record the task ID, not the URL.

**`meshy_list_tasks` ignores its `status` filter** and returns every status.
Filter the results yourself.

## Binary assets

`*.glb`, `*.gltf`, `*.fbx`, `*.obj`, `*.stl`, `*.blend`, `*.usdz`, texture
formats (png, jpg, jpeg, tga, exr, hdr, basis, ktx2) and audio (wav, mp3, ogg)
are tracked with **Git LFS** — see `.gitattributes`, and confirm a path with
`git check-attr filter -- <path>`. New binary asset types must be added to LFS
tracking *before* their first commit — converting existing history later means a
rewrite.

Read `.gitattributes` whole, not through `head` — `*.glb` is line 11, and a
truncated read once produced the false claim that GLBs are not LFS-tracked.

The Meshy **asset library** is not committed at all: decision 0188 keeps its
binaries in gitignored `assets/library/` and commits only the ledger — task IDs,
parameters, credits, prompts and SHA-256 list — in
`docs/art-reference/asset_library/`. Any file is re-downloadable from its task ID.
The reason is size: *because* `*.glb` is LFS-tracked, committing the 13.7 GB
library would charge it against GitHub's 1 GB free LFS tier.

## Directory layout

```
assets/library/         Provisional Meshy library — gitignored, not accepted (decision 0188)
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
