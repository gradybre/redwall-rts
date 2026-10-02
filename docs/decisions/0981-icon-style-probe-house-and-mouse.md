# 0981 — Icon-style probe: one house and one mouse, compared at the game camera

Date: 2026-10-02 · Status: Accepted (a probe; it changes no direction)

## Decision

Brendan asked to see the whole game in the style of the item icons: **"build a 3d style house and character
(like the icons) so I can see what that version would look like for the game as a whole"**. He approved the
probe on 2026-10-02. The coordinator gave a subagent a hard cap of 95 Meshy credits (decision 0961: paid calls
by a subagent within an approved cap).

The probe made two assets:

- an icon-style `residence`, the same building type, sized to the staged residence's footprint;
- an icon-style mouse field worker at the 1.0 m tier, in a static pose.

Both were compared with the current assets in the demo village, under the demo's own light. **No gameplay code
changed and nothing was wired in.** The probe assets were staged only into the gitignored
`godot/demo/assets/style_probe/`, for the scratch scene.

**This record makes no recommendation.** DEC-038 (`docs/setting_decisions.md`) remains the approved world
direction. Whether to move towards the icon look is Brendan's call.

## The three styles, as found

**1. The icon style.** There are two sources.

The 23 staged pantry icons (`godot/demo/assets/icons/`, cut by `tools/demo_props_blender.py` `render_icon`) are
renders of the demo's own Meshy prop models:
- Cycles, the Standard view transform with no filmic or ACES curve, and a transparent film.
- Orthographic, 28° elevation and 32° azimuth, framed tight on the object.
- Three suns: a key at 3.2 from the upper left, a fill at 0.9, and a rim at 1.6 from behind. The rim gives
  every silhouette a lit edge.
- A soft grey world at 0.55.
- No ground, fog, ambient occlusion or distance.

Pass 1's food and dish icons (decision 0941, `assets/library/icon/sheet_*`) are `nano-banana-2` images
conditioned on those renders. They push the same look further: "painted stylized-realistic 3D".

Precisely, the icon style is:
- **Rendering and lighting:** a studio render with smooth, gradient shading. Light is soft and comes from
  the upper left, with a cool fill and a thin rim. Shadows are faint and there is no cast-shadow ground.
- **Saturation:** warm and natural, clearly richer than the world's (carrot orange, beet crimson, cabbage
  green, chestnut fur).
- **Edges:** no ink contour or linework. Silhouettes are clean and separated from the background only by
  value and the rim.
- **Materials:** matte, with soft specular. There is fine surface detail, but no grit or texture noise.
- **Shape language:** compact, rounded objects that read whole.

**2. The current world style.** This is DEC-038 and `docs/art-reference/visual_direction_alignment.md`, with the
approved courtyard image (`docs/art-reference/visuals/grounded_expressive_rts_example_v1.png`):
- "Restrained moss green, oatmeal, ochre and earth tones with deliberate value grouping".
- Distinct cloth, leather, iron, timber and stone.
- A warm, inhabited scene composed for the elevated RTS view.

The world's assets were made from its right-hand panel. The residence concept
(`assets/library/building/residence/concept.png`) is a painted illustration with drawn edges and desaturated
grey slate.

In the demo, the world is lit by `world_look.gd`:
- one sun, 50° up, a little east of south;
- sky ambient at 0.65;
- the ACES tonemapper;
- SSAO;
- a light warm haze.

The camera is perspective, with a 40° field of view, a 50° pitch and a 22 m distance.

**3. The UI art lock's watercolour.** `docs/design/ui_refinement/asset_generation_lock.md` uses storybook
watercolour, I01 ink contours always, and twelve pigments. It governs UI illustrations only, and
`visual_direction_alignment.md` forbids extending it to 3D. It is context here, and the probe did not use it.

**A finding that shapes how to read the comparison.** Rendered through the icon rig, the *current* residence and
mouse already look like icons (contact sheet, panels 9 and 11). Much of the gap Brendan sees is the render and
not the asset:
- a close orthographic studio shot with a rim light and no tonemap curve;
- against a 22 m perspective view through ACES, haze and one sun.

What the icon-style assets themselves add:
- chunkier, rounder, smoother forms;
- lighter, bluer slate and warmer, oranger timber;
- higher saturation;
- a more toy-like stylisation than the food icons.

## How it was made

The recipe is the asset library's (decision 0188):

**Concepts.** Each concept is `nano-banana-2` image-to-image, 6 credits. The style references were:
- a 3×3 of nine staged pantry icons (`item_strawberry`, `onion`, `turnip`, `peas`, `trout`, `beetroot`,
  `carrot`, `relic_bell`, `lettuce`) on #E0E0E0;
- pass 1's `sheet_foods_a`.

The concepts were:
- **Mouse:** with the current `mouse_fieldworker` concept as the third reference. It was on-style first time.
- **House, first attempt:** with the current residence concept as the third reference. **Rejected as clearly
  off-style.** It came back as a near-copy of the painted concept.
- **House, the one redo:** made without that reference, from the style references and a written description
  of the same cottage. It is used.
  - It is a clearly 3D-rendered look.
  - It is chunkier and more toy-like than the pantry icons.
  - Its plan is narrower, with the chimney behind rather than at the side.

**3D.** Each model is `meshy-7` image-to-3D, textured, with PBR, 2K, triangles and no remesh: 30 credits.
- The outputs were already Y-up. The accessor bounds put the height on glTF Y, so there was no Z-up
  correction. The views confirmed it.
- The front faces glTF +Z, the demo manifest's convention. Both were checked by eye in front, side, back and
  top renders, and in the icon-rig render.

**Game budget, made free.** `demo_props_blender.py`'s prop job, as decision 0941 used:
- **House:** 30,000 triangles, against the staged residence's 29,665.
- **Mouse:** 10,400, against the staged `mouse_fieldworker` body's 10,375.
- Both are baked to one 2,048 px material, bottom origin, with facing kept.

**Measured in Godot 4.7.2**, from the instanced scene's mesh AABBs:

| Asset | Drawn size (W × H × D, m) | Rule |
|---|---|---|
| Current residence | 5.54 × 6.00 × 4.90, let down 0.42 | `world_sizes.gd` (6.0 m envelope, SINK_M) |
| Icon residence | **5.23 × 5.87 × 4.90**, let down 0.13 | uniform scale 3.0903 = the tightest of the residence's height, width and depth; sink = its baked dirt base, 0.039 native at the rim's 95th percentile, plus a margin |
| Current mouse | 1.00 tall (manifest) | `idle` clip at 0.6 s |
| Icon mouse | **0.58 × 1.00 × 0.48** | uniform scale to 1.00 m |

## The comparison

The comparison was made by a scratch SceneTree script, not committed. It used:
- the real `DemoWorld.build()` with the staged manifest;
- one 1920×1080 SubViewport at the project's 2× MSAA;
- shadow distance from `Look.shadow_distance_for()`.

Seven shots:
- the village with only current assets, with only icon assets swapped in, and mixed, all from the default
  game camera (focus west of the square, so residences a and b are in frame);
- both full versions again at a 12 m zoom;
- close-ups of each pair on the demo ground, under the demo sun and sky.

The contact sheet is [`contact_sheets/style_probe_2026-10-02.png`](../art-reference/asset_library/contact_sheets/style_probe_2026-10-02.png).
The panels it adds:
- the four icon-rig renders (current and icon, house and mouse);
- the concepts, including the rejected one;
- the two style references.

**No night shot.** Master has no day/night lighting: `world_look.gd` builds one fixed sun, and only weather dims
it.

The village view leaves out the farm, the water and the UI. It is the world layer alone.

## Spend

| Task | Model | Credits |
|---|---|---:|
| House concept 0 (rejected) | nano-banana-2 | 6 |
| Mouse concept | nano-banana-2 | 6 |
| House concept 1 (used) | nano-banana-2 | 6 |
| Mouse high-poly | meshy-7, PBR 2K | 30 |
| House high-poly | meshy-7, PBR 2K | 30 |
| **Total** | | **78** of the 95 cap |

The total is counted from this probe's own tasks: each task reported `consumed_credits`. The account balance was
374 before and 110 after, but another agent (art pass 3) was spending from it at the same time, so the balance
does not measure this probe. Nothing else paid was used.

The ledger rows are in decision 0188's format:
- five rows in `docs/art-reference/asset_library/meshy_tasks.jsonl`;
- three in `concept_prompts.json`;
- fifteen in `files.json`, with hashes.

The binaries are in the gitignored `assets/library/style_probe/`.

## Consequences

- Nothing here changes DEC-038, the UI lock or any asset in the game.
- The probe house and mouse are **not accepted art**. Visual acceptance stays with Brendan, as decision 0188
  says.
- If Brendan does want the icon look, there are two independent levers, which can be separated:
  - **Assets.** Regenerating the world and cast in that style.
  - **Rendering.** The demo's light, tonemap and haze, against the icon rig's studio light. This probe varied
    only the assets.
