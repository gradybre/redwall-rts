# Art pass 3: each asset and the code it serves

[Decision 0971](../decisions/0971-art-pass-3-preserving-brewing-digging-and-free-effects.md) records what was bought
and why. This file is the integration map. **Nothing here is wired into gameplay code.** The features that use these
assets are queued and not yet built:

- preserving (#18, ADRs 0641–), brewing (#19, 0651–) and feasts (#9, 0661–);
- the digging revamp (#51, 0831–);
- hives (group Y);
- livelier weather (#34, 0751–);
- the water revamp (#54, 0841–).

Each section below says what the integrator changes.

The nine icons were made in the 3D-render style after Brendan's ruling (see [Icons](#icons) at the end). Their briefs
are in [`art_pass3_icon_prompts.md`](art_pass3_icon_prompts.md).

## Where the files are

- **Library (gitignored, decision 0188).** Each model's library folder is `assets/library/prop/<key>/`. It holds the
  concept, `highpoly.glb`, the derived `l0.glb`, and for the kit `l0_post.glb` and `l0_lintel.glb`. All of them can be
  rebuilt from the task IDs in [`asset_library/meshy_tasks.jsonl`](asset_library/meshy_tasks.jsonl); those rows
  carry "art pass 3".
- **Staged (gitignored, decision 0196).** Staged copies go in `godot/demo/assets/props/<key>.glb`. Their measurements
  are in `godot/demo/assets/art_pass3_models.json`.
- **Rebuild (free; needs `blender`; reads the main checkout's library when a worktree has none):**

  ```
  python3 tools/make_art_pass3.py
  python3 tools/make_art_pass3.py --check-ice
  ```

  The second command checks that `water_iced.gdshader` is still `water.gdshader` plus its ICE lines.
- **Free effects (committed; nothing to stage).** These are in `godot/demo/fx/` (`bee_swarm.gd`, `fire_fx.gd`,
  `lightning_fx.gd`) and `godot/demo/water/` (`water_ice.gdshaderinc`, `water_iced.gdshader`). They build their own
  meshes and materials, so they draw the same in CI and on a fresh clone.

**Review sheets.** The review sheets are in the session scratchpad's `art3_check/`, not committed. Every file they
show can be remade with the tools above:
- `concepts.png`;
- `lineup_preserving_brewing.png`, `lineup_digging.png`, `digging_from_above.png`;
- `fx_bees.png`, `fx_fire.png`, `fx_lightning.png`, `fx_ice.png`.
- `icons_dark.png`, `icons_light.png`.

**Prescaled, facing +Z.** Every model is at game scale, as pass 1's are (decision 0941):
- its row's `height_m` is its height in metres;
- its origin is the ground centre, its bottom at y = 0;
- it faces glTF +Z, as authored.

So a `demo_props.gd` `SIZES` row of `[RULE_HEIGHT, height_m]` draws it at scale 1.0. **The sizes are Brendan's**
(approved 2026-10-02 as proposed; [DEC-048](../setting_decisions.md)): demo presentation sizes beside the 1.00 m mouse.

## Preserving, brewing and feasts: the kitchen's stations

Today the kitchen has one working point, the cauldron (`kitchen/kitchen_places.gd`, decision 0381). Each point there
is a position plus the spot a resident stands at to work it (`stand_*`), found on rings round the point. A station
below is one more such point, and its model is drawn where the point is.

| Key | Staged file | Height (DEC-048) | Size W×H×D (m) | Triangles / texture | Serves |
|---|---|---|---|---|---|
| `crock_stoneware` | `props/crock_stoneware.glb` | **0.50 m** | 0.46 × 0.50 × 0.42 | 1,150 / 1,024 (small prop) | **Preserving (#18): the pickling and salting crock.** A lidded salt-glazed crock beside the preserves shelf; several stand in a cellar. |
| `jar_shelf` | `props/jar_shelf.glb` | **0.95 m** | 1.35 × 0.95 × 0.38 | 1,888 / 1,024 (furniture) | **Preserving (#18): the preserves store's face.** Two plank shelves of cloth-capped jars: jam, honey, pickles, fruit. |
| `ale_cask` | `props/ale_cask.glb` | **0.80 m** | 0.88 × 0.80 × 0.69 | 1,900 / 1,024 (furniture) | **Brewing (#19): the conditioning cask**, on its side on a two-beam cradle, with a spigot in its head. **Feasts (#9)**: the cask the drink is drawn from at the hall. |
| `brew_vat` | `props/brew_vat.glb` | **0.95 m** (its rim at 0.80 m) | 1.26 × 0.95 × 1.28 | 1,898 / 1,024 (furniture) | **Brewing (#19): the mash tun station.** An open hooped vat of foaming mash on a fieldstone ring, a paddle in it, a tap low on its side. |

To integrate:
- Add each key to `demo_props.gd` `SIZES` as `[RULE_HEIGHT, <height>]`.
- Have the staging step copy the rows from `art_pass3_models.json` into the manifest's `world` section, as pass 1's
  `make_demo_food_art.py` does.
- Brewing's vat: when a batch is in the vat, its steam can reuse `kitchen_view.gd`'s steam quads (no particles), set
  over the vat's rim at 0.80 m.
- The cask's spigot is on its +Z head. Turn the cask so its head faces the stand spot.
- `jar_shelf` is a different object from the library's `pantry_shelf`:
  - `pantry_shelf` is 1.35 m: three tiers of pots, a cheese and herbs, the general larder (decision 0210).
  - `jar_shelf` is low and wide: preserves only.
- The existing upright `barrel` stays the village's general store cask, at 0.95 m (`world_sizes.gd`) and 0.5 m in
  cellars. `ale_cask` is the brewing one; one model does not serve both.

## The digging revamp: timber supports and rock

### The timber set: post, lintel and the assembled set (`tunnel/tunnel_marks.gd`, `burrow/room_view.gd`)

The bore profile it is sized to, from `tunnel/bore_mesh.gd` and `tunnel_rules.gd`:
- the standard bore's floor is 1.0 m wide (`FLOOR_HALF_M[0]` 0.5);
- it is 1.1 m wide at the springline, 0.45 m up;
- its crown is 1.0 m.

`tunnel_marks.gd` stands a frame **0.72 of the crown** tall (`FRAME_CROWN_SHARE`). The U view cuts it at **0.62 m**
(`BRACE_CUT_M`): there the posts show and the cap beam over a walker's head is cut away.

| Key | Staged file | Size W×H×D (m) | Triangles / texture | What it is |
|---|---|---|---|---|
| `tunnel_post` | `props/tunnel_post.glb` | 0.16 × **0.668** × 0.17 | 514 / 1,024 (small prop) | One adzed oak **prop**: squared, with a flared foot and a tenon on top. Its shoulder (the tenon's base) is at 0.883 of its height, **0.59 m**. Stood plumb (it leaned 0.4° as generated). |
| `tunnel_lintel` | `props/tunnel_lintel.glb` | **1.10** × 0.13 × 0.125 | 686 / 1,024 (small prop) | The **cap beam**: notched housings near each end on its upper face. It spans the springline (1.1 m). Its cross-section is squashed to 0.13 m; Meshy's was twice as deep as a cap over a 0.6 m post reads. |
| `tunnel_set` | `props/tunnel_set.glb` | **1.10 × 0.72** × 0.17 | 1,714 / 1,024 (furniture) | The **standard bore's set**: two posts with their outer faces on the floor's edges (±0.5 m; centres at ±0.4185), and the lintel seated on their shoulders, so each tenon enters a housing. One mesh, one material. |

**Swapping it in (the digging revamp):**
- In `tunnel_marks.gd`, set `BRACE_KEY` to `&"tunnel_set"` and add `&"tunnel_set": [RULE_HEIGHT, 0.72]` to
  `demo_props.gd` `SIZES`.
- `frame_fit()` already squeezes any staged brace to the unit 1 m × `FRAME_POST_M` frame, and `_bore_transform` scales
  it to the bore. So the set drops in without other changes, and the cutaway shader copies its albedo, as it does the
  old brace's.
- Its 0.72 m height is the frame height, so at the U view's 0.62 m cut the lintel is cut and the posts stand. That is
  the same read as today.
- The cutaway shader copies only the albedo, tint and roughness (decision 0207). The set's normal map is not drawn
  there, as with the old brace.

**Modular use, for anything but the standard bore:**
- **Wide bore** (2.0 m floor, 1.1 m crown): three posts and two lintels end to end, the middle post under the joint.
  This is how a wide drift is timbered. Do not stretch one lintel 2×: its notches and grain would stretch with it.
- **Rooms' ribs** (`room_view.gd` `RIB_TALL_M`, the cellar beam): posts at the room's width with lintels end to end,
  or the set scaled in height only.
- **The dig face's next frame**, while a BRACE job works: the post alone can rise first (decision 0211's "put up one
  at a time"), then the lintel.
- The **old `tunnel_brace`** (decision 0204) stays the fallback and the cellar's.

### Rock against earth (`tunnel/tunnel_ground.gd` ROCK, `tunnel/bore_dressing.gd`)

| Key | Staged file | Size W×H×D (m) | Triangles / texture | What it is |
|---|---|---|---|---|
| `rock_face` | `props/rock_face.glb` | **1.00** × 0.765 × 0.24 | 1,150 / 1,024 (small prop) | A slab of blue-grey layered bedrock with quartz veins and pick marks, and dark earth crumbling along its ragged top and side edges. Its front (glTF +Z) is the rock face; its back is flat. |

It reads as rock against earth because the bore's earth (`bore_earth.gdshader`) is warm brown, while this is cool,
fractured and veined. See `lineup_digging.png` and `digging_from_above.png`.

To integrate, in the digging revamp:
1. **Along a bore.** Where `tunnel_ground.gd` `type_at_level()` is `ROCK`, dress the bore's walls with `rock_face`
   pieces:
   - add a third MultiMesh beside `bore_dressing.gd`'s stones and roots, a slot per segment;
   - place one a step on each wall, **back to the wall, front to the bore's centre line** (+Z inward);
   - put its base on the floor;
   - turn it to the wall's local tangent, as `_add_stone` beds its stones;
   - roll its own dice per step, so a rock stretch is not a tiled wall.

   At 0.765 m it covers the wall to past the springline (0.45 m) and under the U view's cut. Keep its top under the
   section plane on ramps (`dressed_at`).
2. **At the dig face.** While a rock metre waits for its breaker ("needs the badger", `dig_readout.gd`), one piece
   stands **across** the face, its front toward the digger.
3. **Its colour.** The texture is fairly saturated blue-grey. If it reads too cool beside the earth under the U view's
   lantern light, tint it toward `bore_dressing.gd` `STONE_COLOUR` through the instance colour; that is free, with no
   re-bake.

## Hives (group Y): bees — `godot/demo/fx/bee_swarm.gd`

The swarm is ten bees, one MultiMesh, and no particles: the warren's particle budget is spent (decision 0211). Each
bee flies its own seeded loop about the hive and makes a forage run out and back every few seconds. Its wings beat in
the vertex shader.

| | |
|---|---|
| Bee size (DEC-048) | `BEE_LENGTH_M` **0.09 m**: about half a bee's true ratio to a mouse, so a swarm reads as specks over the skep, never as birds |
| Its hive | the library's `bee_skep` (pass 1, decision 0941, staged at 0.75 m) |
| API | `configure(layer)`, `place(at)` (the skep's base), `set_speed(speed)` (the demo clock; 0 paused), `set_active(on)` (a hive in season), `set_reduced(on)` (reduced motion: closer, slower, wings blurred) |
| Cost | ten instance transforms a frame per swarm. The mesh and wing material are shared by every swarm, and nothing is allocated after `configure` |

To integrate: the hives feature makes one swarm per occupied skep and calls `set_active(false)` in winter. It calls
`set_speed` with the HUD's speed, and `set_reduced(DemoMotion.reduced)` when the setting changes.

## Weather (#34): lightning and the fire it starts — `godot/demo/fx/lightning_fx.gd`, `fire_fx.gd`

**Lightning.**
- There are four forked bolts, pre-built from seeds, each stretched by `strike(sky, ground)` to its span, so a strike
  allocates nothing.
- The flash is two return strokes and a fade over 0.6 s. An OmniLight3D at the strike carries it.
- The weather view can hand in its sun (`sky_light`) to lift, and read `flash()` (0..1) to brighten its sky.
- Strikes are at least `MIN_GAP_S` 1.5 s apart (`strike` returns false otherwise). That is never more than two flashes
  in any second, under WCAG 2.3.1's three.
- `set_reduced(true)` gives one soft swell and no restroke.

**Fire.**
- One fire is three CPUParticles3D (flames, smoke, embers: `allocated()` = **54 particles**) and one light, all built
  in `configure`.
- `ignite(at, size_m, burn_s)` starts it. It runs catching → burning → dying (`douse()`, or `burn_s` running out) →
  smouldering → idle. `release()` returns it to a pool at once, and `is_idle()` tells the pool it is free.
- The flames scale with `intensity()`, so a dying fire shrinks into its embers.
- Sizes are demo values: a shrub 1, a woodpile 1.5, a thatched roof 3.

To integrate:
- `demo_weather.gd` has no storm condition yet (Clear, Rain, Snow, Frost). #34 adds one, and decides when a strike
  lands and whether it catches.
- Keep a small pool of `fire_fx` (2–3 suffice: 108–162 particles, **outside** the warren's 200, like the woods' chips).
  On a catching strike, take an idle one and `ignite` it at the strike.
- `demo_motion.gd` already cuts every CPUParticles3D's count with reduced motion. Also call `set_reduced` on each fire
  and the lightning.
- What burning **does** (damage, spread, putting it out) is #34's ruling, not an asset's.

## Water (#54): winter ice — `godot/demo/water/water_ice.gdshaderinc`, `water_iced.gdshader`

The include adds winter ice to the water surface. With `ice_cover` 0 it changes nothing.

**Where it freezes:**
- Ice grows out from the **shallows over the deep** as `ice_cover` rises 0 → 1, so a pond skins at its margins first
  and closes over its deepest water last.
- **Flowing water resists**: faster than `ice_flow_open` (0.14 m/s) stays open. So the stream keeps an open channel
  with shelf ice along its slow edges, consistent with pond_ice.gd's "the stream never freezes".

**What it looks like, by `ice_thick`:**
- thin ice is dark, glassy and see-through;
- safe ice is milky blue-white, crazed with fine cells and a few long fractures, with bubbles caught in it;
- `ice_snow` lies on it in drifts.

The ripple normals are stilled under it. See `fx_ice.png`, left to right:
1. open water;
2. a pond freezing from its margins (0.45);
3. thin ice;
4. safe ice with snow;
5. the stream with shelf ice and its open channel.

To integrate, in the water revamp:
- **Switching it on.** Either give a frozen body's material `water_iced.gdshader` (`water_surface.gd` `_material`,
  per body), or fold the two `// ICE` lines into `water.gdshader` and delete the copy. `make_art_pass3.py --check-ice`
  guards the copy until then.
- **Its feeds**, all presentation:
  - `ice_cover`: from `fishery/pond_ice.gd` `thickness_um`, e.g. 0 below `FROZEN_UM` and easing to 1 by it.
  - `ice_thick`: `(thickness_um − FROZEN_UM) / (SAFE_UM − FROZEN_UM)`, clamped. Thin ice then reads thin and safe ice
    safe, as the fishing rules treat them.
  - `ice_snow`: the weather's lying cover (`weather_view.gd` `COVER` × snow), because liquid water never whitens but
    ice does.
- **Retire the flat ice sheet.** `fishery_view.gd` draws its own ice mesh over the pond (`_build_ice`, `SAFE_ICE`,
  `THIN_ICE`). With this on, that sheet should go; the ice-fishing hole stays.

## Icons

Brendan ruled on 2026-10-02 that item and dish icons stay in the 3D-render style of the pantry icons (decision 0971;
the UI lock is amended to match). The nine are cut from one sheet, `assets/library/icon/sheet_preserves_finds/sheet.png`
(task `01a0fc94-6141-7684-be9b-4193024f9aab`), by `python3 tools/make_art_pass3.py --icons`:
- into `godot/demo/assets/icons/<key>.png`, 128 px RGBA, the same size and cut as pass 1's and `make_demo_props.py`'s;
- with their rows (sheet, cell and hashes) in `godot/demo/assets/art_pass3_icons.json`.

The keys are proposed. Wire icons **by key**, never by index (pass 1's `index_collisions` note).

| Key | Cell | Serves |
|---|---|---|
| `item_jam` | 0,0 | Preserving (#18): jam |
| `item_pickles` | 1,0 | Preserving (#18): pickles |
| `item_dried_fruit` | 2,0 | Preserving (#18): dried fruit |
| `item_cheese` | 0,1 | Preserving (#18) and feasts (#9): cheese. Pass 1's `sheet_dishes_c` (1,2) holds an uncut alternative |
| `item_ale` | 1,1 | Brewing (#19) and feasts (#9): ale |
| `item_cider` | 2,1 | Brewing (#19) and feasts (#9): cider |
| `find_coins` | 0,2 | Digging revamp (#51): a find, beside `tunnel_finds.gd`'s flint and clay |
| `find_old_map` | 1,2 | Digging revamp (#51): a find |
| `find_spring` | 2,2 | Digging revamp (#51): striking a spring |

To integrate:
- Add the rows to the manifest's top-level `icons` section, `{key: {"icon": res://...}}`, as pass 1's staging does.
  `tools/demo_texture_imports.py` already finds images anywhere in the manifest.
- The panels draw them as they draw the pantry's.

## Flax, linen and beeswax icons (decision 0972)

The sheet is `assets/library/icon/sheet_flax_linen_wax/sheet.png` (task `01a0fce6-bbf4-75f2-92a6-c99baf0c1a38`). It
is in the same 3D-render style and the same cut as the nine above, and `make_art_pass3.py --icons` writes it to
`godot/demo/assets/icons/<key>.png`. Each row of the sheet is one good: the main key first, then two alternates.

| Key | Cell | Serves |
|---|---|---|
| `item_flax` | 0,0 | The flax crop's harvest (`farm_catalog.gd`; `plant_flax`, decision 0951): a tied sheaf with seed bolls |
| `item_flax_fibre` | 1,0 | Alternate: combed fibre, if the fibre-to-cloth chain shows a stage between straw and cloth |
| `item_flax_seed` | 2,0 | Alternate: seed, for the seed store (sowing next year's flax) |
| `item_linen` | 0,1 | Linen cloth: the infirmary care shelf's cloth (the infirmary work, decision 0621 on its branch) and the fibre-to-cloth chain's product |
| `item_linen_bolt` | 1,1 | Alternate: a tied bolt (a trade or store quantity) |
| `item_linen_thread` | 2,1 | Alternate: thread, if spinning becomes its own stage |
| `item_wax` | 0,2 | Hives (group Y): beeswax, beside `item_honey` |
| `item_wax_candles` | 1,2 | Alternate: candles, if wax is made into lights |
| `item_wax_comb` | 2,2 | Alternate: empty comb, as wax comes from the skep |

Add the rows to the manifest's top-level `icons` section, as for the nine above.

## The eleven dishes' icons (decision 1831)

Two sheets in the same style and cut: `assets/library/icon/sheet_dishes_feasts_breakfasts/sheet.png` (task
`01a121b3-a6d1-736d-a23c-8d5b0b8008c4`) and `assets/library/icon/sheet_dishes_suppers/sheet.png` (task
`01a121b4-1c00-7232-9bb7-94c58cdd265e`). Unlike the sheets above, these keys are final: each is the `dish_<key>` that
`meal_rules.gd` DISH_ICON_KEYS builds from `dish_book.gd`, so the Pantry's kitchen rows and the Kitchen tab draw them
with no wiring (the field guide draws no icons). The spare cells hold empty vessels and are not cut.

| Key | Sheet | Cell | Dish |
|---|---|---|---|
| `dish_feast_fish` | feasts and breakfasts | 0,0 | Feast fish |
| `dish_berry_tart` | feasts and breakfasts | 1,0 | Feast tarts |
| `dish_nut_roast` | feasts and breakfasts | 2,0 | Bean, root and nut roast |
| `dish_orchard_crumble` | feasts and breakfasts | 0,1 | Banquet crumble |
| `dish_porridge` | feasts and breakfasts | 1,1 | Wild oat porridge |
| `dish_barleymeal` | feasts and breakfasts | 2,1 | Barleymeal porridge |
| `dish_soup` | suppers | 0,0 | Togget's vegetable soup |
| `dish_beetroot_soup` | suppers | 1,0 | Wild-beetroot soup |
| `dish_vole_stew` | suppers | 2,0 | Vole vegetable stew (roots only) |
| `dish_fish_stew` | suppers | 0,1 | Poached perch or trout |
| `dish_poached_dace` | suppers | 1,1 | Poached dace |

`tools/stage_art_passes.py` writes them into the manifest's `icons` section, and recuts the icon record when it lacks a
key, so a restage brings them.
