# Art pass 2: each asset and the code it serves

[Decision 0951](../decisions/0951-art-pass-2-evergreens-portraits-stone-hall-flax-hall-art-and-wildlife.md) records
what was bought and why. This file is the integration map. **Nothing here is wired into gameplay code.** The feature
branches named below are being integrated separately; each row says what the integrator changes.

## Where the files are

- **Library (gitignored, decision 0188).** Library files are in `assets/library/<family>/<key>/`: the concept, the
  `highpoly.glb`, and the derived `l0.glb`. They are reproducible from the task IDs in
  [`asset_library/meshy_tasks.jsonl`](asset_library/meshy_tasks.jsonl).
- **Staged (gitignored, decision 0196).** Staged copies are in `godot/demo/assets/`:
  - models in `world/`, `props/`, `plants/` and `wildlife/`;
  - UI art in `ui/`;
  - measurements in `art_pass2_models.json`, `art_pass2_post.json` and `ui/art_pass2_ui.json`.
- **Rebuild everything:**

  ```
  python3 tools/make_art_pass2.py all
  python3 tools/art_pass2_ui.py
  ```

  This is free. It needs `blender`, and it reads the main checkout's library when a worktree has none.

**Review sheets.** The `art2_check/…` sheets named below are contact sheets for Brendan's review. They were made in
the session scratchpad (`…/scratchpad/art2_check/`), not committed; the tools above remake every file they show.

**Facing.** Every model keeps the library's convention: glTF **+Z front**, Y up, with the bottom at y = 0 unless noted.
The demo turns nothing on import (asset library README).

## Evergreens: the seasonal trees' `KIND_EVERGREEN` (decision 0551, `feat/demo-seasonal-trees`)

| Key | Staged file | Native size (glTF units) | `DEMO_HEIGHT_M` (Brendan, 2026-10-02) | Proposed `SINK_M` | Triangles / texture |
|---|---|---|---|---|---|
| `pine_scots` | `world/pine_scots.glb` | 1.062 × 1.900 × 1.024 | **16.0** (taller and narrower than the 13 m oak) | 0.6 | 5,686 / 1,024 |
| `yew_ancient` | `world/yew_ancient.glb` | 1.657 × 1.505 × 1.881 | **10.0** (low and broad: 16.5 m spread) | 0.6 | 5,658 / 1,024 |

Both models have one surface with one baked material and one UV set, which is what `season_view.is_staged()` and
`bare_boughs` require.

Snow uses the vertex normals' up component (`season_leaves.gdshaderinc`). Both crowns are layered pads that face up,
so snow lies on them. See `art2_check/winter_evergreens.png`.

The **pine's needles were teal**: blue was above green in 86% of crown texels, so decision 0551's leaf test (green ≥
blue) read them as bark. The `pine_tint` step turned them pine green, and 82% of the pine's texels now pass the leaf
test. The yew passed as generated, at 94% of crown texels.

To integrate:
- Add the keys to these tables:
  - `stage_demo_assets.py` `WORLD["environment"]`;
  - `world_sizes.gd` `DEMO_HEIGHT_M`, `NATIVE_AABB` and `SINK_M`;
  - `world_layout.gd` `TRUNK_RADIUS_M` (proposed: pine 0.45, yew 0.9);
  - `world_scatter.gd` `TREE_SPACING_M` and `_tree_key()`.
- Add `&"pine_scots": KIND_EVERGREEN, &"yew_ancient": KIND_EVERGREEN` to `season_view.gd` `KIND_OF_KEY`.
- Forestry (`forest_stand.gd` `LOOK_KEYS`) is optional.
- The library already has `l0.glb` in place, so staging copies it unchanged.

## The stone Great Hall: stage 2 (decision 0771, `feat/demo-great-hall`)

| Key | Staged file | Native size | Draw at |
|---|---|---|---|
| `hall_stage2` | `world/hall_stage2.glb` | 1.891 × 1.206 × 1.061 | the **timber hall's own scale**, 6.0686 (7.0 m / 1.1535): 11.47 × 7.32 × 6.44 m |

The model is the same hall rebuilt in red-grey sandstone. It keeps the gable end with the arched double doors, the
slate roof and the chimney, and adds stone buttresses, stone-mullioned windows and a **second chimney at the far end**.
It has 30,000 triangles and a 2,048 px texture with a tight unwrap.

It is turned and fitted to the timber hall's L0:
- the door gable faces **+X**, as the timber hall's does;
- its length along X equals the timber hall's, 1.8907;
- it is centred on the timber hall's X/Z centre.

Its depth is 2.5% more than the timber hall's (6.44 m against 6.28 m).

To integrate in `hall_view.gd`:
1. Show `hall_stage2` and hide the world's `hall` node while `projects.tier >= Rules.TIER_GREAT`. Place it with the
   hall's own transform and scale, not by `DEMO_HEIGHT_M` 7.0, which would shrink it 4%.
2. **Do not also show the composed second chimney** (`chimney_pot` at `CHIMNEY_LOCAL`): the model has its own.
3. Keep the roundels and banners: the walls are where the timber hall's are, give or take 8 cm.

## Hall banners (decision 0771's four Decoration banners)

| Key | Staged file | Native size | Surfaces |
|---|---|---|---|
| `hall_banner` | `props/hall_banner.glb` | 0.956 × 1.903 × 0.084 | **0 `banner_cloth`** (undyed linen, dye it), **1 `banner_wood`** (crossbar and cord, never dye it) |

The banner is a swallowtail linen banner on cloth loops from a turned crossbar with a hanging cord. It hangs upright
already, so it needs no `_hanging()` lie-flat turn. It has 1,900 triangles (furniture family) at 1,024 px.

To integrate:
- In `hall_view.gd`, replace `relic_banner` with `hall_banner`.
- Change `_dye()` to multiply **surface 0 only** with `BANNER_DYES[k]` (CLAY, LEAF, BRASS, SAGE). It currently assumes
  one material.
- Drawn height: 1.6 m (Brendan, 2026-10-02). That is `BANNER_SCALE` 0.84 against the native 1.903.
- The four tints at game scale are in `art2_check/lineup_small.png`.

## Tapestry panel art (decision 0771, `tapestry_panel.gd`)

The panel is procedural today: it has an OAT `StyleBoxFlat`, weave lines, stitched bands and diamond knots. These files
give it a woven ground and one embroidered emblem per entry kind. All are original village motifs: oak leaf, acorn and
wheat for the ground; seedling, hall, sheaf, snowflake, pennant, bridge, book and lantern for the emblems. **None is
Martin's tapestry and none shows a figure, animal or weapon** (LORE-R07).

| File (staged under `godot/demo/assets/`) | Size | Serves |
|---|---|---|
| `ui/tapestry/tapestry_ground.png` | 896 × 1200, RGBA (the wall keyed out; loops and fringe kept) | The panel's cloth. Nine-patch margins (l, t, r, b) **180, 226, 178, 232**. |
| `ui/tapestry/tapestry_ground_half.png` | 448 × 600 | The same for the 560 × 640 panel. Margins 90, 113, 89, 116. |
| `ui/tapestry/emblem_<kind>_{24,32,64,128}.png` | round, RGBA | One per `tapestry.gd` `KIND_*`, in its order: `founding`, `hall` (KIND_STAGE), `harvest`, `winter`, `dressing`, `milestone`, `chronicle`, `event`. They can replace or sit beside the `KNOT_R 7` diamonds. 24 px suits the 14 px knot row's line height. |

## Chronicle page (decision 0631, `feat/demo-chronicle`, `chronicle_window.gd`)

| File | Size | Serves |
|---|---|---|
| `ui/chronicle/chronicle_page.png` | 752 × 1048, RGB | A blank parchment page with an inked oak-leaf, acorn, bramble and wildflower border. Write text inside the area `text_area_ltrb` [130, 150, 622, 898] (`ui/art_pass2_ui.json`). Use it as a `TextureRect` or a `StyleBoxTexture` behind the page body, inside `FarmUi.frame()`, at `MAX_W` 720. |

## Resident portraits: the group tiles and the resident card

| Files | Serves |
|---|---|
| `ui/portraits/<cast key>_64.png` | Resident card / journal header at STANDARD and WIDE (`ui_resident_header.gd` `MEDALLION_PIXELS` 64; `ui_resident_card.gd` `EMBLEM_SIZES[1]`) |
| `ui/portraits/<cast key>_48.png` | The same at NARROW (48), and the multiselect **group tiles** (`group_panel.gd`: `TILE_H 46`; a 40 px draw of the 48 fits beside the `CHIP_W 6` colour bar) |
| `ui/portraits/<cast key>_24.png` | **Diagnostic only** (ART-LOCK-001 §5): a species test, not a size to ship |
| `ui/portraits/<cast key>_source.png` | The 512 px crop each is made from |

There is one portrait per named resident. They are keyed by cast key (`demo_people.json`):

| Cast key | Resident | Species |
|---|---|---|
| `mouse_keeper` | Wenna Tallowby | mouse |
| `mouse_fieldworker` | Jory Whitethorn | mouse |
| `squirrel_gatherer` | Linnet Whinberry | squirrel |
| `squirrel_forester` | Tobit Highbough | squirrel |
| `otter_boatwright` | Tegwin Slipstone | otter |
| `otter_fisher` | Corra Netley | otter |
| `mole_digger` | Tuppen Clayholm | mole |
| `badger_quarryman` | Hulda Slatebrook | badger |
| `beaver_bridgewright` | Elstan Weirholt | beaver |

Each wears the clothes of their own library concept.

The frame is ART-LOCK-001 §5's medallion:
- an opaque I03 roundel, 44 px across at 48 and 60 px across at 64;
- an I07 brass ring with an I01 contour;
- the shared oak sprig at lower left.

Today the card shows species **emblems** ("not a portrait", `ui_manager.gd`), and ART-UI-06 keeps emblems as species
marks. A per-resident portrait is a new slot beside that rule, not a replacement for the emblems. Badger and beaver have
no emblem at all, but they do have portraits.

## Flax: the farm's crop visuals (`farm_catalog.gd`, `farm_look.gd`)

Crops are staged as **one plant plus stage rules**, not as one model per stage:
- `make_demo_props.py` `PLANTS` makes a four-cell card atlas (full, side, thinned, sparse);
- `farm_look.gd` shows each stage by scale (`SEEDLING_SCALE 0.14` up to 1.0, `WITHERED_SCALE 0.72`), by cells
  (`CELLS_SPROUT` … `CELLS_WITHERED`) and by tint.

Flax follows that rule.

| Key | Staged | Notes |
|---|---|---|
| `plant_flax` | `plants/plant_flax.glb` (482 triangles), `plants/plant_flax_cards.png` (1,672 × 466, four cells) | Soil line **−0.797** (measured as `PLANTS`' are), tops **false** (upright, like barley). Its close-up mesh shatters at 580 triangles, as the other leafy plants' do, so draw it as cards (`PLANT_HEAD_MESH false`). |

To integrate:
- Add `"plant_flax": (-0.797, False)` to `make_demo_props.py` `PLANTS`.
- Add flax to these `farm_catalog.gd` tables: `PLANT_KEYS`, `PLANT_HEIGHT_M` (**0.80**, Brendan, 2026-10-02; a little over
  barley's 0.74), `PLANT_SPACING` (0.34, as the cereals), the top lift and top scale entries, `PLANT_HEAD_MESH` and
  `ITEM_VISUAL`.
- Flax is a FIBRE crop, and the demo grows none (`farm_catalog.gd:30`). Growing it is a gameplay decision for the
  farm, not part of this art.
- The stages under `farm_look.gd`'s rules are in `art2_check/flax_growth_stages.png`.

## Wildlife: the wildlife feature (#11)

The files are staged under `godot/demo/assets/wildlife/`. Each is skinned, with its clips as glTF animations.
**Import the clips with looping on** for idle, swim, flap, glide and rest; Godot imports glTF animations without
looping.

| Key | Size (Brendan, 2026-10-02) | Origin | Clips |
|---|---|---|---|
| `wild_songbird` (robin, perched) | 0.45 m long, 0.34 m tall | feet | `idle` 2.0 s, `hop` 0.5 s (in place), `peck` 1.0 s |
| `wild_songbird_flight` (robin, on the wing) | 0.45 m long, 0.70 m span | body centre | `flap` 0.2 s, `glide` 1.0 s |
| `wild_butterfly` (peacock) | 0.36 m span | body centre | `flap` 0.33 s, `rest` 3.0 s (perched, wings slowly opening) |
| `wild_frog` | 0.40 m long | feet | `idle` 2.0 s (breathing), `hop` 0.7 s (in place, stretch and land) |
| `wild_trout_leaping` | 0.80 m long | body centre (**y = 0 is the water surface**) | `swim` 1.0 s (in place), `leap` 1.4 s (**travels 1.2 m forward**, rising 0.5 m above the water and starting and ending 0.25 m under it) |

The sizes are judged against the 1.00 m mouse at the demo's storybook scale, where grass tufts are 0.45 m. **Brendan
approved them on 2026-10-02** (DEC-047; decision 0951). The bodies are exported at these sizes, in metres.

Every clip moves in place except the trout's `leap`, which carries its own travel. The hop has no forward step: move
the node about 0.15 m (bird) or 0.3 m (frog) during the air frames.

The rigs are authored in Blender (`art_pass2_blender.py`), not Meshy's, because Meshy's 24-joint humanoid rig cannot
take these bodies (decision 0951). The bird's flight is a second model because a perched robin's folded wings cannot
flap.

## Window glow masks: the night lights (decision 0541, `feat/demo-day-night`, `night_lights.gd`)

Each lit home gets two files:
- `world/<key>_window_mask.png`: a 1,024 px mask in the L0's own UV0 space. It is white on the window glass and
  feathered.
- `world/<key>_windows.glb`: the same L0 with that mask as its glTF `emissiveTexture` and `emissiveFactor` I11 Ember
  (0.851, 0.592, 0.263).

**It glows by day as staged.** At dawn and dusk, drive the material's `emission_energy_multiplier` (0 → about 1.5) from
the same flag as `set_home_lit(lit)`. The single surface and material are unchanged, so swapping `<key>.glb` for
`<key>_windows.glb` changes nothing else.

| Key (`LIT_HOMES`) | Mask | Result |
|---|---|---|
| `hall` | 0.79% of the texture | **Good.** All ten leaded windows of the two long sides glow. |
| `hall_stage2` | 0.55% | **Good.** The five tall mullioned windows a side, and a little at the door. |
| `kitchen` | 0.05% | **Small.** Little glazing: the door's light and a window. |
| `residence_a/b/c` (key `residence`) | 0.01% | **Effectively none.** Its windows are closed wooden shutters, with no glass in the texture. Keep the door spill light. |

The method:
1. Take dark, cool glass texels of the model's own albedo.
2. Keep only those under wall faces (rasterised from the UVs, because Meshy's atlas packs slate and glass alike), below
   the eaves and above the plinth.
3. Close the result over the lead cames, open it to drop mortar lines, then feather it.

The dormer windows above the eaves are not lit.

## The winter oak: bare boughs without shards (decision 0551 `bare_boughs.gd`)

| File | Serves |
|---|---|
| `world/oak_mature_bare.glb` (and the library's `environment/oak_mature/bare.glb`, `bare_albedo.png`) | An **authored** bare oak, 1.367 × 1.372 × 1.191 native units, 778 triangles, one surface. Draw it in place of `bare_boughs.bark_only(oak mesh)` for `oak_mature`. |

What was wrong was **two cuts that disagree**:
- `bare_boughs` keeps a triangle unless its texel is leaf at the 1.2 green-over-red **midpoint**;
- the tree shader then discards leaf texels from the ramp's **start**, 1.08.

The yellow-green leaf triangles between the two were kept as geometry and half-discarded as texels. That left the
angular shards that snow then whitened.

This model fixes it as follows:
1. **Cut** at 1.08, dropping any triangle whose texels are half leaf.
2. **Remove** islands under 2% of the area, slivers, and the flat flaps a cut branch ends in. Then drop pieces left
   floating and cap the branch ends with bark UVs.
3. **Settle** the root mound's outer skirt below the 1.2 m sink line.
4. **Fill** every leaf texel of its own albedo with bark, so the leaf shader discards nothing.

The result has 778 triangles, against the leafed L0's 5,829. A few root flares still catch snow at the base.

To integrate:
- In `season_view.gd`, load this mesh for `oak_mature` when it is staged, instead of `bark_only()`.
- It keeps the same scale and origin as `oak_mature.glb`: draw it with the oak's own transform.
- Before and after are in `art2_check/oak_bare_before_after.png` and `art2_check/winter_evergreens.png`.
- It is about 30% shorter than the leafed oak, because the branches inside the crown went with the leaves.
