# Underground revamp: tunnels, underground view, burrow homes and root cellars

**Status: approved.** Brendan's rulings of 2026-09-29 are in §10; the 309 approved Meshy credits were spent on the §7 props and clips (decision [0204](../decisions/0204-the-underground-pass-clips-and-props.md), branch `docs/underground-asset-provenance`), and P7 swaps them in. Phases land as their own decisions (P0: [0206](../decisions/0206-the-underground-view-is-a-layer-cutaway.md)). Written before any code changed; grounded in `feat/live-demo` at 75acff2 (`godot/demo/tunnel/`, `burrow/`, `cast/`, `farm/`, `events/`), SET-MOVE-001, SET-MOVE-ECON-001 (decision 0107; the 0092 file named in the brief is a different decision), DEC-029/031/040/041, GDD §5.8–5.9 and the setting bible §14.

---

## 1. What's wrong today

**The data model is 8 separate straight-line tunnels, not a network.**
- `tunnel_network.gd` stores up to 8 slots. Each is a polyline of at most 8 points, always with exactly one entrance and one exit.
- There are no junctions and no branching. Tunnels only "chain" through surface walks between their mouths (`tunnel_router.gd`).
- Chambers are bolted on. `burrow_chambers.gd` puts a 3×3 m room centred 2 m (`OFFSET_U`) off a point on one tunnel. The room's edge just touches the bore wall: there is no doorway and no passage.
- Chambers are only reachable as a sub-verb of a selected tunnel ("Burrow home / Root cellar" in the tunnel panel).
- Nobody ever goes into a chamber:
  - Beds are only a panel count (`BEDS_PER_HOME = 2`).
  - Cellar deliveries go to the nearer **surface tunnel mouth** (`farm_cellars.door_of`).
- `refusal()` checks buildings, other chambers, mouths and routes. It does **not** check water or crop beds, so rooms can end up under the farm. That is the overlap in the screenshot.

**The yellow ribbon.** The underground-view tunnel is built by `tunnel_overlay._build_bore`:
- It is a 0.5 m-deep open half-pipe with an unshaded, alpha-blended, double-sided material, coloured only by vertex colour. The colour runs from `BORE_DEEP` to `Palette.EMBER`, and a lit tunnel uses `LIT_RIM` (1.0, 0.86, 0.5).
- No texture, no lighting, no walls, no roof.
- Around it: a 50%-black veil at y=0, a ground-type plane at −1.9 m (`tunnel_ground_view`) and a flat brown plane at −4 m.
- From the 50° camera this reads as a bright flat ribbon.

**The burrow slab.** `burrow_view._build_room`:
- The home floor is an unshaded 3×3×0.08 `BoxMesh` in `HOME_FLOOR` orange, with two beds and a basket. The cellar is a blue slab. No walls or light.
- On the surface, a home is the generic heap dome with a cylinder "door".
- Every view toggle frees the furniture nodes and makes them again.

**Surface bleeding through.**
- `tunnel_view._fade_world` does not hide the village. It sets `GeometryInstance3D.transparency = 0.82` on every mesh.
- Farm bed labels are `Label3D` with `no_depth_test = true` (`farm_bed_visual.gd:197`), so they draw over everything.
- At least six systems each run their own fade hook: `demo_actor._apply_view`, `farm_bed_visual.set_faded`, `farm_view`, `demo_water.set_underground_view`, `farm_stock_view` and `burrow_view`.

**Clicks land about 1 m off in the underground view.** `tunnel_ext._ground_at` and `demo_pick` intersect y=0, but bores sit at −1.25 m. At 50° pitch that puts clicks about 1.05 m off, which matters most when placing chambers.

**Likely causes of the "U freezes the game" stall** (ranked; confirm with a verbose run that logs pipeline compiles):
1. The first toggle pushes hundreds of opaque materials into the transparent pass. This covers every Village mesh, every actor's skinned meshes and every farm bed's `crop_card` shader. The imported materials, the crop-card shader and the skinned meshes have alpha-blended variants that were never compiled, so they all compile on that first frame. The first toggle also runs `find_children` over the whole village.
2. `burrow_view` and `farm_stock_view` create prop instances (bed, basket, shelf, jars) at toggle time, and these materials are drawn for the first time.
3. The veil, strata and trough materials and the first lantern `OmniLight3D`s are also drawn for the first time.
4. The demo clock's stall rule turns the hitch into a freeze: a frame that puts the clock 0.25 s behind raises the CRITICAL pause and its Resume banner.

After the first toggle there is still an ongoing cost: sorting hundreds of transparent objects every frame.

**"The mouse slides and doesn't crouch"** (probable causes; needs a repro):
- There is no posture at all. `STOOP_PERMILLE` is only a fit test, and there is no stoop pose or clip.
- The entry ramp drops 1.25 m over 1.5 m (`floor_y_m`, about 40°). Speed and clip rate are measured per metre of flat XZ distance and the body stays upright, so the feet skate on the slope.
- In the underground view, the trough's near rim plus the veil hide the legs at 50°, so you see a torso gliding.
- When passing (`_side_m`), the body slides sideways with no stepping.

**Rules problems.**
- Only moles dig. DEC-041 already flags this as a species lock against LORE-P12.
- One tunnel is one job, routes are straight legs only, and there are no curves.

---

## 2. Vision and player experience

*A mole-built warren you look down into like a cut-open storybook diorama: dark, root-laced earth, warm lantern pools, and homes that clearly belong to the tunnels.*

**Planning.**
- Press **B** (the Dig/Build tool) and the surface peels away over about 0.3 s.
- You are looking at a section cut through the earth at knee-to-crown height:
  - dark humus over loam, with clay bands and sandy lenses;
  - roots reaching down under every tree;
  - stones in the walls;
  - a blue hatched no-dig zone along the stream;
  - stone footing outlines where buildings stand.
- Existing tunnels are lit voids with residents walking in them.
- You drag a tunnel. It curves smoothly and snaps into the side of an existing bore, where a junction ring appears.
- A readout at the cursor says, for example: *"14 m · 14 quanta · 5.2 h (crew of 3) · 28 U spoil · clay 4 m (slow), sand 2 m (weak: brace)"*.

**Digging.**
- The Foremole's hand lantern lights the face. The face is a rough concave cut of darker, damp soil, and clods burst off it with each quantum.
- Behind the face a helper fills a basket and carries it out stooped. The heap at the mouth grows when the load is dumped.
- Fresh walls stay dark and damp, then dry to a paler colour over a game day.
- Brace frames go up one by one, each with a small dust puff. Lanterns are hung and each light pool blooms on.

**Walking.**
- Moles walk upright in mole-sized bores. Mice stoop slightly, squirrels stoop more, and otters and the badger need a widened bore.
- Inside a home everyone straightens up. The cut-through view shows it at a glance: tunnels are cramped, rooms are generous.

**Living.**
- At dusk residents go down a round front door in a turfed bank, or come in from the tunnel side.
- Inside: hearth glow, a rug, a table (`chair_sit_idle` exists), beds in wall alcoves.
- Smoke rises from the mound's chimney pot on the surface.
- The root cellar is cool grey-blue, stone-lined, with racks and jars that visibly fill as harvests come in.
- On the surface the warren shows itself: mouth arches with a lantern, air vents, turf seams over young tunnels, the cellar hatch, chimney smoke.

**Principles.**
- One art language from the placed burrow through the tunnels to the rooms (bible §14).
- Hazards show in the geometry before they strike (DEC-040 "warned").
- Everything reads at RTS distance.

---

## 3. Spatial model

The underground becomes **one packed graph**: `underground_graph.gd` replaces `tunnel_network.gd`. It keeps the integer u lattice, (slot, generation) references and the prefix-sum dig timelines.

| Table | Key columns | Demo cap |
|---|---|---|
| **Nodes** | kind (MOUTH, JUNCTION, BEND, SOCKET, RAMP_END); x, z (u); level; generation | 96 |
| **Segments** | node_a, node_b; up to 6 interior control points (curve); level; bore class; phase per quantum-range (planned / digging / open); braced, lit, closed + closed range; wet/strain pressure; length_u, cost_u; timeline offsets | 96 |
| **Rooms** | template id; level; centre (u); rotation (quarter turns); phase; socket node ids (up to 3); fixtures (packed: type, cell, rotation, fill); entrance mouth node | 16 |
| **Mouths** | node id; surface kind (TUNNEL_RAMP, HOME_DOOR, CELLAR_HATCH); heap spot; queue | 16 |

**Levels.**
- Level 1 has its floor at −1.25 m, as today.
- Level 2 (phase 6) would use DEC-040's *candidate* 4 m spacing, so a floor at −5.25 m, labelled as a demo value.
- `level` is a real field from day one, as MOVE-REQ-013 requires: same X/Z, different place.

**Geometry (demo values; the paid lattice stays ECON-001's 1 m cube).**

| Space | Paid size | Drawn / fit |
|---|---|---|
| Standard bore | 1×1 quantum | Drawn horseshoe: 1.0 m floor, walls bowing to 1.1 m, crown 1.0 m. Body must clear crown − 0.1 m: moles upright, mice and squirrels stoop. |
| Wide bore | 2×3 quanta | Otters upright, badger stoops |
| Rooms | 2 quanta high | Everyone except the badger stands |

Room templates:

| Template | Shape | Floor quanta | Total quanta | Sockets / entrance |
|---|---|---:|---:|---|
| Burrow home | Round, 4 m diameter | 12 | 24 | 3 sockets; own front door |
| Root cellar | 3×4 m barrel vault | 12 | 24 | 2 sockets plus hatch steps |
| Later | Large home (two lobes), pantry, workshop | — | — | — |

A room with its floor at −1.25 m and a 2 m ceiling rises 0.75 m above grade. **That is the turfed mound**, so the surface mound *is* the room, not a decoration. This matches the bible's "exposed entrance facade and legible interior access". The library `cellar` model (stone door in a turfed mound) already fits the cellar.

**Connection rules** (demo values, named in `tunnel_rules.gd`; each refusal gives text and colour, per MOVE-REQ-018):
1. **Snap-to-junction.** A segment may end on an open or planned segment's interior if:
   - the point is ≥ 1.5 m from any existing node on it; and
   - the meeting angle is ≥ 40°.

   That creates a JUNCTION node and splits the host segment. Its job, hazard and quantum ranges split by the along-distance.
2. **Pillar rule.** Voids that are not connected keep ≥ 1 m of solid earth between them in plan. Breaking this is refused as *"would break into Tunnel 3: join it instead"*, with the snap offered.
3. **Crossing.** A crossing at ≥ 40° becomes a 4-way junction. A shallower crossing is refused.
4. **Curves.** Segments run 2–32 m, with a centreline bend radius ≥ 1 m.
5. **Rooms:**
   - footprint plus a 1 m pillar clear of other voids;
   - not under buildings, the well, crop beds or water (water uses the same `crosses_water` adapter with half-bore clearance; this fixes today's gap);
   - a passage leaves a socket straight for ≥ 1 m.
6. **Mouths:**
   - today's clearances (obstacles, work spots, other mouths); plus
   - a clear 3 m × 1.4 m ramp footprint;
   - ramp grade ≤ 1:2.5, down from today's ~40°.
7. **Levels.** Only RAMP segments (≤ 1:2.5) or stairs join levels.

**Surface entrances** are all MOUTH nodes in one router:
- **Tunnel ramp:** timber-and-fieldstone arch, lantern.
- **Home front door:** round door in the mound.
- **Cellar hatch:** the library cellar model.

**Routing.**
- Per graph revision, run Dijkstra (h=0, the MOVE §4 reference) from each mouth and room socket over the underground graph. Do this per fit class: standard or wide, loaded or not.
- That gives a cached mouth-to-mouth / mouth-to-room cost table: 16 sources × 96 nodes, trivial.
- The existing lazy-surface search in `tunnel_router.gd` keeps its shape. Its "tunnel edge" becomes that table's cost, and a goal inside a room attaches to the room's socket.
- The brain's TUNNEL state walks a **leg list**, `(segment, from_m, to_m)…`, instead of one slot.

**Mapping from the current model.**

| Today | Becomes |
|---|---|
| Tunnel slot | 1..n segments plus two MOUTH nodes |
| `chambers.tunnel` / `along_u` | Room sockets joined by passage segments |
| `cellars()` | Rooms of the cellar template (same dictionary shape) |

---

## 4. Building experience

**Tools.** The Dig panel opens with **B** and replaces T and the panel's chamber buttons. Planning always happens in the underground view and returns to the previous view on exit.

| Tool | What it does |
|---|---|
| Tunnel | Click-drag with live curve smoothing. Starts at a new mouth or snaps onto a bore or junction; Shift adds a waypoint. |
| Burrow home / Root cellar | Separate tools, not tunnel verbs. The ghost room follows the cursor and R rotates it. Shows sockets, the pillar halo, the surface entrance footprint, and an automatic passage preview to the nearest valid bore within 6 m, which can be dragged. Rooms can be placed standalone with only their own door and connected later. |
| Entrance | Adds a ramp mouth to an existing bore |
| Ramp / Stairs | Phase 6 |

**Ghost preview.**
- Chalk-cream dashed volume in the section when valid, clay when refused, with the reason next to the cursor.
- Snap targets glow brass.
- Ground types come from the ground map (tunnel_ground grid) along the ghost.
- Cost readout: quanta, time at the assigned crew's rate, spoil U, brace cost (wood 250 + stone 250 milli-U a quantum, ECON-002) if "brace as dug" is ticked.
- Confirming queues the work as blueprints. Multiple queued pieces form a job list; the one-job-per-tunnel limit goes.

**Who digs.**
- A **digging skill** replaces the mole-only rule (DEC-041 follow-up, LORE-P12). Moles start at skill 3, like the forestry skills.
- Rock needs a *rock breaker*: anyone with the skill and a heavy tool. The badger quarryman starts with it.
- Crews stay as today: ≤ 4 builders, one worker per face (ECON-002).

**Staged construction visuals.**

| Stage | What you see |
|---|---|
| Blueprint | Chalk outline and string pegs |
| Face | Concave rough cap mesh; fresh-soil tint; clod particles each quantum; Foremole's hand lantern (small omni light); pick-swing clip |
| Behind the face | Basket or wheelbarrow filling. A helper hauls it and the heap grows on dump; the ledger still posts at the cut, as in `spoil_into`. With no helper the Foremole hauls every 4 U itself, which is a real reason to bring a crew. |
| Finish | Floor tamps from loose to packed; walls dry over ~1 game day (vertex age channel) |
| Upgrades | Frames placed per metre and lanterns hung one at a time, each with an install pop. Widening shows the bore growing. |

**Fit-out as a player activity.** A dug room is *Bare*. Selecting it opens a fixture palette on a 0.5 m in-room grid, plus a "Suggested layout" button.

| Fixture | GDD row | Demo cost (demo stores: wood, planks, stone) | Effect |
|---|---|---|---|
| Bed | wood 2, cloth 1, 20 WU | 2 planks, 20 WU | One resident sleeps here |
| Hearth | stone 6, 60 WU | stone 6 | Heat; comfort target (dormitory 6000, private 8000); chimney smoke |
| Shelf / rack | wood 2, 16 WU, 50000 g | 2 planks | Cellar capacity |
| Decoration (rug, lantern, hanging herbs) | wood 1, wax 0.25 | 1 wood | Comfort +250, cap 1000 |
| Table and stools | seat wood 1 | 2 planks | Residents sit (`chair_sit_idle`) |

**What the fixtures do.**
- **Homes.** Beds give residents a real home bed. At night they route home through the graph and sleep (phase 4). The panel shows comfort and warmth, and the HUD's Beds stays the simulation's.
- **Cellars:**
  - Capacity is the sum of the racks and jars, replacing the flat `CELLAR_CAPACITY_U = 60`.
  - The cellar is "cool" (spoilage 350 per mille, cited) only while it has at least one rack and no hearth within 3 m or in a room it opens onto.
  - Carriers walk **into** the cellar and shelve. `farm_stock_view` shelves stand on the placed racks.

---

## 5. The underground view

**Hide by render layer, not transparency.** A `DemoLayers` service assigns render layers:

| Layer | Contents |
|---|---|
| 1 | Surface |
| 2 | Surface labels and overlays |
| 3 | Underground |
| 4 | Underground markers |

The underground view sets the camera's `cull_mask` to 3 and 4 and swaps the WorldEnvironment. Switching is **instant, allocates nothing and compiles nothing**. It replaces every fade hook listed in §1, and farm labels, crops, trees and water disappear completely. Surface residents show as small cream markers on the section, so the player still knows who is up top.

**The section cap.**
- One plane at the active level's crown height (−0.15 m for level 1), drawn with an earth shader.
- It reads an **excavation mask**: an R8G8 texture at 8 px/m over the village (320×320, ~200 KB). Red holds voids per level; green holds blueprints.
- Mask updates are small rect blits as quanta open, a few per second.
- **Parallax discard.** Each cap fragment projects its view ray down to the level's floor and discards if that point is void. The whole floor of every void shows through a slanted window, and the near-side lip no longer hides feet.
- Void edges get a dark 8 cm cut band, which reads as solid earth cut through.
- Stratified earth by world Y, with the ground-type map tinting clay, sand and rock pockets exactly where they slow or weaken digging.
- Root tangles under trees, taken from the forestry rows.
- Water as a blue hatched no-dig zone; building footprints as stone footings.

**Walls.**
- Bore and room shells are **inward-facing** meshes with normal back-face culling. The near wall and the roof cull themselves; the floor and the far wall render.
- Room walls are cut at crown height ("walls down").
- Braces and lanterns use a small cutaway shader (discard above the crown) so beams do not hide residents.

**Lighting.**
- The DirectionalLight's `light_cull_mask` excludes layer 3 permanently: the underground is never sunlit.
- The underground environment has low cool-brown ambient, glow on for lantern bloom, and SSAO if the budget allows.
- Lanterns are `OmniLight3D`s: range 3.5 m, shadowless, flickering ±8% on the demo clock, holding still while paused. Budget: ≤ 32 visible.
- Unlit bores get a 0.04 emission floor so they read as dark earth, not black.
- The hearth is a warm omni light plus embers.

**Camera and picking.**
- The rig's focus moves to the level's floor height.
- Picking intersects the active level's floor plane (fixes the ~1 m error), and only layers 3 and 4 are pickable (MOVE-TEST-06).
- In the surface view, residents underground show as a faint dotted marker moving over the tunnel.

**Transition.** About 0.3 s:
- Capture the last frame into a full-screen overlay and crossfade it out while the cap slides from y=0 down to the crown.
- No material ever changes.

**Prewarm.**
- At boot, behind the opening inspection pause, render the underground view for 2 frames with one hidden instance of every underground material, prop and light setup, then switch back.
- A registry, `underground_prewarm.gd`, lists every material; a test asserts that every underground material is in it.
- Rooms and fixtures are built when they are dug or placed, never on a view toggle.

---

## 6. Tunnel geometry and art

**Recommendation: swept profiles plus procedural junction hubs plus procedural room shells. Not SDF / marching cubes.**
- **Bores.** A 16-vertex horseshoe profile is swept along a centripetal Catmull-Rom centreline at 4 rings/m. A seeded per-ring displacement (±4 cm) gives the hand-dug look. The floor gets its own packed-earth strip with a worn footpath.
  - Vertex colours carry wetness, fresh-cut age and hazard masks.
  - One mesh per segment. Only the dug segment is rebuilt, when the face crosses a 0.25 m step (as today).
- **Junctions.** A squashed-dome hub (radius 1.2× the bore) with segment ends trimmed back inside it, and a brace frame at each opening to hide the seams.
- **Rooms.** A lathe profile for the round home, an extruded barrel vault for the cellar with a stone-lined lower wall via a vertex mask. Socket openings are left out of the wall, framed by the arch or door prop, and the passage tube ends inside the frame.

**Materials.**
- One **world-space triplanar earth shader** shared by the cap, walls and floors, so they match seamlessly. It carries strata by Y, the ground-type tint, wetness (darker, lower roughness) and a stone Voronoi.
- Root decals and hanging roots under trees: procedural tube meshes plus alpha cards.
- Embedded stones: library `rock_cluster` and `mossy_boulder` at 0.2–0.5 scale as MultiMesh.

**Cost.**

| | Swept approach (recommended) | Marching cubes |
|---|---|---|
| Size | 200 m of bores ≈ 13k vertices / 25k triangles; 16 rooms ≈ 10k triangles | Village volume at 0.125 m voxels ≈ 2.5M cells |
| Build time | ≈ 1 ms to rebuild one segment in GDScript; ≈ 5 ms for the whole network | Seconds in GDScript; would need a native GDExtension toolchain for Mac and Windows |
| Draw calls | < 60 | — |
| Look | Controlled profiles, clean UVs | Blobby surfaces, stretched textures, remeshing on every edit |

DEC-029 says free excavation "does not prescribe voxels". Revisit only for production's free excavation.

**Hazards made visible.**

| Hazard | Warning signs | When it strikes |
|---|---|---|
| Seep | Wet darkening creeps along the walls, drips, a puddle grows with pressure | Flood: translucent water in the segment |
| Strain | Sand trickles from the crown, crack decal | Collapse: rubble plug (`tunnel_rubble`) |

The existing clay rings stay as map cues.

**How residents move.**
- **Stoop.** A procedural `SkeletonModifier3D` runs after the AnimationPlayer. It bends Spine, Spine01, Spine02 and the neck of Meshy's 24-joint rig and drops the hips. The amount comes from the bore's crown versus body height, eased in over 0.3 s. It is free, works for every creature, and the tail rig follows.
- **Ramps.** Speed and clip rate are measured along the 3D path. The body pitches with half the slope, and the grade limit is 1:2.5.
- **Carrying.** The carry clip plus the held model (`farm_carry_view`), with the load held lower while stooped.
- **In rooms.** `chair_sit_idle` at tables; a sleep clip in beds (phase 4).

---

## 7. Asset plan

**Free / procedural (Godot):**
- bore, hub and room shells; cap and earth shaders; roots; floor paths;
- particles: clods, dust, drips, sand;
- flood water; timber ramp risers and stairs; rug decal.

**Free textures:**
- Poly Haven CC0 earth, clay, sandstone and forest-ground PBR sets, fetched through the Blender MCP (no credits).
- `tools/demo_texture_imports.py` needs a rule for loose textures, because today it reads roles from GLB materials only.

**Reused from the library:**
- `tunnel_brace` (also as ring beams in rooms), `tunnel_rubble`, `wall_lantern`, `bed`, `basket`, `clay_jars`, `pantry_shelf`, `hearth`, `table_stools`, `barrel`, `crate`, `sack_pile`, `wheelbarrow`, `cellar`, `mole_pick`, the finds and relics, `rock_cluster`, `mossy_boulder`.
- Clips: `chair_sit_idle`, `carry_heavy_object_walk`, `pull_radish`.

**New Meshy props.** Not generated; recipe = nano-banana-2 concept 6 + meshy-7 textured image-to-3D 30 = **36 each**:

| # | Prop | Credits |
|---|---|---:|
| 1 | Round burrow door with frame | 36 |
| 2 | Tunnel mouth arch (timber lintel, fieldstone jambs) | 36 |
| 3 | Hand candle lantern (diggers) | 36 |
| 4 | Hanging stores (onion and garlic strings, herb bundles) | 36 |
| 5 | Slatted root bin | 36 |
| 6 | Clay chimney pot | 36 |
| — | Core subtotal | **216** |
| 7 | Rag rug (optional; the decal comes first) | 36 |

**New clips.** `meshy_animate`, 3 credits each, on the existing rigs. First confirm each action exists in Meshy's library.

| Clip | Creatures | Credits |
|---|---|---:|
| Sleep / lie | 8 cast creatures | 24 |
| Pick-swing dig | mole_digger, mole_mason, badger_quarryman | 9 |
| Crouch-walk (optional; the procedural stoop is first) | 8 | 24 |

**Total: 249 core (props 216 plus sleep and dig clips 33), or 309 with every option, out of about 1,522 credits.**

**Blender work (free):**
- L0s of the new props through `make_demo_props.py`.
- New clips through `ground_meshy_clips.py`: the lift/pin steps of decisions 0193, 0201 and 0202.
- Optional root-card atlas.

---

## 8. Phased implementation

Effort is in agent sessions (one build session plus review).

**P0 — Cutaway foundation and stall fix** (1–2 sessions)
- **Scope:**
  - `DemoLayers` and the cull-mask toggle;
  - delete all transparency fades;
  - cap plane with strata, water and footprint marks;
  - prewarm registry;
  - rooms built at dig time;
  - picking on the level floor;
  - surface-resident markers;
  - an interim textured, lit version of the old trough.
- **Acceptance:**
  - From a cold boot, the first U toggle has no frame over 50 ms on the Mac.
  - The stall banner never fires across 20 toggles.
  - No surface label, crop or building is visible in the underground view.
  - Click error ≤ 0.1 m at floor level.
- **Tests:**
  - every surface node's layers are correct;
  - no `transparency` is written anywhere after a toggle;
  - the prewarm registry covers every underground material;
  - pick-plane maths.
- **Perf:** a GPU *saving* in the underground view, because transparent sorting goes.

**P1 — Bore look and traversal** (3 sessions)
- **Scope:**
  - swept horseshoe mesh, triplanar earth shader, roots and stones;
  - lanterns as lit omni lights with flicker;
  - braces with the cutaway shader;
  - mouth ramps with arches at 1:2.5;
  - stoop modifier and 3D-length clip speed;
  - underground environment.
- **Acceptance:**
  - Brendan's screenshot scene looks like a lit, earthy tunnel, not a ribbon.
  - Mice and squirrels visibly stoop; moles stay upright.
  - No foot skate on ramps: measured foot drift under 2 cm per contact, as in 0202's audit.
- **Tests:** profile vertex counts; stoop amount per species; ramp grade refusal; build time of a 32 m segment under 2 ms (headless).
- **Perf:** ≤ +1.5 ms GPU in the underground view; ≤ 0.2 ms/frame CPU.

**P2 — The network graph** (4 sessions)
- **Scope:**
  - `underground_graph.gd` (nodes, segments, junctions, curves);
  - snapping, the pillar rule, crossings;
  - router: Dijkstra mouth tables plus the lazy surface search;
  - brain leg lists;
  - digging skill instead of the species lock;
  - job list;
  - migrate hazards, jobs, crews, finds, queue, heaps, evacuation and drainage/irrigation to segments and mouths.
- **Acceptance:**
  - A T-junction branch dug from a live tunnel is walked by residents.
  - Existing demo behaviours all still work.
  - A MOVE-TEST-09-style fixture matches the Dijkstra reference.
- **Tests:** port `test_demo_tunnel*.gd` (4,732 lines). Rules tests are kept verbatim; network and router tests are rewritten against the graph.

**P3 — Rooms as their own structures** (3–4 sessions)
- **Scope:**
  - room templates (home, cellar) with sockets;
  - Room tools with ghost, rotation and auto-passage;
  - their own surface entrance (door or hatch) with mound or hatch;
  - staged room dig at 24 quanta and 3 faces;
  - water and crop-bed refusals;
  - the cellar API served from rooms (same `root_cellar:<slot>:<gen>` id, position at the hatch).
- **Acceptance:**
  - A home and a cellar built standalone, then connected by a passage.
  - Nothing overlaps farm beds.
  - The pantry still stores to cellars.
- **Tests:** template → quanta counts; socket snapping; refusal reasons; the provider dictionary shape is unchanged.

**P4 — Fit-out and living** (3–4 sessions; needs the sleep clip)
- **Scope:**
  - fixture palette and grid, costs from the demo stores;
  - suggested layouts;
  - bed assignment and a night routine home;
  - comfort readout;
  - cellar capacity from racks and the "cool" rule;
  - carriers walk into the cellar and shelve;
  - chimney smoke.
- **Acceptance:**
  - At dusk, residents walk underground to their own beds.
  - Cellar jars fill in place.
- **Tests:** capacity sums; cool-rule edges; bed allocation ties (REQ-SET-132 order).

**P5 — Construction theatre and hazard visuals** (2–3 sessions)
- **Scope:**
  - face mesh and clods; drying walls;
  - basket hauling to the heap;
  - install animations;
  - seep and strain visuals;
  - surface seams and vents.
- **Perf:** ≤ 200 particles live.

**P6 — Second level** (3–4 sessions)
- **Scope:** ramp/stair segments, level switching (PgUp/PgDn in the underground view), per-level cap and mask channels, the other level as a faint outline.
- **Acceptance:** MOVE-TEST-01-style: a placed home, a tunnel and a level-2 room joined by one route.

**P7 — Asset upgrades** (1–2 sessions plus credits, in parallel after approval)
- Swap the new props and clips in; boxes and the procedural stoop remain as fallbacks.
- **Done:** decision [0371](../decisions/0371-the-generated-underground-props-and-clips-swapped-in.md) (no credits spent;
  the defects fixed in Blender or code; review F16 and F17 closed).

**Kept or rewritten.**

| Status | Files |
|---|---|
| **Kept** | `tunnel_rules` (constants, fit, spoil; route checks generalised to segments), `tunnel_ground`, `tunnel_finds`, `tunnel_crew`, `tunnel_stores`, `tunnel_queue`, `tunnel_heaps`, `village_water`, `demo_events` / `evacuate_task` (re-pointed), `farm_cellars` (same API) |
| **Re-keyed** | `tunnel_hazards` and `tunnel_jobs` (per segment or room) |
| **Rewritten** | `tunnel_network` → `underground_graph`; `tunnel_router`; `tunnel_plan` / `tunnel_control` / `tunnel_actions` (new tools); the underground half of `tunnel_overlay`; `tunnel_view`; `tunnel_ground_view` (into the cap shader); the underground half of `tunnel_marks`; `burrow_chambers` → `underground_rooms`; `burrow_view` → room kits; the brain's TUNNEL state |
| **Deleted** | Every per-system underground fade hook |

**Records.** Write a new decision covering:
- the layer-based cutaway;
- the graph model;
- swept geometry rather than voxels;
- the demo bore and room dimensions;
- the digging skill.

Also update `godot/demo/README.md`. All of this remains presentation-only; MOVE-G01–G05 stay open.

---

## 9. Open questions for Brendan

1. **Cutaway style.** Approve the top-down section of the active level: walls cut at crown height, floors, far walls and lit rooms visible. The alternative is a side-on vertical slice view.
2. **Burrow home access.** Should each home have its own front door in a turfed mound *and* a tunnel connection (recommended), or be tunnel-only?
3. **Second level.** Build it in the demo now (P6) at the *candidate* 4 m spacing, or defer it?
4. **Sleeping at home.** Should residents go home to their burrow beds at night? This needs a night routine and a sleep clip.
5. **Meshy spend.** Approve about 249 credits (6 props plus sleep and dig clips), up to 309 with every option, out of about 1,522? Or go procedural-only first?

Working assumptions that don't need a call unless you object:
- Furniture is priced in demo wood, planks and stone, because the demo has no cloth or wax.
- Digging becomes a skill that moles start with (DEC-041 follow-up).

### Critical Files for Implementation
- godot/demo/tunnel/tunnel_network.gd (becomes underground_graph)
- godot/demo/tunnel/tunnel_view.gd and tunnel_overlay.gd (cutaway, bore meshes, stall fix)
- godot/demo/burrow/burrow_chambers.gd and burrow_view.gd (rooms, templates, fit-out)
- godot/demo/cast/resident_brain.gd and demo_actor.gd (leg-list travel, stoop, remove transparency fade)
- godot/demo/tunnel/tunnel_router.gd and tunnel_rules.gd (Dijkstra mouth tables, connection rules, demo dimensions)

---

## 10. Brendan's rulings (2026-09-29)

1. **Cutaway:** top-down section of the active level (approved as recommended).
2. **Home access:** each home has its own front door in a turfed mound *and* a tunnel connection.
3. **Scope now:** residents sleep at home at night (P4 night routine plus sleep clip) **and** the second level (P6) at the candidate 4 m spacing, both in the demo now.
4. **Meshy spend:** 309 credits approved (everything): the 7 props, including the rag rug, plus the sleep, pick-swing dig and crouch-walk clips.
5. Working assumptions stand: furniture is priced in demo wood, planks and stone; digging is a skill moles start with.
