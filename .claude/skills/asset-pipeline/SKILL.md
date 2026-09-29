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

### 6. Rigged creatures: the post-processing chain (mandatory)

**Never play Meshy's rigged or animation files as they come.** Every one has
defects that show on screen. Run these four tools in order, over the whole
creature library, whenever a creature is rigged, re-rigged or given new clips:

```bash
python3 tools/author_water_clips.py --library assets/library/creature
python3 tools/repair_meshy_rig.py  --library assets/library/creature
python3 tools/rig_meshy_tail.py    --library assets/library/creature
python3 tools/ground_meshy_clips.py --library assets/library/creature
python3 tools/bake_meshy_tail.py   --library assets/library/creature
```

| Step | Output | Fixes |
|---|---|---|
| `author_water_clips.py` | `authored/` | Meshy has no swim: surface swim and tread-water for every creature, the otters' dive (0203) |
| `repair_meshy_rig.py` | `repaired/` | Glossy self-lit material (0190); rigs 17–19% short (0190); the 0.01 Armature scale (0194); **bone scale keys away from rest (0197)** |
| `rig_meshy_tail.py` | `tailed/` | No tail chain, tails bound to a thigh (0191) |
| `ground_meshy_clips.py` | `grounded/` | Feet through the ground (0193); travelling carry walks (0195); standing clips floating (0197); idles spinning on the spot (0201); **planted feet sliding (0202)** |
| `bake_meshy_tail.py` | `baked/` | The crowd tier's tail motion (0192) |

Play `grounded/` clips on the skeletal pool and `baked/` (else `grounded/`) on
the crowd. Never `repaired/` or `tailed/` clips: their feet go through the
ground.

**Creatures that grow and shrink.** Meshy's idle clip keys the Hips at a
constant **scale 1.1765** on every creature (10 of 10). The creature then idles
17.65% larger, and swells or shrinks each time it blends between idle and
walk. The repair resets any bone scale key more than 1% from that bone's rest.
The grounding step **refuses** any clip that still has one. So if grounding
fails with "scaled away from its rest", the clip skipped the repair, or Meshy
has found a new way to do this: fix the repair, never the clip by hand. With
the scale gone, the idle's hips stood where they held the larger body, and its
feet floated 3 mm to 20 cm. The grounding step therefore **seats** any standing
clip whose feet never touch the ground. Only clips listed in `OFF_THE_GROUND`
(the chair sit) may hover. **A new clip that sits, hangs, swims or flies must
be added to `OFF_THE_GROUND`**, or it will be pulled down to the ground.

**Creatures that spin when standing still.** Meshy's idle stands turned −43° from
the walk and swings the whole body through 72–92° of yaw and back (10 of 10). The
creature appears to turn in a half circle on the spot, and every blend between walk
and idle turns it about 50°. **An idle must hold the walk's heading.** The grounding step
therefore **untwists** any in-place clip whose Hips heading swings more than 45°
and returns within 10° of where it began (decision 0201):
- the Hips face +Z on every key;
- the feet are pinned where the first key has them;
- the legs are re-solved;
- the head is turned to face +Z at rest.

It leaves alone a clip that travels, or that ends turned: those turn on purpose. It
refuses a swinging clip it cannot solve: no Head, a missing leg, a foot out of
reach. Do not "fix" such a refusal by editing the clip by hand; fix the step. The
manifest's `heading_swing_deg` shows every clip's swing. Anything new near 45° deserves a look.

**Creatures whose planted feet slide.** Meshy lets a foot drift across the ground
while it is planted: up to 13 cm in its kneels, 3 cm on the moles' chair, 2–9 cm
in a gait's stance. **A planted foot must stay where it lands.** The grounding step
therefore **pins** any contact that strays more than 2 cm (decision 0202):
- A foot is planted when its lowest point is within 2 cm of the ground. In a clip
  named in `GAIT_CLIPS`, it is planted when it moves with the ground at under half
  the gait's speed.
- The pinned foot keeps its height and rotation. The legs are re-solved, with the
  hips lowered at most 3 cm where a leg cannot reach.
- A step lifts the foot and starts a new contact, so steps are never undone.

**A new walk, run or other locomotion clip must be added to `GAIT_CLIPS`.** Otherwise
its scraping swing foot is taken for a planted one. An in-place gait records
`gait.speed_m_s` on its Hips: move the creature at that speed, or play the clip at
`ground_speed / gait.speed_m_s`, or the pinned stance slides again.

**How to check it:**
- The manifest's `contact_slide_before_m` and `contact_slide_after_m` give each
  clip's worst planted slide. After should be under 2 cm.
- `unpinned` lists contacts the step left, each with a reason: `"reach"` or
  `"support"` (a kneeling knee).
- `ground_scrape_m` shows how far a gait drags its swinging foot. That is not fixed
  yet; see the asset library README.
- In Godot, `viewer/dump_bones.gd` measures the feet as played. `viewer/shots_feet.gd`
  renders them against a disc where each contact began.

As with the untwist, never fix a refusal by editing the clip by hand; fix the step.

**Creatures in water (decision 0203).** Meshy has no swim, so `author_water_clips.py` authors
`anim_swim`, `anim_tread_water` and, for otters, `anim_dive` into `<key>/authored/`, as keys on a copy of
the raw `rigged.glb`. The repair picks them up with Meshy's clips, and the chain treats them like any clip.
- **The waterline is y = 0**, not the ground. Place a swimmer's root at the water surface.
- Surface clips hold the Head above it and the Hips below it; a dive keeps the whole body under it.
- **A new clip that swims must be added to `WATER_CLIPS`** in `ground_meshy_clips.py`, with its medium.
  A water clip is never lifted, seated, pinned or untwisted. It is checked against the waterline instead.
- The bake gives a water clip no ground (the spring's floor is 100 m down) and pulls the tail back along the
  body, not down. A dive's tail must stay under the surface (`water_ok`); its `ground_ok` is `null`, which is
  not a pass. A live swimmer needs `TailRig.set_water(true, back)`.
- No swim speed is recorded; that is movement's to set.

**Adding a species.** The beaver is the worked example (decision 0203):
1. **Species table row.** Add it to `SPECIES_KEY`, `SPECIES_HEIGHT_U` and `SPECIES_HEIGHT_MM` in
   `godot/assets/lookdev/lookdev_dimensions.gd`, appended last, with its status. Add it to
   `docs/planning/asset_dimensions_and_budgets.{md,json}` too. The repair refuses a creature whose species
   has no row. Do not invent landmark ratios for `proportion_comparison.gd`: leave the species out of it.
2. **Tail decision, by measurement.** Measure how far the tail rides into the ground if left on the Hips,
   across every clip. A tail that sinks or flies is chained: author its centreline and spring in
   `tail_centrelines.json`. A tail that is not separable from the body goes in `no_chain`, with the reason.
   A flat tail lying on the ground takes `"section": "flat"`, or its clearance is its half-width.
3. **The water clips.** Give the species a row in `SPECIES_CLIPS` in `author_water_clips.py`.
4. **The chain**, then the manifest diff: no other creature's row may change.

**Before calling a creature done**, watch it in Godot blend idle → walk → idle,
and check that it stays the same size, **does not turn**, and its feet stay planted.
Watch a kneel and a walk too: a planted foot should not creep off its spot.
Every automated check can pass on a clip that reads wrong.

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
