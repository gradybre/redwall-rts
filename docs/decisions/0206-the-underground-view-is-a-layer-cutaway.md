# 0206 — The underground view is a layer cutaway
Date: 2026-09-30 · Status: Accepted

Phase P0 ("Cutaway foundation and stall fix") of the approved underground revamp
([`docs/design/underground_revamp.md`](../design/underground_revamp.md) §5 and §8; Brendan's rulings in
its §10). It replaces the underground view of [0196](0196-the-live-demo.md) (items 39 and the U key) and
takes over the first-toggle stall that [0205](0205-the-playtest-fix-pass.md) left to the revamp. The
design's other decisions (the graph model, swept geometry, the bore and room dimensions, the digging
skill) land with the phases that build them. Everything here is presentation: nothing writes into the
simulation, and MOVE-G01–G05 stay open.

## Decision

### 1. The U view is a camera cull mask over four render layers

`demo/demo_layers.gd` names the layers, and every drawn node sits on exactly one of them:

| Layer | Bit | What |
|---|---|---|
| 1 | `SURFACE` | the village: ground, buildings, trees, crops, water, weather, residents above ground |
| 2 | `SURFACE_MARKS` | labels and marks over the surface (bed labels, water labels, rings, plan ribbons, the ground tint) |
| 3 | `UNDERGROUND` | the cap and its backstop and light, troughs, rooms, frames, lanterns, finds, cellar shelves, residents below |
| 4 | `UNDERGROUND_MARKS` | what the U view draws over its cap: resident markers, rings, plan marks, chamber names and outlines |

- **A switch is one write:** `tunnel_view.gd set_on` sets `camera.cull_mask` to layers 1–2 or 3–4.
  Nothing is faded, hidden, built or re-materialed, so a toggle compiles no pipeline.
- **Every per-system fade hook is deleted:**
  - `tunnel_view` (veil, deep plane, village fade);
  - `demo_actor._apply_view` (a `find_children` and a `transparency` write per mesh);
  - `farm_bed_visual.set_faded` and `farm_view`'s per-frame poll;
  - `farm_stock_view`, `burrow_view`, `tunnel_marks` and `tunnel_find_props` view flags;
  - `demo_water` / `water_surface` (bank hidden, fade uniform);
  - `weather_view` (falls and veil hidden);
  - `tunnel_ground_view`'s strata plane;
  - `tunnel_overlay`'s surface fade and its view bit in the trough key.
- **A resident changes layer when it goes down or comes up** (`Layers.set_layers` over its meshes,
  skipping its marker): a layers write, never a material. Parts made later (a held good, a tool) take
  the layer it is on (`_adopt`).
- **A mark shown in both views is a pair of nodes**, one per marks layer: the selection and hover rings,
  the order markers, the route being laid (sharing one ribbon mesh), the selected tunnel's line, a
  planned chamber's outline and every chamber's name. The U view's copy lies on the level's floor and is
  drawn without a depth test, over the cap.
- **Lights are culled by their layers too** (probed: a layer-1 sun under a layer-3 camera makes no
  shadow draws and lights nothing). The sun stays on layer 1, so the U view has no sun and no sun
  shadow pass; its `light_cull_mask` and `shadow_caster_mask` are the surface's, so nothing below is lit
  by it or drawn into its shadow map (the surface's 107 shadow draws are the same with a dug tunnel and
  two rooms as without). The underground has its own directional fill light on layer 3
  (`light_cull_mask` layer 3, no shadows), and lantern lights are on layer 3.

### 2. The section cap

`demo/tunnel/underground_cap.gd` and `underground_cap.gdshader`: one 400 m plane at `CAP_Y_M` = −0.75 m
(the floor, −1.25 m, plus half a standard bore), on layer 3.

- **Read at the floor.** Each fragment reads its maps where the view ray meets the floor
  (`Layers.floor_through`; the shader does the same sum). So what the cap shows under the pointer is the
  floor point a click lands on, and a walker's feet are never under a near lip.
- **The strata:** the ground map (`tunnel_ground.gd`: loam, clay, sand, rock, wet), one texel a metre,
  read through a soft noise warp so patches wander rather than step.
- **The no-dig band:** the water's signed distance, stored unwarped. Bores are refused within half a
  bore of water (`tunnel_plan.gd` WATER), so the band is hatched blue from there, and the water itself is
  darker.
- **Footings:** the buildings' and well's circles, widened by the half bore a route keeps off them. They
  are stored as the union's signed distance, so the outline is smooth at 4 px a metre, and the inside is
  faintly stone.
- **Roots:** a root ball and seven bending roots under each mature tree, out to its root skirt
  (`forest_roots.reach_m`). The sunk root balls of 0205 are part of the tree model on layer 1 and never
  show.
- **Voids:** each dug step of a bore, and each done room, is stamped into an R8 mask at 8 px a metre
  (640 x 640 over the 80 m square, uploaded whole on each rebuild that stamped -- the design's 320 x 320
  R8G8 with rect updates is P1's to take up if a profile asks). A disc's rim is anti-aliased, so the 0.5
  threshold is the rim to a fraction of a pixel; at a dig face only the half behind the face is
  stamped, so no hole opens past the face wall. The cap is discarded over a void, with a dark cut band
  at its edge. Steps are stamped where the floor is within 0.25 m of the level's (so a walker on the
  lower end of a ramp still shows); the rest of a mouth's ramp rises through the cap.
- **The backstop:** a dark plane at −4 m, seen only in slivers past a trough's wall.
- **Built at boot:** the maps take ~0.17 s on the Mac (ground and water 124 ms, footings 43 ms, roots
  6 ms). A void stamp is ~11 µs a disc; the mask is uploaded once a rebuild.

### 3. The prewarm

`demo/tunnel/underground_prewarm.gd` is the registry. Everything the U view can draw registers as it is
built, as a mesh and the material it is drawn with, or a label's style:

- the cap, the backstop, the trough (a one-step sample in the bores' vertex format);
- the plan ribbon's materials and rings, and the selection lines;
- frames, lanterns and glows;
- room floors, beds and baskets;
- every find's model;
- the cellar's shelf, jars and every good a shelf can hold;
- the command layer's rings and markers, and the resident markers.

At boot, `demo_prewarm.gd add_frame_step` runs after the three warm frames of 0205:

- `tunnel_view.begin_prewarm` builds one sample of each (and an omni light) at the camera's focus, 2.25 m
  down, under the cap. There the depth test rejects every fragment, but every draw is issued. What a
  MultiMesh draws (frames, lanterns, glows) is sampled as a one-instance MultiMesh, since an instanced
  draw is its own pipeline.
- It sets the U view's mask for exactly `FRAMES` = 2 frames, under an opaque cover (a canvas layer in
  deep shade), so the player never sees the prewarm's frames.
- `end_prewarm` frees the samples and the cover and restores the mask.

The opening pause is released only after that. A test walks the dug village and requires every
material on layers 3–4 to be registered. It exempts only the residents' own bodies, which the surface's
opening frames draw with the same materials and passes.

### 4. Built when dug, never on a toggle

| What | Built when |
|---|---|
| Troughs | whenever their tunnel is dug, whatever the view |
| Rooms and their furniture | once their chamber is done, keyed per slot by generation and kind |
| Cellar shelves | put on layer 3 once, when their location becomes a cellar |
| Frames and lanterns | when braced or lit |
| Finds | when cut |

A test runs 20 U presses and requires that no room or trough is rebuilt. It also requires that no
node's transparency, material, visibility or layers changes, and that the node count holds.

### 5. Picking on the level's floor

- `tunnel_view.ground_at` picks on y = 0 in the surface view and on y = −1.25 in the U view. The tunnel
  tool, its extensions (chamber placement, tunnel selection, resume) and the command layer's move orders
  all pick through it.
- In the U view, a resident on the surface is picked at its marker.
- The farm's, the woods', the water's and the spoil heaps' click handlers and tools are not offered
  mouse presses in the U view. They are surface things the view does not draw (the design's "only
  layers 3 and 4 are pickable"). Releases, motion and keys still reach their tools, so a drag or an
  armed tool started before U can still end.

### 6. The interim look

Until P1's swept bores, a trough is a half-round channel from rim to rim, closed by a face wall where
the dig has reached:

- the shared material is lit, rough and double-sided (the near wall is seen from behind through the
  cap);
- its texture is a world-triplanar earth grain multiplied by vertex colours: a packed floor, darker
  walls, warmer when lit, water-blue when flooded, rubble in a fall.

It replaces the unshaded, alpha-blended, vertex-coloured ribbon. Room floors are lit and toned down to
earth and stone.

## Why

The first press of U stalled the Windows build (the playtest). On the Mac, with a tunnel and two rooms,
it took one 278 ms frame. The old view:

- pushed every village mesh, skinned resident and crop card into the transparent pass, whose
  alpha-blended pipelines had never been compiled;
- built the trough and the rooms' furniture on the toggle;
- sorted hundreds of transparent objects every frame after that.

A cull mask draws the same things through pipelines that already exist, and draws nothing that is not
needed.

Reading the cap at the floor makes one plane consistent with floor-plane picking. The alternative was a
cap at crown height, as the design's final look has it: without swept bores and walls that hides a
walker's body. P1 revisits it with the bores.

## Rejected

- **Hiding nodes with `visible`.** It still walks hundreds of nodes a toggle, and it would have to be
  kept in step by every system.
- **Drawing the prewarm in a SubViewport.** Its framebuffer format and effects need not match the main
  view's, so its pipelines might not be the ones the toggle needs.
- **A cap with no mask, below the floor.** The troughs lie on it like ribbons, which is the complaint.
- **Pairs for every surface mark.** Only marks the U view needs are paired. The flood water line, the
  fall's rubble ring and the mouth rings stay on the surface; the trough shows water and rubble in its
  own colours.

## Consequences

**Measured** on an Apple M5 Pro Mac (Metal, 1920×1080). Before each run the shader and pipeline caches
were moved aside. The scene was Brendan's playtest scene: a 12.6 m tunnel beside the farm beds, a burrow
home and a root cellar off it. The probe was `scratchpad/revamp_p0_agent/uprobe.gd`. "Before" is
cb3b4da; "after" is this decision's commit.

| | Before | After |
|---|---|---|
| First U toggle, worst frame | **278.1 ms** | **10.7 ms** (10.3–10.7 over four cold runs) |
| Pipeline compiles on the first toggle (surface / draw / specialization) | +1 / +5 / +12 | 0 / 0 / 0 |
| 20 toggles: stall banner, clock diagnostic pauses, worst frame, compiles | 0, 0, 12.5 ms, 0 | 0, 0, 9.8 ms, 0 |
| U view: objects / primitives / draw calls / shadow draw calls | 74 / 1,044,356 / 71 / 106 | 27 / 11,730 / 16 / 0 |
| Frame time with vsync requested off, surface → U view (median) | 8.32 → 11.27 ms | 8.33 → 8.31 ms |
| Click error at floor level (U view, real clicks on 3 floor points) | ~1.05 m (the ground plane; 1.25 m ÷ tan 50°, pinned by a test) | < 0.001 m |
| Boot: the U prewarm step (behind the opening pause, under its cover) | — | 11.5 ms (159–242 ms in earlier runs that drew a third frame and no cover) |

- Metal reports no GPU timestamps (`viewport_get_measured_render_time_gpu` returns 0 here), so the GPU
  is compared by frame time and draw counts.
- The old view cost ~3 ms a frame on this Mac. The new one runs at the display's 120 Hz floor, with a
  sixth of the draw calls and no sun shadow pass.
- The Windows machine cannot be measured from here.
- An independent review of the first commit found no CRITICAL issue. Its two HIGH findings -- the click
  paths and the switch test were not tested as they run -- are fixed: `tunnel_view.ground_along` and
  `demo_command.order_along` carry the plane choice and are tested in both views, and the 20-switch test
  compares after every press, recording every Node3D's visibility, every drawn node's layers, and each
  material's transparency, albedo alpha and shader parameters. Tests run before the scene tree is live,
  so a real camera ray is measured by the probe, not the suite.
- Mutation-tested: 74 mutants of the new logic, one at a time, each restored and hash-checked. Every one
  is killed; one equivalent mutant (a redundant dedupe check in the label registry) was removed by
  deleting the check.

**Open:**
- The underground environment swap (low cool-brown ambient, SSAO, glow) is P1's. The U view still uses
  the sky ambient and the world's fog.
- In the surface view a resident below is not drawn. The design's faint dotted marker over the tunnel
  is not built.
- The ~0.3 s crossfade transition is not built.
- The pick plane is level 1's. P6 adds a floor per level.
- A route may still be laid across a room or a crop bed. The room refusals are P3's.
- The cap is 80 m square. Outside it the edge texels continue.

**For P1:**
- Build the swept bores on layer 3 and register their materials with `view.prewarm` when they are
  built.
- Stamp their voids with `cap.stamp_disc` as they are dug; the mask's resolution and anti-aliasing are
  there.
- The cap reads everything at the floor. Bore walls that rise to the crown need the design's parallax
  discard (already how the void is tested) and probably a higher cap.
- Frames' heights follow the trough's depth (`tunnel_marks._bore_transform`).
- The stoop must play its clip at `resident_brain.gd stride_rate()` (0205).

## Source

- The design and its §10 rulings.
- The playtest record, 0196 and 0205.
- The probe logs and frames in `scratchpad/revamp_p0_check/before` and `after`.
