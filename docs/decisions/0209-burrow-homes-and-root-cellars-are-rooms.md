# 0209 — Burrow homes and root cellars are rooms on the network
Date: 2026-09-30 · Status: Accepted

Phase P3 ("Rooms as their own structures") of the approved underground revamp
([`docs/design/underground_revamp.md`](../design/underground_revamp.md) §3, §4 and §8 P3; Brendan's rulings
in its §10). It builds on [0208](0208-the-tunnels-are-one-network-graph.md) (the network graph) and
[0207](0207-swept-bores-lantern-light-and-the-stoop.md) (swept bores, lanterns, the stoop). Everything here is
presentation. The demo's rooms shape the demo cast's walks and the pantry demo's stores, and nothing writes
into the simulation. MOVE-G01–G05 stay open.

`burrow_chambers.gd` is gone, along with its 3×3 m rooms bolted 2 m off a tunnel, with no doorway and no
passage. `underground_rooms.gd` (moved from it, so its history follows) holds the templates, the room table
and the placement rules. `room_view.gd` (moved from `burrow_view.gd`) draws the rooms. The new
`room_mesh.gd`, `room_plan.gd` and `room_tool.gd` build the shells, propose passages and run the tool.

## Decision

### 1. Two templates, 24 quanta each

| Template | Shape | Floor quanta | Quanta | Sockets | Its own way in |
|---|---|---:|---:|---:|---|
| Burrow home | Round, 4 m across | 12 | 24 | 3 (the ends of the two walls and the back) | A round front door in a turfed mound |
| Root cellar | Barrel vault, 3 × 4 m | 12 | 24 | 2 (the back and one side) | A hatch over steps |

- **A room is `HIGH_QUANTA` (2) quanta high over its floor quanta.** Each quantum is cut in a floor cell of
  the template, nearest the door first (`CELLS_LOCAL`, two quanta a cell), so the dig grows out from the door.
- **The walls bow out 10% at the springline** (`BULGE_PERMILLE` 1100), as a bore's do. The void is the floor
  extent bowed out, and every placement rule measures it exactly.
- **A room is turned in quarter turns**, so a vault's sides stay on the axes and every rule stays integer.
  In its own frame the door is at −Z, 2 m from the middle.
- **Every room carries its level** (MOVE-REQ-013). Only level 1 (`BUILDABLE_LEVEL`) is dug; a level-2
  request is refused ("LEVEL"), and P6 adds it.
- Caps: 8 rooms (`MAX_ROOMS`). Mouths go from 16 to 24 (`MAX_MOUTHS`), because every room's door or hatch is
  a mouth; 16 tunnels' worth of mouths would otherwise run out at eight tunnels and eight rooms.

### 2. Headroom: raise the room, don't sink the floor

The design (§3) gave rooms a 2 m ceiling, "everyone except the badger stands". Brendan's P3 brief says the
badger stands upright in a home. The badger is 2.55 m tall, so rooms take a third bore class, `BORE_ROOM`:
4 m wide and a 2.75 m crown (`ROOM_CROWN_U` 2816).

Two ways to get that headroom were weighed:

- **Sink the floor** to −2.0 m. The room's passages would then need ramps inside the room or a step at
  every socket. The floor would also no longer be level 1's floor, which the graph, the router, the cap and
  the level column all assume is one plane per level.
- **Raise the section** (chosen). The floor stays at level 1's −1.25 m and the crown rises to +1.5 m. The
  design already says the room's rise above grade *is* its turfed mound. A higher crown makes the mound
  1.5 m instead of 0.75 m, which reads better from the RTS camera. Passages meet a room on the level with no
  steps. The stoop (0207) reads `BORE_ROOM`'s crown, and everyone, the badger included, stands.

### 3. A room is one piece on the graph

`underground_graph.add_room` lays a room as one PLANNED piece in the digger's job list:

- **A mouth node** on the surface, of mouth kind `MOUTH_DOOR` (a home) or `MOUTH_HATCH` (a cellar), and its
  4 m **ramp** down to the **door node** in the room's wall. The ramp is a wide bore, so the badger comes in
  by the front door.
- **The body**, a `SEG_ROOM` segment of class `BORE_ROOM` from the door node to the room's **middle node**.
  Its dig timeline is the room's 24 quanta, cell by cell (`quantum_point_u`). The body is dug at three faces
  (`ROOM_FACES`): the crew's pipeline rate for three quanta side by side (`tunnel_crew.pipeline_permille`),
  so a room's crew is not held to one face as a bore's is.
- **A walk**, a `SEG_ROOM` from the middle to each **socket node**. Walks open when the body opens (they are
  the room's own floor), are not dug, and are not counted in the piece's progress.

The rest of the demo treats a room as it treats a tunnel:

- Spoil goes to the mouth's heap, by the existing crews and jobs.
- A dropped room that never broke ground frees its row. A socket that a passage still reaches stays behind
  as a plain junction.
- Hazards, crossings, braces and lantern rows skip room segments (`is_tunnel`).

### 4. Doors and hatches are mouths the router uses

`mouth_kind` is a new mouth column (`MOUTH_TUNNEL`, `MOUTH_DOOR`, `MOUTH_HATCH`). The router offers a room's
door or hatch like any mouth, and the paths reach the room's middle through its ramp and body. A wide walker
may use any bore that is not standard (`graph_paths.admits`), so the badger walks in at the front door but
does not go on through a standard passage.

**`leads_on`.** A standalone room's door leads only into its room. It is offered to the router only for a
trip whose goal node is inside the network and reachable from it, or when it reaches another usable mouth.
Offering every dead-end door raised the router's p95 from 129 to 157 ms with four standalone rooms; with
`leads_on` it is back to 126–127 ms (the P2 baseline). A joined room's door is a way through like any mouth.

### 5. Sockets and passages

- **A passage joins a room only at a free socket** (END_NODE at a `NODE_SOCKET` whose walk is its only
  segment). A point never snaps onto a room's middle, its door node or a taken socket.
- **It leaves the socket straight out.** It must stay within the 40° meeting angle of the socket's way out
  (`leaves_straight`), and its first leg must run straight for at least 1 m (`SOCKET_STRAIGHT_U`) before any
  bend's fillet. Otherwise it is refused as SOCKET_ANGLE; a socket already taken is SOCKET_TAKEN.
- **1 m of earth from every room's void.** A passage keeps 1 m of earth and half a bore from every room's
  void, except within 2 m (`ROOM_JOIN_U`) of the socket of the room it joins. Running into a room anywhere
  else is refused as INTO_ROOM. Crossing a room's ramp, body or walk is refused the same way.
- **Once the room is dug, the passage is cut clean at the room's wall.** A bore ending at a socket, or at
  the door once the room breaks ground, is cut by a plane through the room's wall there (`room_cut`; the
  shader's plane mode). The tunnel then opens into the room rather than poking through it.

### 6. Where a room may go

`underground_rooms.refusal` checks the rules below in order and returns the first that fails. Each has its
own words, and every test is exact integer geometry on the void, the mound (the void and 0.5 m of turf,
`SKIRT_U`) and the door ramp's cutting (1 m either side of it, `HOOD_HALF_U`).

| Reason | Rule |
|---|---|
| LEVEL | the first level only |
| FULL / NETWORK_FULL | a free room row; the network's node, segment, mouth and piece rows for it |
| OUT_OF_BOUNDS | the mound and the door inside the village |
| UNDER_WATER | the void, the ramp and the cutting clear of the stream, the pond and their no-dig band (half a bore, as tunnels) |
| OVER_CROPS | the mound and the cutting clear of every crop bed |
| UNDER_BUILDING | the mound and the cutting clear of the buildings and the well |
| NEAR_ROOM | 1 m of earth between voids, between this room's ramp and another's void, and between the two ramps (a wide bore's pillar gap) |
| NEAR_TUNNEL | 1 m of earth between the void or the ramp and every tunnel (join one at a socket instead) |
| SURFACE_BLOCKED | the door, the mound and the cutting clear of trees, heaps, props, work spots and mouths |

A room's mound and ramp are obstacles on the ground from the moment it is laid, not only once it is dug
(`cast_space.set_mound`). Heaps are then placed off them, and nobody walks over the dig.

### 7. The auto-passage

Unless it is placed standalone (Shift+click), the ghost proposes a passage from the nearest valid socket to
the network within 6 m (`AUTO_REACH_U`). The candidates are:

- on every open tunnel bore, the foot of the perpendicular from each socket and the point where the socket's
  way straight out meets the bore;
- every junction and ramp foot.

Each candidate is snapped as a pointer would be and laid through the full piece rules (with the socket's way
out, `pending_outward`). The passage starts where its join snapped (a node, or a point on a bore) and is
measured from there. It must also keep a wide-and-standard pillar of earth from the room's own door ramp, which
the piece rules cannot see until the room is laid. The shortest passage that passes is kept.

A click lays the room, then the passage as a P2 piece ending END_NODE at the socket, both in the digger's job
list, room first. The passage is checked again once the room is laid. Should it fail then (the network's last
rows, say), the room stands alone and the notice says why. A room placed standalone is joined later by
drawing a tunnel to one of its sockets.

### 8. The tool

- **Opening it.** H (Burrow home) and C (Root cellar) open the room tools from the Dig tool, as do two new
  buttons on the party panel, which replace the chamber buttons. Pressing the same key again goes back to
  laying tunnels.
- **The ghost.** It follows the pointer on a 0.25 m lattice. R turns it a quarter turn (Shift+R the other
  way); the wheel stays the camera's zoom. The ghost is cream when the room may go and clay when it may not.
  Its words sit over the ghost's middle, wrapped, so a long refusal stays clear of the side panels. They give
  the template, the quanta, the hours, the spoil and the passage ("to Tunnel 4", "to a ramp's foot"), or the
  refusal.
- **Checking and drawing.** The ghost is checked and redrawn only when it moves to another lattice point,
  turns, or the site changes. The site (heaps, mouths, work spots) is taken afresh whenever the network's
  revision or the ground's obstacles change, and again on each click. A second room laid in one session is
  checked against the first one's door and heaps.
- **The panel.** Its heading says "Placing a burrow home" or "Placing a root cellar".
- **Closing it.** Esc or a right-click goes back to laying tunnels.

### 9. The look

- **The shells.** A home is a lathe dome with bed alcoves bowed out 0.45 m (`ALCOVE_U`) round each bed; a
  cellar is a barrel vault with straight end walls. Both use P1's earth shader and vertex format. Socket and
  door openings are left in the wall.
- **Staged digging.** The shell grows in six stages out from the door as the body is dug, and is built at
  dig time, never at a toggle. Digging moves no network revision, so the view also re-checks each room being
  dug whenever its whole percent dug changes. Its shell then grows stage by stage, and its "(digging N%)"
  label keeps count.
- **The timber inside.** A home has a ring beam 0.14 m inside its wall; a cellar has a rectangle of wall
  plates. The beam's top sits under the section plane. It is carried by the `tunnel_brace` frames at the door
  and each socket, which are as tall as the beam is high. From above, this reads as a few clear posts
  carrying one ring. The first version had eight wall ribs cut off by the section, which read as rows of
  stumps.
- **Floor and light.** Each room has a packed floor and a lantern from P1's pool, tinted per room (warm in a
  home, cool in a cellar).
- **Stone lining.** The cellar's lower wall is stone-lined through a vertex mask (COLOR.b) in the shared
  bore shader, and the cellar is lit grey-blue.
- **Fixture places** (`FIXTURES`, in the room's frame):
  - a home has three beds in its alcoves, a hearth, a table, a lantern and a basket;
  - a cellar has two shelves, jars, a basket and a lantern.
  - Beds, shelves, jars, baskets and the lantern stand now. The hearth and table places stay empty for P4.
  - The cellar's first shelf place is the farm's pantry shelf.
- **The mound.** A dug room is a low turfed mound: a bank flaring into a skirt 0.9 m beyond its obstacle,
  1.9 m high. It wears the village ground's own shader with the worn paths left off, so it is the grass
  round it even over a path.
- **The cut for the door.** Where the ramp comes in, the mound is cut back to a bank of bare earth at the
  room's wall. Set in that bank:
  - a home has a round front door in a timber ring on a fieldstone sill, reached down the ramp's open cutting;
  - a cellar has a bulkhead hatch: two plank leaves sloping from the face over the top of its steps, in a
    timber frame on a sill.
- **Why it changed.** The first version ran a turf hood (a half-buried barrel) over the whole 4 m ramp with
  the door at its end. It read as a long straw tube, not a bank.
- **Prewarming.** The underground pieces register with the U view's prewarm, including every ghost ring and
  the ring beam. The surface pieces are sampled for two frames 3 m under the ground where the camera looks,
  behind the opening pause (a "rooms on the ground" frame step). So the first room finished on a running
  clock compiles nothing.

### 10. What the rest of the demo reads now

| Reader | Now |
|---|---|
| The pantry (`farm_cellars.gd`) | `rooms.cellars(graph)`: dug root cellars, same dictionary shape and the same `root_cellar:<slot>:<gen>` id, positioned at the hatch; the pantry stores to them as before |
| The stock shelf (`farm_stock_view.gd`) | The cellar's first shelf place |
| The housing line | `rooms.housing_line`: homes, their demo beds (three a home: the GDD's dormitory density), cellars |
| The job list and the digger's line | Rooms are named ("Digging Burrow home 1 — 40%") |
| The playtest scene | Starts with a real home at (−1, 10) m and a root cellar at (−7, 4) m, each with its passage to the bore |
| The notices | A tunnel's opening says its bore is for mice, moles and squirrels, and that rooms and their doors take everybeast; a room's says everybeast stands in it |

## Deviations from the design, and why

- **The crown is 2.75 m, not 2 m** (§2 above): Brendan's P3 brief, which has the badger stand upright in a
  home, outranks the design's "everyone except the badger stands".
- **Eight rooms, not sixteen, and 24 mouths.** Eight rooms are more than the demo village holds (each needs
  its mound, its ramp and 1 m of earth). The mouth table grows so that tunnels are not starved.
- **The auto-passage cannot be dragged.** The tool proposes one; a different one is drawn with the tunnel
  tool to a socket afterwards.
- **The door ramp is paid as a standard bore.** It is drawn and walked as a wide bore, so the badger comes
  in by the front door, but its dig charges one quantum a metre (4 for the ramp), not a wide bore's six. That
  keeps a room's dig about its 24 quanta, as the design sizes it. A player's Widen job still charges the full
  wide price.
- **The playtest cellar moved.** Its old spot at (0, 4) m now has a work spot under its mound, so it moved to
  (−7, 4) m, where it also takes a passage.

## Measured

On the probe (`p3probe.gd`, 1920×1080, Metal, cold shader and pipeline caches), run on the P2 playtest scene
(before) and the P3 playtest scene (after):

| | Before (P2, chambers) | After (P3, rooms; final run) |
|---|---:|---:|
| First cold U toggle, worst frame | 12.0 ms | 12.9 ms (7 new pipeline specialisations, no banner) |
| 20 U toggles, worst frame | 9.8 ms | 9.4 ms |
| U view: objects / primitives / draws | 39 / 33,406 / 26 | 64 / 65,335 / 42 |
| U view at 2× supersampling, median frame | 8.28 ms | 8.33 ms |
| Surface at 2× supersampling, median frame | 19.9 ms | 19.8 ms |

- **GPU time.** The GPU timer reads 0 on Metal, so, as in P1, the budget is compared by frame time and draws.
  Both views stay at the 120 Hz floor at 1×.
- **Walk-in.** From the surface, the mouse and the badger went in at the home's front door (ramp, body,
  walk). The squirrel went in at the tunnel and through the passage. The badger's stoop in the home is 0.0 m.
- **The toggle spike, found and fixed.** The first 20-toggle run had one frame of 50–110 ms, with no
  compiles and no revision change. The time was one node's `_process`. Timing every route plan found
  64–91 ms plans, including plain surface trips with no mouths offered. Timing the navigation's graph build
  found the cause: each body class's visibility graph (about 540 circles and 1,200 nodes in the village,
  52–90 ms) was rebuilt whole by the first plan for that class after any obstacle change. A heap grows on
  every dig accepted and a room's mound stands from placement, so these spikes landed at random frames. P2's
  heaps had the same mechanism; rooms made it more frequent. The fix: `cast_nav` keeps each class's graph in
  use and rebuilds it a slice a frame (1.5 ms, `advance_builds` from the cast's frame), then swaps it in. A
  class's first graph is still built at once. On a quiet machine the 20-toggle run's worst frame is now
  9.4 ms (P2: 9.8 ms). Runs made while another worktree's render probe used 20–40% of the CPU read higher
  and are not used here.
- **Budgets on the final run** (quiet machine): U view 8.33 ms median at 1× and at 2× supersampling; surface
  8.34 ms at 1×. An unchanged room-view refresh costs 4 µs, now that it also watches rooms being dug. A ghost
  check with its auto-passage costs 1.0 ms a pointer step: every candidate is now snapped and tried, where the
  raw length used to rule some out. It runs only when the ghost moves to another lattice point. A home's shell
  build costs 0.41 ms.

## Tested

- **The suite.** `./tools/run_tests.sh`: `ok: 6228 tests, 547214 assertions, 0 failures.` P2 had 6161 tests.
  `test_demo_rooms.gd` is new. It covers template quanta, socket snapping, every refusal, the provider
  dictionary's shape, and doors and hatches in routing. The chamber tests migrated to rooms. Tests of the
  sliced navigation rebuild are in `test_demo_cast.gd`.
- **Mutation testing** of the new logic, one mutant at a time, restored and checked by hash each time: 141
  mutants in all.
  - **The rooms (94).** 70 were killed at first; the tests added for 18 more of the 24 survivors killed them.
    One was dead code (`room_of_socket`, removed). Five were argued equivalent:
    - the sign of a vault's inverse turn in `gap_u`: a half turn leaves the box unchanged;
    - `_joins_room` and `ROOM_JOIN_U` in the void check: the pillar check on the room's own ramp, body and walks
      refuses the same legs and names the same room, and the bend rules keep any passage that joins at a
      socket off the rest of the void;
    - the auto-passage's reach bound: every candidate is already within it;
    - bore-only candidates: a foot on a ramp's side is never a join.
  - **The panel heading and the ground's material (4).** All killed.
  - **The first review's fixes and the coordinator's feedback (30).** 16 were killed at first, then 12 more
    after new tests. The other two exposed unreachable code: a dead call in `ensure_graph` and a repeated
    final lay's `else`. Both are removed.
  - **The second review's fixes (13).**
    - 9 were killed at first, and 2 more once the new-circle count was tested.
    - One exposed a now-redundant walk check in `_announce` (removed).
    - One survives: the inflation of the stale-edge test (`_fresh_hit`: the circle's radius alone, against
      radius, body and margin). The only effect is how closely a route made during a rebuild may graze a new
      circle. No route test we could build separates the two.

## Review

Two independent `code-reviewer` passes ran on the uncommitted diff against 157a3a4.

**First pass: 2 CRITICAL, 4 HIGH, 6 MEDIUM, 10 LOW.**

| Finding | Fix |
|---|---|
| C1: the room tool checked against the site from when it opened, so a second room could cover the first's heap or door | The site is taken afresh whenever `site_key()` (network revision, obstacle rebuilds) changes, and on every click; tested with two rooms in one session and a heap under a still pointer |
| C2: the auto-passage kept the raw candidate point but the snapped join, so the passage laid was not the one shown, and its quanta were charged wrong | The passage starts where its join snapped and is measured from there |
| H1: a room's shell never grew in stages while dug, and its "(digging N%)" label froze | The view re-checks each room being dug when its whole percent dug changes |
| H2: NEAR_ROOM had no ramp-to-ramp check | Added, at a wide bore's pillar gap |
| H3: an assertion could not fail (the middle node after release) | It now checks every node and the mouth row freed |
| H4: the preview ignored the room being placed, so a proposed passage could be dropped quietly | The passage keeps a pillar from the room's own ramp (`clear_of_own_ramp`); a passage failing once the room is laid is dropped with a notice saying why |
| MEDIUM: the wide door ramp charged as a standard bore | Recorded as a deviation (above) |
| MEDIUM: a mound could cover work spots | Work spots and mouths are kept off the mound and the cutting |
| MEDIUM: the surface pieces were not prewarmed | The "rooms on the ground" frame step |
| MEDIUM: the ghost rebuilt on every mouse motion | It is drawn only when it moves, turns or its site changes |
| MEDIUM: duplicated code (`_leg_box_gap`, the shelf transform, key handling, the passage strip) | Left: each copy is small and differs in its frame or types |
| MEDIUM: untested branches | Tests added for each named branch |
| LOW: the ghost's words at the cursor | Centred on the ghost |
| LOW: `set_cap` did not reset `_seen` | Reset |
| LOW: `_join_name` called a ramp's foot "a junction" | Says "a ramp's foot" |
| LOW, left: `take`'s −1 row (every caller guards it); `BEDS_PER_HOME`'s literal; the MAX_MOUTHS comment; C in the Dig tool shadowing the spoil tool's C (only with a heap selected); `after_splits` run twice (idempotent) | Noted, not changed |

**Second pass: 1 HIGH, 6 MEDIUM, and LOWs.**

| Finding | Fix |
|---|---|
| H1: while a graph was rebuilt, a plan could route straight through a new heap or mound and report it found, and the placement gates trust that | Each graph remembers the circles it was built from; while it is rebuilt, its edges and nodes are tested against the few circles new since (`_fresh`); tested with a wall whose gap a heap plugs |
| M1: nothing guarded the ground material's copy (without it the village loses its paths) | Tested: the mound's material is a copy; the ground keeps its paths |
| M2: nothing guarded the prewarm samples being freed | Tested |
| M3: a rebuild slice ran over budget (2.2 ms) because the bucketing and finishing ran unbudgeted | Bucketing ends its own slice |
| M4: the room's dug notice and the walks' silence were untested; a new test found the notice said twice when a room's ramp and body opened in one frame | Each piece's dug notice is said once per look; tested |
| M5: the cutting's part of SURFACE_BLOCKED was untested | Tested with a tree beside the ramp |
| M6: claims in this record out of date | Corrected here |
| LOW: `room_site` handed out the tool's arrays by reference; `_has_cursor` survived `end()`; door and hatch meshes built per redraw; string keys; untyped arrays in `_quad`; the cast_space docs; `set_mound` dropping extra circles silently | Copies handed out; reset; shared; integer keys; typed; docs updated; asserted |
| LOW, left: the ghost's words go stale while the pointer is still and a crew changes; the tunnel tool's own clearances refresh only on its events (P2's); `--` against `—` in the Dig tool's words (P2's own prompts use `--`); the mound's detail normal without UVs | Noted |

## Consequences

- **P4 fit-out** reads `FIXTURES`: bed alcoves at `FIX_BED`, empty hearth and table places, and the pantry
  shelf at the cellar's first `FIX_SHELF`. A "go home" task can route to a room's middle with `goal_node`,
  exactly as the probe's visit does. Residents arriving must stand at spread spots
  (`task_stand_in_bore`), or they block one another in the room.
- **P6 levels.** A room's level is a column already; level 2 needs only its rules and its view.
- **The navigation.** Rebuilds are sliced at about 1.5 ms a frame. A slice may run over by one circle, one
  node, the bucketing or the finishing step. In the village a class takes about 30–60 frames to rebuild.
  Plans made meanwhile route over the old graph but keep off new circles. Across several classes a rebuild
  can take 2 s or so at 60 fps. An incremental rebuild (re-ringing only the changed circles' neighbourhood)
  would end that window; it is left for when heaps and mounds change more often.

## Source

`docs/design/underground_revamp.md` §3 (room templates, headroom, mounds), §4 (room tools, ghost,
auto-passage), §8 P3 and §10 (Brendan's rulings: each home has its own front door in a turfed mound and a
tunnel connection; cellars have a hatch; the top-down section cutaway stands; homes ready for sleeping at
home in P4; rooms carry a level, only level 1 buildable). The GDD's starter dormitory (12 beds in 40 tiles)
and cellar store factor (350 per mille), as `underground_rooms.gd` cites them. MOVE-REQ-013 (levels), MOVE-REQ-018 (refusals in words).
