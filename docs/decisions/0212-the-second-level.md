# 0212 — The second level: links down, ground at depth, a view a level at a time
Date: 2026-09-30 · Status: Accepted

Phase P6 ("Second level") of the approved underground revamp
([`docs/design/underground_revamp.md`](../design/underground_revamp.md) §3 "Levels" and rule 7, §5 "The underground
view", §8 P6; Brendan's ruling in §10: **"Second level: build it in the demo now at the candidate 4 m spacing."**).
It builds on [0206](0206-the-underground-view-is-a-layer-cutaway.md) (the layer cutaway), [0207](0207-swept-bores-lantern-light-and-the-stoop.md)
(swept bores, ramps walked along their slope, the stoop), [0208](0208-the-tunnels-are-one-network-graph.md) (the
graph, with `level` a column from day one and level 2 named but not dug), [0209](0209-burrow-homes-and-root-cellars-are-rooms.md)
(rooms carry a level), [0210](0210-fit-out-and-living.md) (the night, the cool rule) and
[0211](0211-construction-theatre-and-hazard-visuals.md) (per-segment theatre; surface signs the top level's; a
village-wide particle budget). Everything here is presentation: the demo cast's walks and the pantry demo's stores,
nothing the simulation owns. **MOVE-G01–G05 stay open.**

New files: `godot/demo/tunnel/stair_view.gd` (the stairs' treads), `godot/test/test_demo_levels.gd` and
`godot/test/test_demo_levels_edges.gd`.

## Decision

### 1. The spacing is a named CANDIDATE, not a settled value

`tunnel_rules.gd`: `LEVEL_SPACING_U` = 4096 (4 m), so level 2's floor is `LEVEL_2_FLOOR_DEPTH_U` = 1280 + 4096 =
5376 u (5.25 m down). It is DEC-040's *candidate* four-levels-at-4 m spacing, which SET-MOVE-001 says "remain[s] a
candidate pending G02 representation and memory review" and SET-MOVE-ECON-001 does not adopt. The demo carries it as a
demo value so the second level can be built now, as ruled; nothing here settles depth, the number of levels or their
spacing for production (MOVE-G01 owns finite spatial/depth extents, G02 the representation). `TOP_LEVEL` (level 1, the
one mouths open onto) and `DEEPEST_LEVEL` (2) bound `is_buildable_level`; only two levels exist in the demo.

With 4 m between floors the voids of the two levels never come within a pillar (1 m) of each other: a level-1 bore
(floor 1.28 m, crown 1.0 m) and a level-2 bore are 3 m apart in height; a level-1 room (crown 1.5 m above the ground) and
a level-2 room (crown 2.75 m over its floor, so 2.5 m down) 1.25 m apart.

### 2. Links: ramps and stairs, the only way between levels

A **link** is a segment of kind `SEG_LINK` (graph column `seg_link`: `LINK_RAMP` or `LINK_STAIRS`), straight, from its
**head** (node A) on level 1's network down `LEVEL_SPACING_U` to its **foot** (node B) on level 2's (design §3 rule 7).
Its `seg_level` is its head's. Demo values (`tunnel_rules.gd` LINKS):

| | Ramp | Stairs |
|---|---|---|
| Profile | 1:2.5 at the steepest (the mouths' grade), eased over `RAMP_FILLET_U` at both ends, one grade for the run laid | 16 risers of 0.25 m (`STAIR_RISE_U`), treads of `STAIR_MIN_TREAD_U` 0.3125 m to `STAIR_MAX_TREAD_U` 0.5 m |
| Run | 10.875 m (`link_min_run_u`) to 16 m | 5 m to 8 m |
| Steepest | 400‰ (21.8°) | 800‰ (4:5, 38.7°) |
| Walked at, along the slope | walk pace (1000‰) | half pace (`STAIR_SPEED_PERMILLE` 500) |
| Work a quantum | a bore's | 1250‰ (`STAIR_WORK_PERMILLE`: the risers are set as it is dug) |
| Quanta (shortest) | 12 | 7 |

- **Cost and quanta by the slope.** A link's planner cost and its quanta are its *slope* length (`link_slope_u`,
  rounded up; `link_quanta`, every started metre): the void is one standard bore along the slope. So stairs are less
  to dig and slower to walk; a ramp more to dig and quicker. The shortest stairs cost 6557 u at half pace (13.1 m of
  walk); the shortest ramp 11865 u at full pace.
- **Its floor** is `link_drop_u` (integer, exact) and `link_drop_m` (its float twin, for drawing and walking): a ramp
  eased in and out at the one grade that takes it 4 m down in its run; stairs straight down their pitch line.
  `floor_y_at`, `floor_grade_at` and the integer `floor_depth_u_at` read it; `speed_permille` gives the stairs' half
  pace (×1.1 when lit); `advance` scales a stairs quantum's work by `work_permille`.
- **Refused in words** (MOVE-REQ-018; `LINK_REASONS`): a head joining nothing ("starts on the first level's network:
  at a junction, a ramp's foot, a room's free socket or a bore's side"), a bend (two points only), too short for its
  grade ("going 4 m down at no steeper than 1:2.5 takes at least 10.9 m"; "16 timber risers of 0.25 m need treads of at
  least 0.31 m -- 5 m of run"), too long, and any piece joining a link's slope ("join it at its head or its foot", as a
  mouth's ramp cannot be joined). A link crosses nothing, and nothing crosses it. A point laid on level 1 snaps onto a
  link's slope only where the link's void is still within a pillar of level 1's floor; over its deep part it passes
  over (`_nearest_segment`), so a level-1 tunnel may be laid across the stairs' foot.
- **The foot** snaps onto level 2's network (a junction, a blind end, a room's free socket or a bore's side) or ends
  in a new **blind end** (`NODE_END`, below).

### 3. Building on level 2

- **Pieces** (`tunnel_plan.gd` LEVELS AND LINKS): the plan carries `level` and `link_kind`. On level 2 a piece snaps,
  crosses and keeps its junction gap only on level 2 (level 1's mouths count as level 1's); it must START on level 2's
  network (`REFUSE_LOWER_START`) -- the digger reaches it only from there -- and an end that joins nothing is a **blind
  end** (`piece_spec.gd END_BLIND`, stored as `NODE_END`), clear of every node on its level. No mouth opens on level 2,
  and the buildings' footings (level 1's UNDER BUILDINGS) do not reach it. A blind end is closed by a dug face in the
  drawing (`bore_view.gd ends_blind`) until a continuation has broken ground there (a planned one leaves the face), and
  is a node to dig on from.
- **The pillar in height.** Every pillar test now asks height too (`tunnel_rules.gd vertical_gap_u`,
  `tunnel_plan.gd clear_in_height`, `other_band_u`; `underground_rooms.gd _link_near_void`): two voids whose heights are
  a pillar apart or more need none in plan. So level 1 and level 2 never refuse each other, and a link keeps its pillar
  from each level only where its slope is near that level's height. A mouth's ramp is read at its own depth where it
  passes (its first leg is straight), not as the whole ramp's band -- the first probe refused stairs passing 2.4 m from a
  cellar hatch's mouth, already 1.6 m under its floor there.
- **Rooms** (`underground_rooms.gd`, `underground_graph.gd add_room(..., level)`): a level-2 room has **no mound, no door
  or hatch on the surface and no ramp**. Its door node is a **socket** (`NODE_SOCKET`) -- a free socket a passage joins --
  and its body is its piece's first segment. `refusal` on level 2 tests only the void: inside the village, off the water
  and its band, and a pillar from its own level's voids (and links at its height); nothing on the surface is asked.
  The room tool (`room_plan.gd`, `room_tool.gd` ON LEVEL 2) places rooms on the level the U view shows; on level 2 the
  auto-passage runs from level 2's network to the room's **door** only (it is dug from there), the room may not stand
  alone (`REFUSE_NEEDS_PASSAGE`, in words), the passage is put first in the job list and the room spoils where it does
  (`adopt_passage`, which records the room on the passage's piece, `piece_adopter`), and a passage that fails once the
  room is laid drops the room again (`drop_unbroken`). **The two go together when dropped unbroken**: the passage called
  away before its first tick takes its room with it (a level-2 room may not stand alone); the room called away before
  its first tick leaves its door as the passage's **blind end** (`NODE_END`, belonging to no room), to dig on from. A
  passage that outlives its room points at nothing, so a later room in the freed rows is never dropped with it. A
  passage is never dropped from under a room that has broken ground (`unbroken` asks both): called away, it is kept
  PAUSED instead. A level-2
  cellar's entrance for the pantry is its piece's spoil mouth (`entrance_u`). `way_in_count` / `way_in_node` count a
  level-2 room's door among its ways in (the cool rule's walks).
- **Rows** (`has_rows_for_room`): a level-2 room takes no mouth row and no ramp segment.

### 4. The ground at depth (demo values)

`tunnel_ground.gd` keeps a second grid, `deep_cells`, laid the same way from its own patches -- deeper means more clay and
rock and less sand:

| | Level 1 (unchanged) | Level 2 |
|---|---|---|
| Rock | 4 pockets | the same at 150% radius (`DEEP_ROCK_PERMILLE`) and 3 more (`DEEP_ROCK_PATCHES`) |
| Clay | 4 beds | the same at 140% and 3 more |
| Sand | 3 lenses | the same at 50% |
| Wet | within 4.5 m of the waterline | within 2.5 m (`DEEP_WET_REACH_U`: the water table) |

`type_at_level` / `wet_at_level` answer for a level (`type_at` / `wet_at` stay level 1's). Each quantum of a timeline is
cut in the ground of its own level (`quantum_level`: a link's head's level through the upper half of its drop, its
foot's below), and the hazards survey each quantum in its level's ground -- so **a level-2 bore seeps only within 2.5 m
of the water and strains only through its (smaller) sand**. In the demo village the ground grid comes no nearer the
water than ~2 m, so level 2 is wet only in that band; the first value tried, 1.5 m, left level 2 dry everywhere. The
readout (`dig_readout.gd`) and the route's ground words read the level's ground too.

### 5. Routing across levels

Nothing new was needed in the router: `graph_paths.gd`'s Dijkstra (h = 0, SET-MOVE-001 §4's reference) already walks
every usable segment between nodes, and a link is a segment whose cost is its slope over its pace. The mouth tables reach
level 2; a trip bound for a node on level 2 (`goal_node`) reaches it only through the network. The brain's TUNNEL state
walks a link as it walks a ramp (P1): the flat step is the pace times the slope's cosine, the body pitched with the
slope, the spine taking half back, the clip at the stride rate -- so the feet plant -- and stooping by the bore's crown.
The night (beds on level 2), crews (baskets carried up the link to the heap at the spoil mouth), evacuation and walking
out, a paused dig's resume, the cool rule (a level-2 cellar is 5.25 m deep; a hearth warms it only on its own level:
through the earth only from a home on its level, and by a run of passages within 6 m to its door that never goes up or
down a link -- the stairs' 5 m run alone is shorter than 6 m, so this is a rule, not a length) all work through the
same paths, and are tested against an independent Floyd-Warshall table where a route's cost is the claim.

### 6. The view: one level at a time

- **Layers** (`demo_layers.gd` THE SECOND LEVEL): level 2 has its own `UNDERGROUND_2` (bit 16) and `UNDERGROUND_2_MARKS`
  (32). `below(level)`, `marks(level)`, `level_mask(level)`, `floor_y`, `cap_y`, `view_floor_y`. The U view's mask is
  `level_mask(level)`: the other level's geometry is not drawn at all (no bleed-through).
- **Switching** (`tunnel_view.gd` THE LEVELS): **PgUp/PgDn** in the U view, read in `takes_before_gui` before the HUD and
  the camera (`tunnel_control.gd` THE SECOND LEVEL). Checked against the input map: PgUp/PgDn are `camera_zoom_in/out`
  and Alt+PgUp/PgDn `camera_pitch_up/down` (`project.godot`). So **in the U view, unmodified PgUp/PgDn switch the level
  and never zoom** (the wheel still zooms); on the surface they stay the zoom; Alt+PgUp/PgDn stay the pitch; U stays the
  view's toggle. A held PgUp/PgDn's auto-repeats are taken too and do nothing (else every repeat after the first would
  zoom). A switch is **one cull-mask write** and the indicator's text: nothing is built, faded or re-materialed.
- **The level laid on** is the level shown (`tunnel_control.gd laying_level`): the U view's, or level 1 with the view
  off. Opening the tool turns the view on *before* the plan takes its level, so a tool opened from the surface lays on
  the level the view then shows. Switching the view or the level with the Dig tool open drops a half-laid piece and
  lays on the new level, the room tool too; a link's head is always on level 1. A key held with Ctrl, Cmd or Alt, or a
  letter with Shift, is not the tool's (Shift alone still drops a bend). `Layers.active_level` (what the command layer
  and the actors read) is level 1 again once the view leaves the tree or is freed -- shared state reset by the one
  view there is; a second TunnelView leaving the tree would reset it under the first (the demo never has two).
  The pooled lanterns follow the view's focus to the level shown (as they followed a pan), each light put on its spot's
  level's layer.
- **Caps** (`underground_cap.gd` ONE CAP A LEVEL): one per level, at its own section (`cap_y`: level 2's at -4.15 m), on
  its own layer, reading its own void mask and its own strata (level 2's image built from level 1's water distances, so
  the water is not asked twice), its backstop under it and its own fill light. Each reads the **other** level's void
  mask for a faint cream **outline** (`other_strength` 0.28) of its bores' floors and rooms' edges -- an outline only.
- **Each cap is a true section.** A link is stamped into level 2's mask at its real rise (`RISE_RANGES_M`: level 2 codes
  rises to 4.25 m) -- the cap opens where it has come down under level 2's section -- and into level 1's only while its
  void still reaches above level 1's floor. From level 1 its head is seen going down under the cut; from level 2 its
  foot coming up through it. (Tried: stamping the whole link into level 1's mask so its whole length showed from above.
  It opened a window onto earth the section plane should hide, with the deep stairs seen at a parallax offset through
  it; rejected for the true section.)
- **Drawn on both levels**: a link's chunks each have a **twin** on level 2's layer sharing the mesh, each in its level's
  earth material (`bore_view.gd earth_material(level)`: the same shader, cut at that level's section). Stairs'
  **treads** (`stair_view.gd`): 16 blocks of packed earth fronted by a timber riser board, their tops' middles on the
  walking line, standing on the stairs' swept floor half a riser under it; one MultiMesh a level, each cut at its
  section. Hubs, rooms, fixtures, frames, lanterns, finds and stones are drawn on their level's layer, in their level's
  materials, at their level's floor; a level-2 bore has no roots (trees' roots do not reach 5 m).
- **Picking**: clicks land on the shown level's floor (`Layers.pick_y(on, level)`, `tunnel_view.pick_y`, the command
  layer's orders); selection of a room or a tunnel, and a right-click resume, take the shown level's (a link is on both).
- **Residents** (`resident_brain.gd view_level`): on the surface (layer 1), on level 1 or level 2 (their level's layer);
  on a link, its head's level while its floor is within a bore's crown of level 1's floor, its foot's once under level
  2's section, and in between **BETWEEN_LEVELS** -- drawn on no layer, as each section is solid earth over it there. A
  resident's **marker** shows in the views of the levels it is not on (`marker_mask`: every level's from the surface or
  between), on the shown level's floor; the command layer picks such a resident at its marker.
- **The level indicator**: a dark strip centred in the top-centre column at the HUD's scale (`scripts/ui/ui_layout.gd`),
  below the band the HUD stacks under the alerts -- the pause label (UI-SET-086) and the error panel (UI-SET-085) at
  their registered least heights (`ui_registry.gd`, read once) -- on canvas layer 0, under the HUD's, so a grown error
  panel, the open history or the stall banner covers it rather than the other way round. At 1080p that is about a
  third of the way down the screen, where it can cover a world label behind it (frames in `revamp_p6_check/look4/`) --
  the cost of keeping clear of the HUD's band; a later UI pass may give it a zone of its own (MOVE-G03). It says
  "Underground · Level 2 of 2 (floor 5.25 m down) · PgUp: level 1" -- its depth formatted from the constants -- shown
  with the U view; the party panel's notice says so on a switch. A link's selection line is drawn on both levels' marks.
- **The top level only on the surface**: seams and vents (`warren_signs.gd signed`) and a digger's mound are level 1's;
  a level-2 home has no chimney or smoke.
- **Particles**: the 200-particle budget and the 3 face / 2 hazard slots stay village-wide; an emitter is put on the
  layer of the level it emits on whenever it is given a place (`Layers.level_at`).

### 7. Prewarmed at build time, never at a switch

Every level-2 material is registered with the U view's prewarm when the view and its parts are built (at boot, before
anything is dug on level 2): level 2's cap, the bores' and hubs' earth (rooms' shells wear the hubs'), the stairs'
treads, the frames' and ribs' cutaways. The boot prewarm draws every level's layers for its two frames. Same shaders,
so no new pipeline; a test requires the registry to cover every node on level 2's layers.

## Deviations from the design, and why

- **Rooms on level 2 have no door to the surface**: a ramp from the ground 5.25 m down would be 13+ m of 1:2.5. They are
  entered only through the network, at their door, which is a socket.
- **A link is one straight segment**: a ramp or a flight of stairs is laid head to foot with no bends; turns are made
  with level bores at either end.
- **Stairs' risers cost time, not timber**: the stairs' quanta take a quarter more work (setting the risers) rather than
  planks from the demo stores; a store payment would need a refund path on every drop and pause. The design's "timber
  ramp risers and stairs" are drawn.
- **Two levels only**, not DEC-040's four: the brief's scope.
- **The camera's focus stays at the ground** (design §5: "the rig's focus moves to the level's floor height"): the demo
  camera clamps its focus to y = 0, and in the top-down U view the 5.25 m difference only shifts the orbit's pivot.
  Clicks, the pooled lights' focus and the markers do use the level's floor; moving the rig's pivot is left to the
  production camera (MOVE-G03).
- **The refusal words carry the candidate numbers as text** ("4 m down", "10.9 m", "16 timber risers", "16 m", "8 m"),
  as every other refusal in `tunnel_rules.gd` does; a test checks each against the constants, so changing the
  candidate spacing fails until the words are changed with it. The indicator's depth is formatted from the constants.

## Measured

All runs below use the windowed probe (`scratchpad/revamp_p6_agent/p6probe.gd`) at 1920x1080 on the Apple M5 Pro,
120 Hz vsync. Every run starts cold: the shader and pipeline caches are moved aside first. The machine was **not**
quiet: other agents' Godot suites kept the load at 9-16. The table gives the last two cold runs after the review
fixes (perf6, perf7), and five cold runs agree.

| | Result |
|---|---|
| First cold U toggle, worst frame | 14.7 / 11.7 ms; 6 pipeline specialisations; no stall banner, no clock pause |
| First level switch from cold (1 to 2), worst frame | 15.0 / 15.2 ms; **0 compiles**; the bar is 50 ms |
| 20 level switches, worst frame | 15.3 / 15.3 ms, on the first 2-to-1 switch; the other 19 are **at most 9.3 / 9.2 ms**; 0 compiles, 0 banner frames |
| 20 U toggles, worst frame | 9.2 / 8.7 ms; 0 compiles |
| Surface: median / p95 frame, draws, objects, primitives | 8.33 / 8.59 ms; 61 draws; 70 objects; 1,122,090 primitives |
| U view level 1: the same | 8.33 / 8.53 ms; 43 draws; 102 objects; 43,444 primitives |
| U view level 2: the same | 8.34 / 8.61 ms; 28 draws; 59 objects; 27,682 primitives |
| CPU: `set_level` | 11.7 µs |
| CPU: `view_level` for every resident | 1.6 µs |
| CPU: hazard view / signs / marks a refresh | 48 / 33 / 22 µs |

All frames stay at the vsync cap, within P1's budgets. Level 2 draws fewer objects than level 1, because the other
level is not drawn at all.

**The first switch in each direction misses one vsync**, at about 15 ms with no pipeline compiled. This held in every
cold run, and repeats of the same switch stay at or under 9.3 ms. These were ruled out:

- **The notice text**: a run with the switch's notice removed still showed it.
- **The indicator's glyphs**: every level's words are now drawn under the boot prewarm's cover (`prewarm_words`), and
  the frame is unchanged.
- **Shadows**: the pooled lights cast none.

The measured split of the frame was too coarse to name the cause, so it stays open. The 20-switch figure therefore
includes one first-time switch (2 to 1), much as a cold first toggle is its own row.

Set-up costs:

- `set_level` costs 11.7 µs (it was 0.33 µs) because it now re-measures the indicator's words to centre them; the HUD's
  layout is computed once per screen size.
- **Feet** (`scratchpad/revamp_p6_agent/feet.json`; walking code unchanged since that measurement):
  - the mouse keeper's worst foot drift is 2.23-2.31 cm on the ramp and 2.07 cm on the stairs, its right foot (its
    clip's own ~2.1 cm drift on the flat, found in P1), with every mean under 1.6 cm;
  - the squirrel's is 1.64 / 0.67 cm;
  - the mole's is 1.26 / 1.04 cm.
- **The MOVE-TEST-01-style walk** (`scratchpad/revamp_p6_check/walk4/`): a resident goes from the surface through the
  front door of a placed home, across it, down its stairs, along the level-2 passage into the level-2 home, and back
  out the same way. Frames show both levels and the link.

## Tested

`godot/test/test_demo_levels.gd` (38 tests) and `godot/test/test_demo_levels_edges.gd` (23), headless:

- the rules: the spacing, a ramp never steeper than 2:5 sampled every 16 u at its shortest and longest runs (and its
  float twin within a unit), `link_slope` equal to the drop's rate of fall in the fillets and the middle, the stairs'
  pitch, pace and work, the refusals in words, cost and quanta by the slope, and the refusal words matching the
  constants;
- the ground at depth: more clay and rock and less sand over the grid, a deep pocket and a lens rim at 140%, wet only near
  the water table, each link quantum cut and read out in its own level's ground;
- level-2 buildability and refusals: a start joining nothing, a blind end and its gap, the snapping and the junction gap
  per level, the pillar in height (crown to floor along a link; under a mouth's ramp; a link through a level-1 home at its
  height refused, past one by its foot allowed), rooms (no mouth or ramp, refused only by their own level: bounds, water,
  rooms, tunnels, links at their height, nooks), the row counts, a level-2 room's passage first, a dropped room leaving
  its door a blind end, a dropped passage taking its room, an orphaned passage taking no other room, the pantry entrance;
- cross-level routes: two trips through both links equal to an independent Floyd-Warshall (MOVE-TEST-09 style), a trip
  bound for a level-2 node against the same reference, and walking out up the reference's cheaper link;
- the night (beds on level 2 down the stairs), a crew basket up the stairs to the heap, a level-2 dig reached, paused and
  resumed through the stairs, the cool rule's depth and its walk never passing a link;
- the view over the playtest village with its second level laid through the Dig tool: per-level layers, materials and
  floors; a switch writing the cull mask only (twenty switches, the drawn state otherwise unchanged); PgUp/PgDn only in
  the U view, their repeats taken, Alt+PgUp the pitch, Ctrl+L not L; the level laid on following the view; picking per
  level; the caps' outlines and true sections; markers; the indicator under the alerts at 4K at the HUD's scale; the
  prewarm registry covering every node on level 2's layers; the surface signs; the bore view's blind face going when the
  network runs on, the link twins, the door cut once a level-2 room breaks ground, and the stairs' treads.

**Mutation**: 212 mutants (198 over the work and the first review's fixes, 14 over the re-review's), one at a time, each restored and its hash checked (`scratchpad/revamp_p6_agent/mutate.py`).
Pass 1, 178 mutants over the new logic against the levels suite: 116 killed. Killers were written for the 62 survivors
and 20 mutants added on the review's fixes. Pass 2, 82 mutants against both level suites: 78 killed. Pass 3 covered the
last three: all killed. **One survivor is equivalent**: `passage.count < 2` mutated to `< 1` in `room_plan.check`.
After `_propose` the passage has either 0 points (cleared) or the 2 of a lay that passed, never 1.

The full suite: see the commit's run (`./tools/run_tests.sh`).

## Review

The independent `code-reviewer` agent reviewed the diff and found no CRITICAL issues, five HIGH and nine MEDIUM. All
HIGH were fixed:

- **H1**: dropping a level-2 room left its door a socket pointing at a freed room row. `_forget_room` now walks every way
  in (the door too), frees its `node_room`, and leaves a degree-1 survivor on level 2 as a blind end. Tested.
- **H2**: dropping a passage stranded its level-2 room. `piece_adopter` now records the adoption, and dropping the
  passage unbroken drops the room too. Tested, including that an orphaned passage takes no later room with it.
- **H3**: a blind end's dug face stayed after the network ran on from it. `ends_blind` is now folded into the bore
  view's state key and `hub_bits`, which also feeds the overlay's key. Tested.
- **H4**: refusals were untested. Killing tests were added for the link through a level-1 room, the level-2 room's water
  and bounds, the blind-end row count, and the listed MEDIUM survivors.
- **H5**: `prewarm` is now typed.

MEDIUM:

- **M1**: PgUp/PgDn repeats are taken in the U view.
- **M2**: `Layers.active_level` is reset when the view is freed and in the suite's `after_each`.
- **M3**: a level-1 point passes over a link's deep part.
- **M4**: the cool rule's walk never passes a link, and the header no longer claims a length.
- **M5**: the camera pivot not moving is recorded as a deviation.
- **M6**: the indicator is placed through `UiLayout`.
- **M7**: a link's selection line is drawn on both levels.
- **M8**: the level laid on is `laying_level`, re-synced on U.
- **M9**: both route oracles now use an independent Floyd-Warshall table.

LOW:

- **Fixed**:
  - `BETWEEN_LEVELS` is now one value;
  - Ctrl+L no longer cycles links;
  - removed the dead line in a test.
- **Kept**:
  - Words carrying the candidate numbers: now tested against the constants.
  - Tests reaching into private members: as the existing suites do.
  - Shift+click wording on level 2: unchanged.
  - `plan_status` naming the head level's ground: a link's ground is in the readout's tally per level.

**The re-review** (the same agent, over the fixes) found one HIGH, two MEDIUM and four LOW issues. All are fixed:
- **H-A**: `begin_plan` took the plan's level before turning the view on. A tool opened from the surface with level 2
  set laid on level 1 while level 2 was shown. The view is now turned on first. Tested.
- **M-A**: `ends_blind` counted planned segments, so the face went as soon as a continuation was laid. It now counts
  only segments that have broken ground (`dug_degree`). Tested.
- **M-B**: the indicator overlapped the error panel's band. It now stands below that band at the registry's sizes, on a
  canvas layer under the HUD's. The test reads the registry.
- **L-A**: modified letter keys are no longer the tool's.
- **L-B**: `unbroken` guards both drops. `_drop_piece` asserts the adopter was dropped. Tested.
- **L-C**: the stale docstring is fixed.
- **L-D**: the shared level reset is noted above.

Mutation over these fixes: 14 mutants, all killed.

## Merged with master

`origin/master` at b49b982 (review groups B, C, D, E and G, PR #199) merged into `feat/live-demo` with no textual
conflict and no semantic fix needed:
- E's `refresh_panel` / `housing_line` wording merged beside P6's level-aware rooms.
- G's input gate (0261) runs its `_input` before the Dig tool's. Outside a modal, the gate drops a click's focus and
  passes PgUp/PgDn on, so the U view's level keys still reach the tool. Inside a modal, it swallows them, as it does
  every world key.
- G's Demo Lab and button factories touch no P6 code.

After the merge:
- the suite: `ok: 6568 tests, 554739 assertions, 0 failures.`;
- the live input harness: `LIVE-SUMMARY 116 0` at 1280x720 and `LIVE-SUMMARY 121 0` at 1920x1080;
- `demo/demo_village.tscn` boots headless for 600 frames with no error.

## Consequences / open

- **MOVE-G01–G05 stay open.** The 4 m spacing, the two levels, the link grades and paces, the stairs' work and the
  ground at depth are demo values; none settles production geometry, depth extents, profiles or the representation.
- In the U view PgUp/PgDn no longer zoom (the wheel does). If a later UI pass wants zoom on keys underground, `+`/`-` or
  the level keys would need rebinding in `ui_ux_controls.md` (MOVE-G03 owns the layer controls).
- A resident on a link's hidden middle is a marker on both levels; its body is drawn only where a section shows it.
- The level-2 strata are procedural noise-warped patches like level 1's; P7 changes nothing here.
- **Open: the first switch each way misses one vsync** (~15 ms, no compile; see Measured) -- under the 50 ms bar, but
  above the ~10 ms of every repeat; not yet traced.
- **For P7**: the stairs' treads are boxes in plain cutaway materials and want a proper timber step prop (risers,
  nosing); the hand lantern, basket, mouth lantern and the room props are as 0211 says.

## Source

`docs/design/underground_revamp.md` §3 (levels, rule 7), §5, §8 P6 and §10 (Brendan's ruling); SET-MOVE-001 §4 (the
Dijkstra reference) and its DEC-040 follow-up (the four-level 4 m candidate); MOVE-REQ-013 (levels), MOVE-REQ-018
(refusals in words); decisions 0206–0211; `project.godot`'s input map (UI 5: PgUp/PgDn zoom, Alt+PgUp/PgDn pitch).
