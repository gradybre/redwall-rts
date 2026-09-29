# Provisional asset library — Meshy, 2026-09-24

81 assets generated from expiring Meshy credits, each kept as an untouched **high-poly
source** and a **game-budget L0 remesh**, plus 10 rigs and 80 animation clips. Why it
exists, what Brendan authorised and what it overrides:
[decision 0188](../../decisions/0188-the-meshy-asset-library-is-provisional-and-lives-outside-git.md).

**Nothing here is an accepted asset.** It is raw material. See *What still has to happen*.

## Where things are

| What | Where | In git? |
|---|---|---|
| The binaries — 1,105 files, 13.7 GB | `assets/library/<family>/<key>/` | **No** — gitignored |
| Every Meshy task: ID, model, parameters, outcome, credits | [`meshy_tasks.jsonl`](meshy_tasks.jsonl) | yes |
| Every file: path, bytes, SHA-256, source task | [`files.json`](files.json) | yes |
| Every **repaired** rigged/animated file: source and output SHA-256, height before and after, scale factor | [`repaired.json`](repaired.json) | yes |
| The authored tail centrelines, and the spring settings to drive each chain | [`tail_centrelines.json`](tail_centrelines.json) | yes |
| Every **tail-chained** file: tail vertices, tail length, joints, bind check, hashes | [`tailed.json`](tailed.json) | yes |
| Every **grounded** clip: keys lifted, largest lift, lowest support before and after, root travel extracted, loop gap, hash | [`grounded.json`](grounded.json) | yes |
| Every **tail-baked** clip: frames, loop seam, largest one-frame step, tail/feet/base lowest points, ground and motion verdicts, hash | [`baked.json`](baked.json) | yes |
| The prompt and reference image behind every concept | [`concept_prompts.json`](concept_prompts.json) | yes |
| Rendered contact sheets of every L0 | [`contact_sheets/`](contact_sheets/) | yes (LFS) |

Per asset directory: `concept_*.png`, `highpoly.glb` (+ `highpoly_textures/`), `l0.glb`
(+ `l0_textures/`), and for creatures `rigged.glb`, `anim_walk.glb`, `anim_run.glb` and
`anim_<action>.glb`.
Rigged creatures also have `repaired/`: the same rigged and animated files with the material
and height repaired (decision 0190), and Meshy's 0.01 Armature scale folded into the joints so every
skeleton is at unit scale (decision 0194). The six tailed creatures also have `tailed/`: the repaired
files plus the tail chain (decision 0191). Every rigged creature then has `grounded/`: its
`tailed/` (or `repaired/`) clips with the hips lifted so the feet, or the knees in a kneel,
never go below the ground (decision 0193), and playing in place: the two carry walks' travel is
recorded as `root_motion` on the Hips bone instead (decision 0195;
`godot/scripts/presentation/clip_root_motion.gd` reads it). The ten idles are also held at the walk's
heading, with their feet pinned, instead of swinging round (decision 0201). The six tailed creatures also have `baked/`: every
`grounded/` clip with the tail's spring motion written in as keys, for the crowd tier (decision
0192). **For crowd clips use `baked/` where it exists, otherwise `grounded/`; for the skeletal
pool, which runs the spring live, `grounded/`, with `godot/scripts/presentation/tail_rig.gd`
attaching the spring and the exact ground constraint from the tail bones' own metadata (decision
0194). Never the raw rig files, and no longer `repaired/` or `tailed/` clips: their feet go
through the ground.**

**Lost the files?** Every task ID in `meshy_tasks.jsonl` can be downloaded again with
`meshy_download_model` — no credits. Verify against `files.json`. Rig and animation
outputs come back as signed URLs, not files, and those URLs expire after about 28 hours.

## Spend

3,763 credits at the start; **3,728 spent**, 35 left to expire. The ledger's
`credits_charged` column sums to exactly 3,728. Five tasks failed on Meshy's side and were
charged nothing; one rig was refused.

## What is in it

Measured from the files, not from Meshy's reports. No L0 exceeds its GAP-04 ceiling.

### Creatures (11)

| Key | High-poly | L0 tris | Rig | Clips |
|---|---|---:|---|---:|
| `badger_cellarer` | meshy-7 | 10,262 | yes | 10 |
| `badger_quarryman` | meshy-7 | 10,359 | yes | 10 |
| `badger_steward` | meshy-7 | 10,384 | **no — robe defeated the auto-rigger** | 0 |
| `mole_digger` | meshy-7 | 10,209 | yes | 10 |
| `mole_mason` | meshy-7 | 10,313 | yes | 10 |
| `mouse_fieldworker` | meshy-7 | 10,375 | yes | 10 |
| `mouse_keeper` | meshy-7 | 10,245 | yes | 10 |
| `otter_boatwright` | meshy-7 | 10,281 | yes | 10 |
| `otter_fisher` | meshy-7 | 10,398 | yes | 10 |
| `squirrel_forester` | meshy-7 | 10,357 | yes | 10 |
| `squirrel_gatherer` | meshy-7 | 9,903 | yes | 10 |

### Buildings (28)

| Key | High-poly | L0 tris (target) |
|---|---|---:|
| `apiary` | meshy-7 | 5,070 (6,000) |
| `boathouse` | meshy-7 | 28,977 (30,000) |
| `brewery` | meshy-7 | 29,754 (30,000) |
| `cellar` | meshy-7 | 16,276 (16,000) |
| `composter` | meshy-7 | 5,829 (6,000) |
| `covered_store` | meshy-7 | 29,804 (30,000) |
| `dryer` | meshy-7 | 15,044 (16,000) |
| `fence` | meshy-7 | 5,682 (6,000) |
| `fisher_shelter` | meshy-6 | 15,358 (16,000) |
| `forester_lodge` | meshy-7 | 29,682 (30,000) |
| `gate` | meshy-7 | 16,059 (16,000) |
| `hall` | meshy-7 | 29,482 (30,000) |
| `infirmary` | meshy-7 | 29,497 (30,000) |
| `kitchen` | meshy-7 | 29,963 (30,000) |
| `lookout` | meshy-7 | 29,616 (30,000) |
| `memorial_garden` | meshy-7 | 12,855 (16,000) |
| `mill` | meshy-7 | 30,408 (30,000) |
| `nursery` | meshy-7 | 15,961 (16,000) |
| `open_stockpile` | meshy-7 | 15,757 (16,000) |
| `preserver` | meshy-7 | 29,994 (30,000) |
| `quarry_shed` | meshy-7 | 16,062 (16,000) |
| `residence` | meshy-7 | 29,665 (30,000) |
| `saltpan` | meshy-7 | 5,984 (6,000) |
| `stone_wall` | meshy-7 | 6,244 (6,000) |
| `weir` | meshy-7 | 6,012 (6,000) |
| `well` | meshy-7 | 16,178 (16,000) |
| `workbench` | meshy-7 | 15,399 (16,000) |
| `workshop` | meshy-7 | 28,890 (30,000) |

### Props (20)

| Key | High-poly | L0 tris (target) |
|---|---|---:|
| `axe` | meshy-7 | 1,187 (1,150) |
| `barrel` | meshy-7 | 1,131 (1,150) |
| `basket` | meshy-7 | 459 (1,150) |
| `bed` | meshy-7 | 1,879 (1,900) |
| `cauldron_tripod` | meshy-7 | 1,863 (1,900) |
| `clay_jars` | meshy-7 | 1,108 (1,150) |
| `crate` | meshy-7 | 964 (1,150) |
| `fish_creel` | meshy-7 | 792 (1,150) |
| `handcart` | meshy-7 | 1,828 (1,900) |
| `hearth` | meshy-7 | 1,922 (1,900) |
| `hoe` | meshy-7 | 1,129 (1,150) |
| `log_stack` | meshy-7 | 1,137 (1,150) |
| `pantry_shelf` | meshy-7 | 1,456 (1,900) |
| `sack_pile` | meshy-7 | 1,146 (1,150) |
| `sickle` | meshy-7 | 1,192 (1,150) |
| `spade` | meshy-7 | 1,155 (1,150) |
| `table_stools` | meshy-7 | 1,859 (1,900) |
| `wall_lantern` | meshy-7 | 1,103 (1,150) |
| `water_bucket` | meshy-7 | 1,115 (1,150) |
| `wheelbarrow` | meshy-7 | 1,775 (1,900) |

### Environment (22)

| Key | High-poly | L0 tris (target) |
|---|---|---:|
| `apple_mature` | meshy-7 | 3,338 (5,800) |
| `beech_mature` | meshy-7 | 5,801 (5,800) |
| `birch_mature` | meshy-7 | 2,698 (5,800) |
| `birch_sapling` | meshy-7 | 1,453 (3,000) |
| `bramble` | meshy-7 | 303 (580) |
| `crop_beans_ripe` | meshy-7 | 682 (1,200) |
| `crop_cabbage_ripe` | meshy-7 | 1,128 (1,200) |
| `crop_flax_ripe` | meshy-7 | 877 (1,200) |
| `crop_grain_ripe` | meshy-7 | 655 (1,200) |
| `crop_roots_ripe` | meshy-7 | 898 (1,200) |
| `fallen_log` | meshy-7 | 973 (1,150) |
| `fern_clump` | meshy-7 | 378 (580) |
| `grass_tuft` | meshy-7 | 499 (580) |
| `mossy_boulder` | meshy-7 | 779 (1,150) |
| `mushroom_cluster` | meshy-7 | 413 (580) |
| `oak_mature` | meshy-7 | 5,829 (5,800) |
| `oak_sapling` | meshy-7 | 3,099 (3,000) |
| `oak_stump_fresh` | meshy-7 | 3,103 (3,000) |
| `reeds` | meshy-7 | 493 (580) |
| `rock_cluster` | meshy-7 | 927 (1,150) |
| `stump_mossy` | meshy-7 | 2,960 (3,000) |
| `wildflower_patch` | meshy-7 | 438 (580) |
## Verified properties

- **Height and pivot.** Creature L0s are exactly their DEC-039 height along **+Y** —
  mouse 1.00 m, mole 0.90, squirrel 1.15, otter 1.49, badger 2.55 — with the feet at
  y = 0.
- **Axes.** These GLBs are ordinary glTF **Y-up**, and the high-poly sources are Y-up
  and centred on the origin. The asset-pipeline skill's claim that Meshy GLBs are Z-up
  does not hold for this output. **Run `prep_unit.py` with `--no-rotate`**, or it will
  tip every one of them onto its back.
- **Facing: +Z**, glTF's front. Checked 2026-09-26 by running the animated files in
  Godot 4.7.2: a camera on +Z sees every creature's face. The project's convention is −Z
  forward, so each one needs a **180° turn** on import. Godot imports them upright with no
  rotation, which confirms the Y-up finding above.
- **Rigs** are Meshy's generic humanoid: 24 joints, **no tail, no fingers, no sockets**.
  In motion the missing tail chain shows: bending clips (gather, pull radish, bucket) leave
  the tail rigid, riding on the hips and sticking out behind.
  **Fixed for six creatures** by `tools/rig_meshy_tail.py` (decision 0191): an 8-bone chain
  `tail_00`–`tail_07` under `Hips`, in `<key>/tailed/`. Meshy had bound three of those tails to a
  **thigh**, so they swung with one leg; that binding is gone. Moles and badgers have no separable
  tail, and no chain, by design.
- **Rigged and animated files are NOT all at DEC-039 height.** Meshy's rig `height_meters`
  scales the model's **longest** rest-pose dimension, not its height. Three creatures are
  wider in T-pose than they are tall, and came out short. The rigged file and every
  animation file for them share the error; their L0 is correct.

  | Key | Rigged height | Rest width | Target | Fix |
  |---|---:|---:|---:|---|
  | mole_digger | 0.734 | 0.900 | 0.90 | scale ×1.226 |
  | mole_mason | 0.759 | 0.900 | 0.90 | scale ×1.185 |
  | badger_cellarer | 2.121 | 2.550 | 2.55 | scale ×1.202 |

  The other seven rigged creatures match their target to the millimetre.
- **Triangle counts** land 0–4% over the remesh target; that is Meshy's tolerance.

## Known problems

| Asset | Problem | Fix |
|---|---|---|
| bramble, fern_clump, wildflower_patch, birch_mature, apple_mature, crop_beans_ripe, basket | Leaves, fronds and the woven rim shatter under the automatic remesh at these budgets. **Every high-poly source is good** — see `contact_sheets/foliage_compare.png` | Build the L0 in Blender as leaf cards with alpha, or retopologise by hand. Not a Meshy remesh |
| badger_steward | The robe hides the legs, so Meshy's auto-rigger refused it (`422 Pose estimation failed`) | Rig in Blender; or use badger_quarryman |
| mole_digger, mole_mason, badger_cellarer rigs and clips | 17–19% short: the rig scaled their arm span, not their height (see above) | **Fixed** by `tools/repair_meshy_rig.py` (decision 0190): the single scene root is scaled ×1.2269, ×1.1860 and ×1.2020, measured from the files to within 1 mm of `SPECIES_HEIGHT_U`. Repaired copies are in `<key>/repaired/` |
| *(not a file defect)* | Importing a rigged GLB into **Blender** adds a 2 m `Icosphere`. It is **not in the file** (0 of 110 contain one): Blender's glTF importer creates it as the bones' display shape (`io_scene_gltf2/blender/imp/node.py`) | Import with `disable_bone_shape=True`, or ignore it; it never reaches Godot |
| **Every rigged and animated GLB (110 files)** | Reads glossy and self-lit. Meshy's rig step rewrote the material: no metallic or roughness value, so glTF's default **metallic 1.0** applies; the colour map is wired in **again as full emission** (`emissiveFactor [1,1,1]`); `KHR_materials_specular` is **2.0**; the L0's roughness and normal maps are **dropped**. Godot's imported material confirms it: metallic 1.00, roughness 1.00, emission on. The high-poly and L0 files (162) are correct: roughness median 0.93, metallic 0 | **Fixed** by `tools/repair_meshy_rig.py` (decision 0190) in all 110 files: metallic 0, roughness from the L0's own map, the L0's normal map, no emission, no specular or ior extension. Before attaching the L0's maps, it proves the atlas is shared: the colour map must be byte-identical to the L0's. Godot reads every repaired material as metallic 0 with a roughness texture and a normal map, and emission off. Output in `<key>/repaired/`; the originals are untouched |
| Every `anim_idle` clip (10 of 10) | The creature **grows and shrinks**: Meshy keys the Hips at a constant scale 1.1765, so each creature idles 17.65% larger and swells or shrinks as it blends to and from any other clip. No other channel in the 110 files strays from rest by more than 1%. With the scale removed, the idle's feet floated 3 mm - 20 cm | **Fixed** (decision 0197). `tools/repair_meshy_rig.py` resets every bone scale key more than 1% from rest. `tools/ground_meshy_clips.py` seats a standing clip whose feet never touch the ground, and refuses a clip that still scales a bone. Audited: 0 stray scale channels in all 160 `grounded/` and `baked/` clips |
| Every `anim_idle` clip (10 of 10) | The creature **spins on the spot**. Meshy's idle stands turned −43° from the walk, then swings the whole body through 72–92° of yaw and back: the hips go to about +8°, then −79°, then −43° again. The feet shuffle 1–28 cm with it (the squirrels most). Every walk → idle blend turns the body about 50°. The head faces the viewer while the body is turned. No other clip swings more than 31.9° | **Fixed** (decision 0201). `tools/ground_meshy_clips.py` **untwists** an in-place clip whose Hips heading swings more than 45° and returns within 10°. The Hips face +Z on every key, and the upper body keeps its own motion. The feet are pinned where the first key has them, with the legs re-solved by two-bone IK. The hips stand over the rest hips, lowered at most 4.3 cm where a leg could not reach. The head gets one twist so it faces +Z at rest. Godot 4.7.2: heading range 0.00° on all ten, feet within 2 mm, walk → idle blend turns 2–8° (the walk's own stride). Sheets: `contact_sheets/idle_untwist_*.png` |
| Every clip with a planted foot (46 of 100 over 2 cm) | **Planted feet slide.** A foot on the ground drifts within one contact: up to 12.7 cm in pull_radish, 9.0 cm in collect_object, 3.2 cm on the moles' chair. The stance drifts 1.3–8.6 cm against the ground in the walk, run and carry walks | **Fixed** (decision 0202). `tools/ground_meshy_clips.py` finds each foot's contacts (within 2 cm of the ground standing; moving with the ground at under half the gait's speed in a gait). It holds any contact straying more than 2 cm where it landed, re-solving the legs with 0201's IK and lowering the hips at most 3 cm where a leg cannot reach. Steps are kept. 46 clips are pinned. Every pinned contact reads back at 0.0 mm from the file. In Godot 4.7.2 playback the worst clip goes from 12.6 to 0.2 cm; a few read up to 3.2 cm where Godot's import drops a key (see the next row). An in-place gait records `gait.speed_m_s` on its Hips; **move the creature at that speed**, or the stance slides again. Two kneeling contacts are left, reported `"support"`. Sheets: `contact_sheets/foot_pin_*.png` |
| Walk, run and both carry walks (all 10 creatures) | **The swinging foot scrapes along the ground** (0.1–1.2 m per clip, `ground_scrape_m`) while the planted foot hovers 2–22 cm. Meshy's retarget puts the swing foot below the planted one, and grounding (0193) stands the clip on the lowest point | **Open.** A pin cannot fix this; it needs a retargeted or authored gait cycle. Godot 4.7.2's import also drops an occasional key (up to 3 cm at the feet, original clips too) |
| `chair_sit_idle` clips | Sits on nothing | Pair it with a seat at play time |
| crop_cabbage_ripe | Cabbages read cyan-blue | Recolour the texture |
| stone_wall | Generated as an L-shaped corner, not a straight modular section | Cut it in Blender |
| boathouse, weir, fisher_shelter | Water surfaces are baked into the mesh | Strip them; water is the engine's |
| Most buildings | They sit on a sculpted dirt or grass base | Trim to the footprint, or keep as a decal |
| mill | The waterwheel the prompt asked for isn't visible from the default view | Inspect it; may need adding |
| squirrel_gatherer | A basket is attached to the hand, although the prompt said nothing held | Separate it in Blender |
| Crops | Only RIPE was generated, and the runtime module ceiling is **256** triangles | Author EMPTY, SOWN, GROWING and WITHERED, and a 256-triangle module, in Blender from these sources |

## Seeing them move

[`viewer/`](viewer/) holds the two scripts used on 2026-09-26 to check the rigs in motion.
Both are scratch tools, not part of the game:
- `render_lineup.py` renders ten creatures walking in Blender, headless.
- `capture.gd` runs in a throwaway Godot project, imports the animated GLBs exactly as the
  game would, advances every clip by exactly 1/24 s per captured frame, and saves each frame.
  It must run **windowed**: headless Godot has no renderer to capture from.
- `capture_tail.gd` records the tail chains before and after, driving each chain with
  `SpringBoneSimulator3D` and a ground `SpringBoneCollisionPlane3D`. It predates decisions 0192 and
  0194: it drove the spring under Meshy's 0.01-scaled skeleton, where Godot's plane collider is
  wrong, so its before/after sheet shows that bug too. The live tail is now `tail_rig.gd`.
  Arguments after `--`: `<out_dir> <walk|clips> <frames> [fixmat]`. `fixmat` applies the
  material repair described under *Known problems*. `walk` rescales the three short rigs to
  their DEC-039 height, in the viewer only.
- `capture_baked.gd` plays one `baked/` clip beside its `grounded/` twin with **no spring
  running**, as the crowd tier plays it: whatever the baked tail does is in the clip.
  Arguments after `--`: `<out_dir> <frames>`.
- `measure_idle.gd`, `blend_idle.gd` and `shots_idle.gd` check decision 0201's untwisted idles. Put
  `<key>__before.glb` (Meshy's idle, grounded), `<key>__after.glb` (the untwisted idle) and
  `<key>__walk.glb` in a throwaway project's `res://glb/`.
  - `measure_idle.gd` (headless) samples the Hips heading and the feet across each loop.
  - `blend_idle.gd` (headless) plays idle → walk → idle with 0.3 s crossfades, and reports how far each
    blend turns the body.
  - `shots_idle.gd` (windowed) renders before and after side by side, from above and from the front,
    with an arrow along the walk. Arguments after `--`: `<out_dir> <key> <height_m> <times>`.
- `dump_bones.gd` and `shots_feet.gd` check decision 0202's pinned feet.
  - `dump_bones.gd` (headless) plays each GLB in a job file through Godot's import and `AnimationPlayer`, and
    writes every bone's global transform at the clip's own key times. Arguments after `--`:
    `<job.json> <out.json>`. The foot vertices are then skinned with those transforms, and measured with
    `ground_meshy_clips.foot_slips` and `contact_slide`.
  - `shots_feet.gd` (windowed) renders the before and pinned clip side by side, carried along the ground as
    the game would move them. It draws each foot's contact trail, and a red disc where each planted contact
    began. Arguments after `--`: `<out_dir> <plan.json>`; the header documents the plan's shape.

## What still has to happen before anything is in the game

1. `prep_unit.py --no-rotate` normalisation, then a **human facing check** against the
   "face north" fixture.
2. L1–L3 in Blender from the L0 (`FAMILY_TRIANGLE_CEILING` has every tier).
3. Repack textures into the shared 2048² albedo/normal/ORM contract per family.
4. The production rig per species: the three sockets and a fixed rig manifest within the 64-bone
   budget. Six tails have their chain (decision 0191) and their motion baked into every clip
   (decision 0192). Retarget the Meshy clips onto the production rig, or treat them as
   references. Meshy's clips sank the feet in 90 of 100 clips; `grounded/` lifts them
   (decision 0193). Planted feet are pinned (decisions 0201 and 0202). The gaits' swinging foot still scrapes the
   ground; see *Known problems*.
5. Door openings at 1536 × 3072 u, and the residence cutaway (GAP-06). Meshy honoured
   neither.
6. `asset_import_validator.gd` against the GAP-03 envelopes and GAP-04 budgets.
7. **Brendan's visual acceptance** through `tools/art_gate.py`.
