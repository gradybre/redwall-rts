# 0188 — The Meshy asset library is provisional, lives outside git, and is reproducible from task IDs
Date: 2026-09-24 · Status: Accepted

## Decision

On 2026-09-24 Brendan spent expiring Meshy credits on a **provisional asset library**:
81 generated assets (11 creatures, 28 buildings, 20 props, 22 environment pieces),
each kept as a high-poly source and a game-budget remesh, plus 10 rigs and 80
animation clips on the creatures.

1. **The binaries live in `assets/library/`, which is gitignored.** What is committed is
   the ledger in [`docs/art-reference/asset_library/`](../art-reference/asset_library/README.md):
   every Meshy task ID, its parameters and credits, the concept prompts, and a
   per-file size and SHA-256 list. Any file can be downloaded again from its task ID.
2. **Nothing in the library is an accepted asset.** It is not under `godot/`. Getting
   any piece into the game still means `prep_unit.py` normalisation, a human check of
   which way it faces, levels of detail L1–L3, texture repacking, the import validator
   and Brendan's visual acceptance through `tools/art_gate.py`.

## What Brendan authorised, and in what words

The request, verbatim: *"I have 3900 meshy credits that expire tonight - I'd like to use
them to begin building assets for this game so I can start building an asset library,
even if I don't need them yet."* The balance was actually **3,763**.

Asked whether a plan covered full production, he added: reference art built from
**the right-hand panel** of the DEC-038 approved image; characters **in T-pose**;
generation **at high quality first, then retopology down** to where the game needs it;
rigging, texturing and *"anything else that is worthwhile doing in meshy"*.

He then confirmed three spends, each presented with its cost first:

| Confirmation | Scope | Credits |
|---|---|---|
| "Go (Recommended)" | 80 assets: concept → meshy-7 high-poly → remesh; creatures also rigged plus 3 clips | 3,534 planned |
| "Animations + a rig-able badger" | 45 extra clips; a third badger outfit, because the robed steward could not be rigged | 135 + 58 |
| "Badger quarryman extras (Recommended)" | the same 5 extra clips for the new badger | 15 |

**This was authorised in the session, not through `docs/planning/art_approvals.json`.**
The ART-CREATURES entry there approves 120 credits for four species; tonight's spend is
far wider. The ledger is Brendan's to write, so it has not been touched — this record is
the audit trail.

## What it overrides, and why

[`creature_generation_batch.md`](../planning/creature_generation_batch.md) sequences a
30-credit mouse first, a review, then the rest, and excludes paid remesh, rigging and
animation. The pipeline skill says *"Do not batch."* Both exist to stop credits being
wasted on a pipeline nobody has checked. **Credits that expire at midnight are wasted by
not spending them**, so the argument ran the other way tonight. The quality gates those
rules protect are unchanged: nothing generated here is accepted until it passes them.

The batch plan's **A-pose** became **T-pose** on Brendan's instruction, which also fits
Meshy's auto-rigger.

## Choices made in execution

**Style anchor.** Every concept went through image-to-image with the right-hand panel of
[the DEC-038 image](../art-reference/visuals/grounded_expressive_rts_example_v1.png),
cropped to `assets/library/_reference/style_right_panel_rts.png`. Creature concepts
*also* took the left panel, because the right panel's mouse and mole are about 40 px
tall — too small to carry fur, face or cloth. Brendan asked for the right panel; the
left one was added for the creatures only, and that is a deviation.

**High-poly first.** meshy-7, textured, PBR, 2K, triangle topology, with Meshy's own
remesh **off** at generation, so the untouched source survives. Ultra mode was not used:
remeshing throws its extra geometry away.

**Remesh targets come from the contract, not taste.** GAP-04's
`FAMILY_TRIANGLE_CEILING` in `godot/assets/lookdev/lookdev_dimensions.gd`:

| Family | L0 ceiling | Target |
|---|---|---|
| Creature body | 12,000 incl. equipment | 10,000 |
| Building — hall, residence, kitchen, mill, … | 32,000 | 30,000 |
| Building — workbench, cellar, well, gate, … | 32,000 | 16,000 |
| Building — fence, wall, weir, saltpan, apiary, composter | 32,000 | 6,000 |
| Furniture | 2,000 | 1,900 |
| Small prop / pile | 1,200 | 1,150 |
| Tree | 6,000 | 5,800 (stumps, saplings 3,000) |
| Ground cover | 600 | 580 |
| Crop plot | **256** (`CROP_MODULE_TRIANGLE_CEILING`) | **1,200 — a bake source, not the runtime module** |

The crop ceiling is 256 triangles per 2 × 2 m module. A Meshy remesh of a planted
plot at 256 is not a usable asset, so the 1,200-triangle remesh is recorded as the
source the Blender-authored module is baked from. Only the RIPE state was generated;
EMPTY, SOWN, GROWING and WITHERED remain local work.

**Heights.** Creature remeshes were resized to the DEC-039 heights in metres (mouse 1.00,
mole 0.90, squirrel 1.15, otter 1.49, badger 2.55) with the origin at the bottom.
**Measured afterwards from the accessor bounds: every creature L0 is exactly its height
along +Y, feet at y = 0.** The buildings were **not** resized: GAP-03's figures are
maximum-Y envelopes, not targets.

**Rigs are prototypes.** Meshy's auto-rig is a generic humanoid — 24 joints, read from
the rigged GLB's skin. It has **no tail bones**, no fingers, and none of the crowd doc's sockets (`socket_main`, `socket_off`, `socket_head`), and it
is not bound to the 64-bone budget. It is a head start and an animation reference; the
production `rig_<species>_v1` is still to be built.

**Animation library IDs used** (Meshy's catalogue, 2026-09-24): 0 Idle, 551
Carry_Heavy_Object_Walk, 284 Collect_Object, 33 Chair_Sit_Idle_M, 342 Stand_and_Drink,
290 Wave_One_Hand, 283 Pull_Radish, 552 Carry_Water_Bucket_Walk. Walk and run come
free with every rig.

**Paths are not models.** `dirt_path` and `paved_path` (64 u and 128 u tall) are ground
decals and were not generated.

## Tool behaviour discovered — each one would cost the next person time

- **Failed Meshy tasks charge 0 credits.** Confirmed from `consumed_credits: 0` on a
  failed task. A retry costs nothing if it also fails.
- **meshy-7 fails on thin geometry** with `RepairDidNotCloseError` (fisher shelter:
  6,922 open edges from nets and poles), twice. **meshy-6 on the same concept worked.**
  The well, log stack and hearth failed once each and succeeded on regeneration.
- **The rate limit is roughly 10–14 requests per burst.** Beyond that, calls return
  "Rate limit exceeded"; waiting a few seconds clears it.
- **A long robe defeats the auto-rigger.** `422 Pose estimation failed` on the badger
  steward, whose legs are hidden. Trousers rigged first time.
- **Rig and animation downloads do not save a file.** `meshy_download_model` returns
  signed URLs for those task types, and they expire in about 28 hours. The task itself
  persists, so asking again produces fresh URLs.
- **`meshy_list_tasks` ignores its `status` filter** when listing, and returns every
  status.
- **These Meshy GLBs are glTF-compliant Y-up**, not Z-up as the asset-pipeline skill says.
  The high-poly sources are Y-up and centred on the origin; the remeshes are Y-up with the
  feet at y = 0. `prep_unit.py`'s fixed +90° X rotation would lay them on their backs, so
  run it with `--no-rotate`. The skill's warning may have been true of older Meshy output;
  it is not true of this batch.
- **Meshy's automatic remesh destroys foliage and thin woven geometry** at these budgets.
  Bramble, fern, wildflower patch, birch, apple tree, bean poles and the basket rim all
  shattered, while every one of their high-poly sources is good. Foliage L0s must be built
  in Blender (leaf cards with alpha), which is the GAP-07 vegetation question again.
- **The library is 13.7 GB**, 1,105 files. The first estimate of 2–4 GB was wrong by more
  than a factor of three, mostly because 2K PBR texture sets are embedded in every GLB
  *and* saved beside it. That size against GitHub's 1 GB free LFS tier is why the
  binaries stay out of git.
- **The ledger reconciles to the credit.** `credits_charged` in the committed ledger sums
  to 3,728 = 3,763 − 35. It first came out 150 high, because each failed task had stayed in
  the ledger as live alongside its FAILED row. Failed tasks charge nothing.
- **`*.glb` *is* LFS-tracked** (`.gitattributes` line 11, since a54041f), so committing
  the library would put 13.7 GB into LFS against GitHub's 1 GB free tier. An earlier draft
  of this record said the opposite, because it read `.gitattributes` through `head` and
  stopped at line 10. The skill-fix session caught it; `git check-attr filter` confirms it.

## What this does not do

It does not accept any art, satisfy ART-CREATURES' production bodies, make any level of
detail below L0, verify facing, pack textures to the 2048² family contract, or touch any
gate in `art_approvals.json`. The existing `godot/assets/units/species_mouse_body_a_lod0.glb`
is unchanged.

## Addendum — 2026-09-26: the rigs checked in motion

Brendan asked to see the creatures moving, so the animated files were played in Blender 5.2.1
and in Godot 4.7.2. That surfaced one error in this batch and settled two open questions.

- **Meshy's `height_meters` scales the longest rest-pose dimension, not the height.** In
  T-pose, mole_digger, mole_mason and badger_cellarer are wider than they are tall, so their
  rigged and animated files came out at 0.734, 0.759 and 2.121 m against 0.90, 0.90 and
  2.55 — and in each case the *width* equals the target exactly. Measured from the glTF
  accessors of `rigged.glb` and `anim_walk.glb`, and matched by Godot's own mesh AABB. The
  other seven are exact, and every L0 is exact, because the remesh used `resize_height`,
  which does mean height. **Anyone rigging through Meshy should pass the height the
  longest axis will scale to, or rescale afterwards.** An earlier Blender render sent to
  Brendan was described as showing true relative heights; for these three it did not.
- **Facing is +Z**, glTF's front. The project faces −Z, so every creature takes a 180° turn
  on import. This was the one property the asset-pipeline skill says only a human can
  check. A camera on +Z in Godot sees every face.
- **Godot imports these files upright with no rotation,** confirming the Y-up measurement.
- **In motion, the missing tail chain is visible.** Bending clips leave the tail rigid on the
  hips. The production rig's tail chain is a requirement, not a refinement.
- **The 2 m `Icosphere` seen in Blender is not in the files.** 0 of 110 rigged and animated
  GLBs contain one. Blender's glTF importer creates it as the bones' display shape
  (`io_scene_gltf2/blender/imp/node.py`; off with `disable_bone_shape`). A first reading
  blamed the files, and was corrected before this addendum merged.
- **The rig step also breaks the material, in all 110 rigged and animated files.** It keeps
  only the colour map, and then:
  - sets **no metallic or roughness**, so glTF's default of metallic 1.0 applies;
  - wires the colour map in **a second time as full emission**;
  - sets `KHR_materials_specular` to **2.0**;
  - **drops** the L0's roughness and normal maps.

  Godot's imported material reads metallic 1.00, roughness 1.00, emission on, and the cloth
  renders glossy and self-lit. All 162 high-poly and L0 files are correct (roughness median
  0.93, metallic 0), and the rigged mesh *is* the L0 mesh, with identical triangle counts. So
  the fix is a local material repair, not regeneration: metallic 0, emission off, specular
  1.0, and the L0's own roughness and normal maps. A Godot override with a constant
  roughness of 0.93 was captured before and after; see
  `contact_sheets/gloss_before_after.png`.

