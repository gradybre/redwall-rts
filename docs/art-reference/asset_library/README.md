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
| Every **authored** water clip (swim, tread-water, dive): style, parameters, period, anchor height, hashes | [`authored.json`](authored.json) | yes |
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

## Farm and tunnel pass — 2026-09-29

32 more assets for the demo's farming and tunnel features, **1,152 credits** (Brendan approved
exactly that: 3,575 before, 2,423 after). They follow the library's recipe:
- a **concept** from the style reference (`nano-banana-2`, 6 credits);
- a **textured high-poly** from that concept (`meshy-7`, PBR, 2K, triangles, no remesh, 30 credits).

The **L0 is not a Meshy remesh**. Game-budget versions are made free in Blender instead: plant
cards for the fields, decimated meshes for props. Every task, prompt and file hash is in
`meshy_tasks.jsonl`, `concept_prompts.json` and `files.json`.

| Family | Keys | What for |
|---|---|---|
| environment | `plant_radish`, `plant_turnip`, `plant_carrot`, `plant_beetroot`, `plant_onion`, `plant_leek`, `plant_lettuce`, `plant_celery`, `plant_strawberry`, `plant_peas`, `plant_barley`, `plant_oats` | **One plant each, not a bed.** A planned lot, dynamic planting, pots and wild patches are all arrangements of the same plant. Growth stages are derived from the mature plant by scale, leaf thinning and tint. |
| prop | `item_radish` … `item_oats` (the same 12 crops) | The harvested item: carried to the store, rendered as the pantry icon, shown on shelves and in jars, and later used as a cooking ingredient. |
| prop | `tunnel_brace`, `tunnel_rubble`, `find_flint`, `find_clay`, `relic_bell`, `relic_key`, `relic_banner`, `mole_pick` | Tunnel bracing, collapse rubble, digging finds and relics, and the mole's tool. |

Known from the concepts: the turnip and carrot plants show their roots below the soil clump, as
a cut-away. Staging sinks each plant to its soil line.

## Water, bridge, beaver and forestry pass — 2026-09-29

A second pass of 24 assets for the demo's water, bridge-building and forestry features. **901
credits**, against about 913 Brendan approved (2,423 before, 1,522 after). It uses the same recipe
as above: props are a concept plus a meshy-7 high-poly, 36 credits each.

| Family | Keys |
|---|---|
| prop: water | `boat_coracle`, `boat_rowboat`, `boat_raft`, `jetty`, `fishing_rod`, `fishing_net`, `eel_trap`, `smoking_rack` |
| prop: catches | `item_trout`, `item_perch`, `item_eel`, `item_shrimp`, `item_mussels`, `item_hotroot` |
| prop: bridges | `bridge_plank`, `bridge_log`, `bridge_pier`, `gnawed_log` |
| prop: forestry | `felled_trunk`, `plank_stack`, `sawhorse`, `chopping_block`, `sapling_basket` |
| creature | `beaver_bridgewright` (DEC-041) |

**The beaver follows the other creatures' recipe:**

| Step | Credits |
|---|---|
| Multi-view concept (nano-banana-pro) | 9 |
| T-pose multi-image high-poly (meshy-7) | 30 |
| L0 remesh at 10,000 triangles and 1.40 m | 5 |
| Rig at 1.40 m, walk and run included | 5 |
| 8 clips, with the same action IDs as the otters | 24 |

Its height, 1434 u, is DEC-041's proposed value. Decision 0203 (PR #196) added its species row
and put it through the repair → tail → ground → bake chain. See "The beaver and the water clips"
below.

**`fishing_net` failed once on meshy-7:** `OverDenseInputError`, 77,382 active voxels against a
limit of 65,536, charged 0. The retry on meshy-6 succeeded, for 30 credits. **Swim and dive clips
were not bought:** Meshy's action catalog cannot be listed without spending, so swim cycles will
be authored in Blender.

## Underground revamp pass — 2026-09-29

Seven props and 19 clips for the underground revamp (tunnels, burrow homes, root cellars). **309
credits**, exactly what Brendan approved (1,522 before, 1,213 after). Decision
[0204](../../decisions/0204-the-underground-pass-clips-and-props.md) records the choices below.

**Props.** Library recipe: a `nano-banana-2` concept from the style reference (6), then a `meshy-7`
high-poly (PBR, 2K, triangles, no remesh; 30). **36 each.**

| Key | Concept task | High-poly task | L0 family |
|---|---|---|---|
| `burrow_door` | `01a0f007-c204-74d7-9b67-d812630413d7` | `01a0f008-c332-74c4-b420-641363ea18c7` | furniture, 1,900 |
| `tunnel_arch` | `01a0f007-cc8f-74d4-a859-17b402b476b3` | `01a0f008-ccd1-72a7-bf7d-bc26d13554df` | furniture, 1,900 |
| `hand_lantern` | `01a0f007-d839-7334-9c92-418843db7751` | `01a0f008-d4fb-74e8-83b6-23f6186586f1` | small prop, 1,150 |
| `hanging_stores` | `01a0f007-e1b9-735e-956e-f75f649f9c6e` | `01a0f008-dc7f-7301-8461-8a3f5ab80b40` | small prop, 1,122 |
| `root_bin` | `01a0f007-ec7a-7232-b394-a82a6e1928df` | `01a0f008-e5ac-7536-9b0d-b2fe7538a4c5` | furniture, 1,883 |
| `chimney_pot` | `01a0f007-fadc-77a9-bab6-73a7a946ed5b` | `01a0f008-ee15-7049-aa2d-b73b73cc5e23` | small prop, 1,150 |
| `rag_rug` | `01a0f008-02ae-7271-876e-69e4612726bc` | `01a0f008-f5f9-7187-9ccd-d8b85e14b326` | small prop, 1,145 |

- Every high-poly is Y-up, faces +Z and is centred on the origin, with its longest side about 1.9 units.
- The L0s were made free, by `make_demo_props.py`'s own `stage()`, into the demo's gitignored
  `godot/demo/assets/props/`. Godot 4 imports each one upright, with its bottom at y = 0.
  - The underground revamp's P7 (decision 0371) added these keys to that tool's `PROPS` table
    (`UNDERGROUND_PROPS`) and so to the demo's `manifest.json`.
  - `root_bin` was tried first as a small prop. At 1,150 triangles its feet and slats collapsed, so it was
    made at the furniture budget instead.

**Clips.** `meshy_animate` on each creature's existing rig, 3 credits each. The eight cast creatures
(`stage_demo_assets.py` `CAST`) get sleep and crouch-walk. `mole_digger`, `mole_mason` and
`badger_quarryman` get the dig. Every task ID is in `meshy_tasks.jsonl`.

| Role | Meshy action | File | Substitute? |
|---|---|---|---|
| Sleep / lie | 267 `Sleep_Normally` | `anim_sleep_normally.glb` | no: a looping sleep, lying on the back |
| Pick-swing dig | 128 `Heavy_Hammer_Swing` | `anim_heavy_hammer_swing.glb` | **yes**: Meshy has no pickaxe, mining or digging action |
| Crouch-walk | 524 `Cautious_Crouch_Walk_Forward` | `anim_cautious_crouch_walk_forward.glb` | no |

All 19 went through repair → tail → ground → bake. No existing row of `repaired.json`,
`tailed.json`, `grounded.json` or `baked.json` changed; the new rows are added.

**Known problems in this pass:**

| Asset | Problem |
|---|---|
| `tunnel_arch` | The doorway is filled by a **solid dark slab**, from the front and from behind. The concept painted it black. Cut it out in Blender before the passage tube can pass through. |
| `burrow_door` | The door is modelled on both faces. It does not open. |
| `hanging_stores`, `hand_lantern` L0 | At 1,150 triangles, the onions, garlic and herbs become faceted lumps, and the lantern's candle is mangled. Their high-polys are good. Build them as cards, or at a larger budget. |
| `hanging_stores` | It hangs from wall brackets, but the L0's origin is its lowest point, like every prop. Hang it by its top. |
| Dig (all 3) | The swing turns the hips 98–114° and **ends turned 68–81°**. So a looped dig snaps back each cycle. Grounding leaves it, as an intended turn (0201). Play it once per strike, facing the work, or author a loop. |
| Sleep (all 8) | Meshy leaves it floating 0.16–1.23 m, so grounding seats it by its legs. The torso then sinks up to 19.5 cm into the ground (squirrel_forester; 4–7 cm on four others). Grounding reads only foot, toe and leg joints as support. |
| Sleep, `otter_boatwright` baked | The tail's clearance constraint falls **2.6 cm short**: the otter lies on its tail. The bake exits 1 on this row. The bake's other failing row (`otter_fisher` / `anim_collect_object`, a 124° flick) was already failing on master. |
| Crouch-walk, `mouse_keeper` | Two contacts are left unpinned (`"support"`), so 8.8 cm of slide remains. The other seven pin to 0–1.8 cm. |
| Crouch-walk (all 8) | It travels, 0.68–2.74 m per loop, and that is recorded as root motion (0195). The swing foot drags 0.06–0.81 m, the known gait scrape. |

**Derived for the demo (P7, decision [0371](../../decisions/0371-the-generated-underground-props-and-clips-swapped-in.md)).**
`tools/make_demo_derived_props.py` (Blender half `demo_derived_blender.py`) makes these from the high-polys, which it only
reads, into the demo's gitignored `godot/demo/assets/props/`, each with a `.made.json` (the job, stamped with both
Blender scripts' SHA-256, and the source's SHA-256) and a manifest row. Same decimate-and-bake as the plain L0s; every
key inside the furniture ceiling (2,000), its parts together.

| Key | Source (SHA-256) | Fix | Parts (triangles) |
|---|---|---|---|
| `burrow_door_open` | `prop/burrow_door/highpoly.glb` (`2de1ea40966d…`) | leaf (a disc round its measured middle) split from the frame, the leaf's back face brought up to a door's thickness and its edge closed by a rim | `burrow_door_open__leaf.glb` 559, `burrow_door_open__frame.glb` 1340 |
| `tunnel_arch_open` | `prop/tunnel_arch/highpoly.glb` (`f685f3e1b6ab…`) | the doorway's two dark sheets (4,571 faces) removed | `tunnel_arch_open__arch.glb` 1899 |
| `hanging_stores_strung` | `prop/hanging_stores/highpoly.glb` (`7940c13a0215…`) | at the furniture budget, split into its bar and five strings | `hanging_stores_strung__bar.glb` 520, `hanging_stores_strung__string0.glb` 272, `hanging_stores_strung__string1.glb` 232, `hanging_stores_strung__string2.glb` 259, `hanging_stores_strung__string3.glb` 264, `hanging_stores_strung__string4.glb` 271 |
| `hand_lantern_lit` | `prop/hand_lantern/highpoly.glb` (`26476ac1720c…`) | at the furniture budget; its pale horn panes and candle a second material, `glow` | `hand_lantern_lit__lantern.glb` 1900 |
| `large_bed` | `prop/bed/highpoly.glb` (`5c76233c032b…`) | lengthened by 1.31 units, the middle slab repeated (quilt not stretched) | `large_bed__bed.glb` 1899 |

The root bin was tried twice (its roots split from its bin; its roots cut out) and both shattered its slats at the
budget: the plain L0 is used, full. `tools/stage_demo_assets.py` also re-pins the mouse keeper's crouch walk as it stages
it (support tolerance 2 cm, `REPIN`): its two contacts left unpinned above pin, the library's grounded clip untouched.

## Art pass 3 — 2026-10-02

Preserving and brewing props, the digging revamp's timber kit and rock face, and nine icons. **228 credits** were spent
against the **270** Brendan approved for the itemised list:
- the balance was 410 before and 104 after;
- the style probe (decision 0981) spent from the same account at the same time, and its tasks are not this pass's.

A subagent made the calls under decision 0961's delegated cap. Decision
[0971](../../decisions/0971-art-pass-3-preserving-brewing-digging-and-free-effects.md) records the choices. The assets
and the code each one serves are in [`../art_pass3_mapping.md`](../art_pass3_mapping.md). The nine icons were made
after Brendan's ruling (item and dish icons stay in the 3D-render style), from one sheet:

| Sheet | Task | Model |
|---|---|---|
| `icon/sheet_preserves_finds/sheet.png` (jam, pickles, dried fruit, cheese, ale, cider, coins, old map, spring) | `01a0fc94-6141-7684-be9b-4193024f9aab` | nano-banana-2, 6, conditioned on `sheet_foods_a` |

Their briefs and prompts are in [`../art_pass3_icon_prompts.md`](../art_pass3_icon_prompts.md).

**3D models.** Each uses the library recipe: a concept from the style reference (nano-banana-2, 6), then a meshy-7
high-poly (PBR, 2K, triangles, no remesh; 30). That is 36 a model. All are in the `prop/` family.

| Key | Concept task | High-poly task |
|---|---|---|
| `crock_stoneware` | `01a0fc6e-cc02-75fa-bae0-5797434db889` | `01a0fc6f-cb6c-7140-b9cb-bd4cc5c335d2` |
| `jar_shelf` | `01a0fc6e-d7aa-74a2-a6b8-ea59e52ee929` | `01a0fc6f-d4b3-7212-90e8-57c4e3e4bbee` |
| `ale_cask` | `01a0fc6e-e1e1-74d5-b7cb-b4550f5747e0` | `01a0fc6f-df40-7274-bf9b-f5e0ea5af358` |
| `brew_vat` | `01a0fc6e-ed19-711c-ba27-7780da747614` | `01a0fc6f-e8cb-72f6-b31e-ceec177bfcdb` |
| `tunnel_timber_kit` (post and lintel, one model) | `01a0fc6e-f739-75ce-b3db-00a3eaf715b4` | `01a0fc6f-f3d9-70f3-8213-a48fb9b1869d` |
| `rock_face` | `01a0fc6f-b47b-77ae-b198-a2b02abace26` (redo; the first, `01a0fc6f-0100-71ca-841a-5add62707dfa`, drew a box round it: `concept_rejected_box.png`) | `01a0fc70-4b9f-7267-9823-f5e356159cd2` |

**No Meshy remesh, rig or animation was bought.** The following were made free by `tools/make_art_pass3.py` and
`tools/art_pass3_blender.py`:
- the L0s;
- the kit's `l0_post.glb` and `l0_lintel.glb`;
- the staged `tunnel_post`, `tunnel_lintel` and `tunnel_set`.

The bees, fire, lightning and ice are committed code in `godot/demo/fx/` and `godot/demo/water/`, not library files.

## What is in it

Measured from the files, not from Meshy's reports. No L0 exceeds its GAP-04 ceiling.

### Creatures (12)

| Key | High-poly | L0 tris | Rig | Clips |
|---|---|---:|---|---:|
| `badger_cellarer` | meshy-7 | 10,262 | yes | 10 |
| `badger_quarryman` | meshy-7 | 10,359 | yes | 10 |
| `badger_steward` | meshy-7 | 10,384 | **no — robe defeated the auto-rigger** | 0 |
| `beaver_bridgewright` | meshy-7 | 10,332 | yes (DEC-041; decision 0203) | 10 |
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
  y = 0. The beaver's L0 is 1.40 m, DEC-041's proposed 1434 u.
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
  tail, and no chain, by design. The **beaver** has a chain (decision 0203): its flat paddle is
  measured by thickness, not width, and kept level by `tail_flat_roll.gd`.
- **Rigged and animated files are NOT all at DEC-039 height.** Meshy's rig `height_meters`
  scales the model's **longest** rest-pose dimension, not its height. Three creatures are
  wider in T-pose than they are tall, and came out short. The rigged file and every
  animation file for them share the error; their L0 is correct.

  | Key | Rigged height | Rest width | Target | Fix |
  |---|---:|---:|---:|---|
  | mole_digger | 0.734 | 0.900 | 0.90 | scale ×1.226 |
  | mole_mason | 0.759 | 0.900 | 0.90 | scale ×1.185 |
  | badger_cellarer | 2.121 | 2.550 | 2.55 | scale ×1.202 |
  | beaver_bridgewright | 1.179 | 1.400 | 1.40 | scale ×1.1879 |

  The other seven rigged creatures match their target to the millimetre.
- **Triangle counts** land 0–4% over the remesh target; that is Meshy's tolerance.

## Known problems

| Asset | Problem | Fix |
|---|---|---|
| bramble, fern_clump, wildflower_patch, birch_mature, apple_mature, crop_beans_ripe, basket, crop_grain_ripe, crop_roots_ripe | Leaves, fronds, wheat stalks, carrot tops and the woven rim shatter under the automatic remesh at these budgets. **Every high-poly source is good** — see `contact_sheets/foliage_compare.png` | Build the L0 in Blender as leaf cards with alpha, or retopologise by hand. Not a Meshy remesh. For the live demo, `tools/make_demo_crop_cards.py` does this for grain and roots (a bare bed plus cards rendered from the high-poly) |
| badger_steward | The robe hides the legs, so Meshy's auto-rigger refused it (`422 Pose estimation failed`) | Rig in Blender; or use badger_quarryman |
| mole_digger, mole_mason, badger_cellarer rigs and clips | 17–19% short: the rig scaled their arm span, not their height (see above) | **Fixed** by `tools/repair_meshy_rig.py` (decision 0190): the single scene root is scaled ×1.2269, ×1.1860 and ×1.2020, measured from the files to within 1 mm of `SPECIES_HEIGHT_U`. Repaired copies are in `<key>/repaired/` |
| *(not a file defect)* | Importing a rigged GLB into **Blender** adds a 2 m `Icosphere`. It is **not in the file** (0 of 110 contain one): Blender's glTF importer creates it as the bones' display shape (`io_scene_gltf2/blender/imp/node.py`) | Import with `disable_bone_shape=True`, or ignore it; it never reaches Godot |
| **Every rigged and animated GLB (110 files)** | Reads glossy and self-lit. Meshy's rig step rewrote the material: no metallic or roughness value, so glTF's default **metallic 1.0** applies; the colour map is wired in **again as full emission** (`emissiveFactor [1,1,1]`); `KHR_materials_specular` is **2.0**; the L0's roughness and normal maps are **dropped**. Godot's imported material confirms it: metallic 1.00, roughness 1.00, emission on. The high-poly and L0 files (162) are correct: roughness median 0.93, metallic 0 | **Fixed** by `tools/repair_meshy_rig.py` (decision 0190) in all 110 files: metallic 0, roughness from the L0's own map, the L0's normal map, no emission, no specular or ior extension. Before attaching the L0's maps, it proves the atlas is shared: the colour map must be byte-identical to the L0's. Godot reads every repaired material as metallic 0 with a roughness texture and a normal map, and emission off. Output in `<key>/repaired/`; the originals are untouched |
| Every `anim_idle` clip (10 of 10) | The creature **grows and shrinks**: Meshy keys the Hips at a constant scale 1.1765, so each creature idles 17.65% larger and swells or shrinks as it blends to and from any other clip. No other channel in the 110 files strays from rest by more than 1%. With the scale removed, the idle's feet floated 3 mm - 20 cm | **Fixed** (decision 0197). `tools/repair_meshy_rig.py` resets every bone scale key more than 1% from rest. `tools/ground_meshy_clips.py` seats a standing clip whose feet never touch the ground, and refuses a clip that still scales a bone. Audited: 0 stray scale channels in all 160 `grounded/` and `baked/` clips |
| Every `anim_idle` clip (10 of 10) | The creature **spins on the spot**. Meshy's idle stands turned −43° from the walk, then swings the whole body through 72–92° of yaw and back: the hips go to about +8°, then −79°, then −43° again. The feet shuffle 1–28 cm with it (the squirrels most). Every walk → idle blend turns the body about 50°. The head faces the viewer while the body is turned. No other clip swings more than 31.9° | **Fixed** (decision 0201). `tools/ground_meshy_clips.py` **untwists** an in-place clip whose Hips heading swings more than 45° and returns within 10°. The Hips face +Z on every key, and the upper body keeps its own motion. The feet are pinned where the first key has them, with the legs re-solved by two-bone IK. The hips stand over the rest hips, lowered at most 4.3 cm where a leg could not reach. The head gets one twist so it faces +Z at rest. Godot 4.7.2: heading range 0.00° on all ten, feet within 2 mm, walk → idle blend turns 2–8° (the walk's own stride). Sheets: `contact_sheets/idle_untwist_*.png` |
| Every clip with a planted foot (46 of 100 over 2 cm) | **Planted feet slide.** A foot on the ground drifts within one contact: up to 12.7 cm in pull_radish, 9.0 cm in collect_object, 3.2 cm on the moles' chair. The stance drifts 1.3–8.6 cm against the ground in the walk, run and carry walks | **Fixed** (decision 0202). `tools/ground_meshy_clips.py` finds each foot's contacts (within 2 cm of the ground standing; moving with the ground at under half the gait's speed in a gait). It holds any contact straying more than 2 cm where it landed, re-solving the legs with 0201's IK and lowering the hips at most 3 cm where a leg cannot reach. Steps are kept. 46 clips are pinned. Every pinned contact reads back at 0.0 mm from the file. In Godot 4.7.2 playback the worst clip goes from 12.6 to 0.2 cm; a few read up to 3.2 cm where Godot's import drops a key (see the next row). An in-place gait records `gait.speed_m_s` on its Hips; **move the creature at that speed**, or the stance slides again. Two kneeling contacts are left, reported `"support"`. Sheets: `contact_sheets/foot_pin_*.png` |
| Walk, run and both carry walks (all 10 creatures) | **The swinging foot scrapes along the ground** (0.1–1.2 m per clip, `ground_scrape_m`) while the planted foot hovers 2–22 cm. Meshy's retarget puts the swing foot below the planted one, and grounding (0193) stands the clip on the lowest point | **Open.** A pin cannot fix this; it needs a retargeted or authored gait cycle. Godot 4.7.2's import also drops an occasional key (up to 3 cm at the feet, original clips too) |
| `chair_sit_idle` clips | Sits on nothing | Pair it with a seat at play time |
| beaver_bridgewright tail | A broad, flat paddle. Meshy bound it to the Hips. Left there, it sank up to 43 cm into the ground (collect_object) and flew 61 cm up (bucket walk). Measured round, a chain's clearance would be its half-width, holding it off the ground it lies on. The first chain's spring rolled it 32–56°, and its edge dug up to 5.5 cm in | **Fixed** (decision 0203). Chained with `"section": "flat"`: clearance by thickness, in drawn metres. `tail_flat_roll.gd` keeps the paddle level after the spring. All 10 land clips pass the bake's ground and constraint checks |
| Water clips (tailed creatures) | With the land gravity, the spring hung the otters' tails straight down under them in every swim and dive | **Fixed** (decision 0203). In a water clip the spring pulls the tail back along the body, not down. With no pull at all it stood out of the water. The live tail must be told too: `TailRig.set_water(true, back)` |
| crop_cabbage_ripe | *(not a defect)* The concept is deliberately a blue-green savoy and the texture matches it, running slightly bluer (median leaf RGB 62,109,110 against the concept's 81,123,118) | Keep the authored colour. The live demo multiplies the albedo by the measured ratio, normalised on green: (1.16, 1.0, 0.95) |
| stone_wall | Generated as an L-shaped corner, not a straight modular section | Cut it in Blender |
| boathouse, weir, fisher_shelter | Water surfaces are baked into the mesh | Strip them; water is the engine's |
| Most buildings | They sit on a sculpted dirt or grass base | Trim to the footprint, or keep as a decal |
| mill | The waterwheel the prompt asked for isn't visible from the default view | Inspect it; may need adding |
| squirrel_gatherer | A basket is attached to the hand, although the prompt said nothing held | Separate it in Blender |
| crop_grain_ripe | The concept put a small well in the middle of the grain bed, and Meshy modelled it | Leave it out; the demo's cards never include it |
| Crops | Only RIPE was generated, and the runtime module ceiling is **256** triangles | Author EMPTY, SOWN, GROWING and WITHERED, and a 256-triangle module, in Blender from these sources |

## The beaver and the water clips — 2026-09-29

Decision [0203](../../decisions/0203-the-beaver-joins-the-pipeline-and-every-creature-can-swim.md).

- **The beaver bridgewright went through the whole chain.**
  - Repaired ×1.1879 to 1.4004 m (1434 u).
  - Its paddle tail is chained, with `"section": "flat"`. Left on the Hips, it sank up to 43 cm into the
    ground and flew 61 cm up.
  - The idle is untwisted from an 81° swing.
  - Its gaits record `gait.speed_m_s`: walk 0.992, run 3.140.
- **Every rigged creature can swim.** `tools/author_water_clips.py` writes `anim_swim` and
  `anim_tread_water`, and for the otters `anim_dive`, into `<key>/authored/`. The repair takes them from
  there with Meshy's clips.
  - **The waterline is y = 0.** Place a swimmer's root at the water surface.
  - `grounded.json` rows for them carry `water`, `head_min_y_m` and `hips_max_y_m`, and for the dive
    `body_max_y_m`.
  - `baked.json` gives them `ground_ok: null` (no ground) and `water_ok`. Their tails were baked pulled
    back along the body, not down; call `TailRig.set_water(true, back)` on a live swimmer.
- Sheets: `contact_sheets/beaver_lineup.png` (beside an otter and a badger), and
  `contact_sheets/water_<key>.png` for the otter, mouse, badger and beaver, side views with the waterline.

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
- `verify_water.gd` and `shots_water.gd` check decision 0203's beaver and water clips. Put the files in a
  throwaway project's `res://glb/` as `<key>__rigged.glb`, `<key>__idle.glb`, `<key>__walk.glb` and
  `<key>__anim_swim.glb` (and so on).
  - `verify_water.gd` (headless) measures each rig's rest height and blends idle → walk → idle. For every
    water clip it reports the neck's and hips' heights against the waterline, the skinned top and extent,
    and the bone-length drift. The headless renderer registers no skin, so it skins the vertices itself.
  - `shots_water.gd` (windowed) renders each shot of a plan: side or front, with the waterline and tinted
    water, or with height rules on the ground. Arguments after `--`: `<out_dir> <plan.json>`.

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
