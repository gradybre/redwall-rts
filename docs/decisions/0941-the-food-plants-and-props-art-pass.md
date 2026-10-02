# 0941 — The food, plants and props art pass: eleven models and 24 icons, staged and not yet wired
Date: 2026-10-01 · Status: Accepted

## Decision

On 2026-10-01 Brendan approved a paid art pass for the orchards, foraging, infirmary, dishes and hives
work. His words: **"Full pass, ~480 credits"**. The balance was 1,213 credits, and the coordinator set a
hard cap of 520.

**431 credits were spent**, measured from the balance: 1,213 before and 782 after. The ledger's
`credits_charged` column for this pass also sums to 431.

The pass made:

- **Eleven world models**, prescaled to game height. Each was normalised by `prep_unit.py`, imported by
  Godot 4.7.2 and measured.
- **24 icons**: ten foods and fourteen dishes.

Both are staged into the gitignored `godot/demo/assets/` by a new tool, `tools/make_demo_food_art.py`.
`stage_demo_assets.py` runs it.

**None of it is wired into gameplay.** The orchards, foraging, infirmary and dishes code is on branches
still being integrated. [`food_art_mapping.json`](../art-reference/asset_library/food_art_mapping.json)
names, for each asset, the stand-in it replaces, the branch and file that draws it, and how to wire it.

**Nothing here is accepted art.** Visual acceptance stays with Brendan, through `tools/art_gate.py`, as in
decision 0188.

## Authority

- **The approval.** Brendan's approval of this pass in the 2026-10-01 session; the itemised list is in
  the brief below. As with decision 0188, the approval was given in the session and is not recorded in
  `docs/planning/art_approvals.json`, which is Brendan's to edit and was not touched.
- **The UI art lock.** `asset_generation_lock.md` said "Paid generation NOT APPROVED" for UI
  illustrations. Brendan's approval of this pass overrides that **for these icons only**. Decision
  0961 (Brendan's rulings of 2026-10-01, PR #213) has since changed the lock to by-request.
- **Paid calls by a subagent.** These calls were made by a subagent within the approved list and cap.
  Decision 0961 records Brendan's choice, "Subagents may, within approved cap".
  - The first 330 credits were spent *before* that ruling, under the coordinator's delegation, while
    `paid_asset_process.md` still said a subagent may never call a paid tool.
  - The coordinator then paused the subagent. No paid call was made during the pause.
  - The pass resumed once Brendan ruled. The balance was checked before and after each group.

## The approved list, and what was made of it

**Models.** Each was made by the library's recipe:
- a `nano-banana-2` concept (6 credits), by image-to-image from the right-hand panel of the DEC-038
  image, as decision 0188 did;
- then a `meshy-7` textured high-poly (PBR, 2K, triangles, no remesh; 30 credits).

| Key | Replaces | Height | Triangles (family) |
|---|---|---:|---|
| `apple_tree` | the orchard's oak stand-in (apples) | 4.70 m | 5,800 (tree) |
| `pear_tree` | the orchard's oak stand-in (pears) | 5.20 m | 5,800 (tree) |
| `raspberry_canes` | the hedge's oak-at-0.15 raspberry canes | 1.40 m | 2,998 (tree) |
| `bramble_blackberry` | the hedge's blackberry bramble; the forage "bramble edge" | 1.20 m | 2,999 (tree) |
| `hazel_bush` | the forage "hazel brake" (nothing drawn now) | 3.00 m | 3,000 (tree) |
| `strawberry_patch` | the orchard's bed of five `plant_strawberry` | 0.35 m | 523 (ground cover) |
| `mushroom_forage` | the forage "beech hollow" (nothing drawn now) | 0.45 m | 552 (ground cover) |
| `herb_patch` | the forage "herb bank"; the infirmary's procedural herb clumps | 0.50 m | 546 (ground cover) |
| `apple_basket` | the orchard stand's empty baskets plus sphere heap | 0.40 m | 1,141 (small prop) |
| `bee_skep` | the coming hives (nothing drawn now) | 0.75 m | 1,886 (furniture) |
| `infirmary_ward` | the infirmary's borrowed `residence` | 5.50 m | 29,341 (building) |

**Icons.** Three `nano-banana-2` image-to-image sheets of nine, at 6 credits each, so 2.7 credits an
icon.
- Ten foods: apple, pear, berries, nuts, mushrooms, herb, potato, honey, flour and dried fish.
- Fourteen dishes: oatcake, farl, hardtack, salad, baked fish, biscuit soup, pasty, root pie, scones,
  cordial, woodland pie, nut loaf, herb infusion and bean hotpot.
- Cheese and milk filled the last two cells of sheet C. They are in the library, and are not staged.

## Choices made, and why

- **A concept and an image-to-3D model (36 credits), not text-to-3D plus refine (30).** Only the
  image route carries the DEC-038 style reference. `meshy_text_to_3d_refine` takes a reference only
  as a public URL. It is also the recipe of the library's three earlier passes.
- **The icons match the in-game pantry icons rather than the lock's ink-contour watercolour.**
  - They sit in the same Pantry list as the 23 existing icons. Those are 128 px renders of 3D props,
    with no contour.
  - So the first sheet was conditioned on a 3 x 3 of those icons, and the later sheets on the first.
  - The lock's conventions that do not conflict were kept: upper-left light, three-quarter view,
    transparent RGBA, no backing disc, and a restrained palette.
- **Game-budget L0s were made free in Blender, as the 2026-09-29 passes did**, not by paid remesh.
  - The bake is `demo_props_blender.py`'s prop job. It gives one material and one surface, which
    `season_view.gd` needs: it dresses surface 0 only, and only when that surface has an albedo
    texture.
  - **The one exception is the infirmary.** Its bake left black streaks across the slate roof and
    walls. It uses Meshy's 30,000-triangle remesh (5 credits), as decision 0188's buildings did.
  - That remesh's 4,096 px maps are resized to GAP-04's 2,048 px building edge.
  - The staged `residence` and `hall` still carry 4,096 px maps.
- **The fruit trees carry no fruit or blossom.** On the orchards branch, `season_leaves.gdshaderinc`
  paints blossom and fruit as speckles. It paints them only on leaf texels, which it finds by colour:
  green over red between 1.08 and 1.35, with green at least blue.
  - So the trees were prompted with plain green crowns.
  - Their crowns were prompted as "broad grouped leaf masses", like the oak, which survives
    decimation.
  - Measured on the baked albedo, the median green/red of leaf texels is 1.37 for the apple, 1.29 for
    the hazel and 1.24 for the oak.
  - **The raspberry measures 1.16**, so the shader's leaf mask only half-catches its yellow-green
    leaves.
- **The berry bushes carry their berries**, as the brief asked ("a bramble with blackberries", "a hazel
  bush with nuts"). The berries are red, black and brown, so the leaf mask leaves them alone, and they
  show in every season. The mapping file says so.
- **Prescaled, unlike the older staged models.**
  - The older ones are about 1.9 m native and are sized at run time by `world_sizes.gd` or
    `demo_props.gd`.
  - These arrive at game height. Each row carries `prescaled: true`, `height_m` and `sink_m`.
  - A rule that divides a target height by the manifest's AABB still works: its factor is 1.0.
  - Heights are demo-only, judged against the DEC-039 creatures. The fruit trees match the orchard's
    0.36 of a 13 m oak.
  - The infirmary is the tallest that fits both its 5.5 m envelope (`BUILDING_MAX_Y_MM`) and its 16 m
    (8 x 8 tile) footprint. The envelope binds first, so its plan is 11.8 m.
- **Sinks were measured.**
  - The pear stands on a square plate 0 to 0.12 m thick, so `sink_m` is 0.15.
  - The infirmary's earth base measures 0.25 m (median) to 0.32 m (90th percentile) at its rim, so
    `sink_m` is 0.33. The branch now sinks it 0.385 m (`SINK_SHARE` 0.07).
- **Icons go in a new top-level `"icons"` section of the manifest.**
  - `demo_props.gd` loads only rows it sizes, and those must have a model.
  - `demo_texture_imports.py` already walks the whole manifest, so the icons are packed as files
    (importer `keep`).
  - The wiring step must teach `icon_of` to read this section.
- **`prep_unit.py` gained `--allow-flat`.** Its `upright` check (height at least depth) cannot tell a
  wide model from one lying on its back. These sources were *measured* Y-up from their accessor bounds,
  so the check is skipped for the patches, the bramble, the basket and the infirmary. Height and
  ground-origin checks still run.

## What was redone, within the cap

| What | Why | Cost |
|---|---|---:|
| Pear concept | The first was a thin, poplar-like sapling | 6 |
| Infirmary concept | The first was two-storey and tall, against a 5.5 m envelope on a 16 m footprint | 6 |
| Infirmary L0 | The Blender bake streaked black, so Meshy's remesh was used | 5 |
| Bramble | See below | 36 |

**The bramble.** The library's 2026-09-24 bramble (reused at first, free) shattered into floating leaf
clumps: at 2,410 triangles, and again at 5,230. A new one was generated as a solid mound of leaf masses.
It decimated cleanly to 2,999.

The two rejected concepts are kept in the library as `concept_v1_rejected.png`. Their ledger rows are
marked `superseded`.

## Known and left

- **The baked-fish icon has lemon slices**, which the woodland setting does not have. They are not
  legible at 28 px. Left.
- The herb-infusion icon keeps a wisp of steam.
- The raspberry's leaf mask is weak, as above. The wiring step can retune it or accept it.
- **Facing.** Every model faces +Z, as authored. The Godot front views confirm the infirmary's porch and
  the skep's entrance face +Z. The project faces −Z, so presentation roots turn them, as for every
  staged model.
- **The demo project's texture settle step was not run in this worktree.**
  `demo_texture_imports.py --godot godot` imports all 3.9 GB of staged assets. The models were imported
  and measured in a throwaway Godot project instead.
  - All eleven loaded at their height, with min y = 0, one surface each, and an albedo texture on
    surface 0.
  - The icons' `.import` files (`keep`) are written.

## Where things are

- **Ledger** (committed): `docs/art-reference/asset_library/`
  - `meshy_tasks.jsonl`: 28 rows;
  - `concept_prompts.json`: 16 rows;
  - `files.json`: 77 rows;
  - the README's "Food, plants and props pass" section;
  - `food_art_mapping.json`, with staged file hashes.
- **Binaries** (gitignored): `assets/library/{environment,prop,building,icon}/<key>/`.
- **Staged** (gitignored): `godot/demo/assets/world|props|icons/`.
- **Tools**: `tools/make_demo_food_art.py`, with its self-test `tools/test_make_demo_food_art.py`.
