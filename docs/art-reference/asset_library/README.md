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
| The prompt and reference image behind every concept | [`concept_prompts.json`](concept_prompts.json) | yes |
| Rendered contact sheets of every L0 | [`contact_sheets/`](contact_sheets/) | yes (LFS) |

Per asset directory: `concept_*.png`, `highpoly.glb` (+ `highpoly_textures/`), `l0.glb`
(+ `l0_textures/`), and for creatures `rigged.glb`, `anim_walk.glb`, `anim_run.glb` and
`anim_<action>.glb`.

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
| mole_digger, mole_mason, badger_cellarer rigs and clips | 17–19% short: the rig scaled their arm span, not their height (see above) | Rescale the rig by the factor above. It is a uniform scale; nothing needs regenerating |
| Every animated GLB | Carries a stray 2 m **Icosphere** mesh. Blender's importer brings it in; Godot's does not | Delete it when a clip is prepared in Blender |
| **Every rigged and animated GLB (110 files)** | Reads glossy and self-lit. Meshy's rig step rewrote the material: no metallic or roughness value, so glTF's default **metallic 1.0** applies; the colour map is wired in **again as full emission** (`emissiveFactor [1,1,1]`); `KHR_materials_specular` is **2.0**; the L0's roughness and normal maps are **dropped**. Godot's imported material confirms it: metallic 1.00, roughness 1.00, emission on. The high-poly and L0 files (162) are correct: roughness median 0.93, metallic 0 | A free, local material repair, with no regeneration: metallic 0, emission off, specular 1.0, and the **L0's own roughness and normal maps**. The rigged mesh is the L0 mesh (identical triangle counts; the extra vertices are skinning-seam splits). Proven in Godot with a constant roughness of 0.93: `contact_sheets/gloss_before_after.png` |
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
  Arguments after `--`: `<out_dir> <walk|clips> <frames> [fixmat]`. `fixmat` applies the
  material repair described under *Known problems*. `walk` rescales the three short rigs to
  their DEC-039 height, in the viewer only.

## What still has to happen before anything is in the game

1. `prep_unit.py --no-rotate` normalisation, then a **human facing check** against the
   "face north" fixture.
2. L1–L3 in Blender from the L0 (`FAMILY_TRIANGLE_CEILING` has every tier).
3. Repack textures into the shared 2048² albedo/normal/ORM contract per family.
4. The production rig per species, with a tail, the three sockets and the 64-bone budget.
   Retarget the Meshy clips onto it, or treat them as references.
5. Door openings at 1536 × 3072 u, and the residence cutaway (GAP-06). Meshy honoured
   neither.
6. `asset_import_validator.gd` against the GAP-03 envelopes and GAP-04 budgets.
7. **Brendan's visual acceptance** through `tools/art_gate.py`.
