# 2001 — Mound homes: Surface rooms dug into a hill heaped to fit them

Date: 2026-10-15 · Status: Accepted as the plan. Brendan approved the mound mockup, "This looks good, let's build this
into the plan", relayed by the coordinator on 2026-10-15. He ruled P-2001-1 to P-2001-14 the same day ("Brendan's
rulings" below), and P-2001-15, the ground-height step, as "1/8 m" (a 128 u step). Docs only: no code.

Number range: 2001–2019, allocated to this lane by the coordinator. It was checked free on every local and remote ref
(`git ls-tree` over `refs/heads` and `refs/remotes`), and `docs/validation/decision_numbers.py` accepts four-digit
numbers above 2000. This is the plan record. The three BACKLOG packets it opens take 2002–2019 (§8). It replaces no
BACKLOG range.

## Brendan's words (2026-10-15, in chat to the coordinator, relayed)

In order. W1–W14 are this record's labels, used below to trace each rule.

| # | Words |
|---|---|
| W1 | "How would we incorporate the building into hillsides into this concept we have of grid/level building?" |
| W2 | "Is it possible to create the hill when building a certain style of room? Ie. I select a burrow-room (need a better name) and paint the grid, which when built also builds the hill that it is built into? And can these connect to underground (ie. Stairs in the home leading to underground levels)" |
| W3 | He chose "Phone mockup first". |
| W4 | "It's too boxy, especially the front and the frame. Does it make more sense to pile dirt, dig into the dirt, frame the build, then fix the top - to create more of a dynamic shape instead of a boxy shape?" |
| W5 | "When it builds we probably want the hill to match the size of the build we've done, then grow as we expand more rooms. Instead right now the hill is much larger than the built inside space" |
| W6 | "The door and windows should have to be manually placed by the user on the grid system, not auto generated. Similar to underground as well" |
| W7 | "Windows look bad in the artifact, they shouldn't have the channel. The window should exist on the edge of the hill against the wall." |
| W8 | "No recessing for windows, no channels and no flat faces, keep the mound the way it was and place the window on the turf slope" |
| W9 | He supplied four Bag End reference images: "These should be your inspirations" |
| W10 | "The windows would need to sit flat against the ground" |
| W11 | "The windows are also sitting too low, not at a natural height and blocked by bushes, etc…" |
| W12 | "The windows should be visible from the inside too, providing light" |
| W13 | Of the light-well shafts: "I don't like that. Let's make it so that the rooms are always on the edge of the mound that way there's no awkward gap between the mound and window" |
| W14 | "This looks good, let's build this into the plan" |

The earlier cozy-burrow discussion is context only.

- **W1 and W2 are questions**, and W3 is a choice of next step. They set the direction, but they are not rules by
  themselves.
- **W9 is a direction** for inspiration.
- **W4–W8 and W10–W13 shaped the design.** W14 approved the mockup's final state as the design.

## Brendan's rulings (2026-10-15)

Given in chat to the coordinator and relayed, on the questions of §6.

| Question | Ruling | What it means |
|---|---|---|
| P-2001-1, ground heights | **"Finer heights"**: (b), not the recommendation | Ground heights are finer than a metre, and slopes are real slopes. Walkers and haulers must handle them. The hill becomes real ground (BUILD-MOUND-006 adopted), blocked until MOUND-TERRAIN amends GDD §5.1. The step was ruled later the same day: 128 u (P-2001-15 (a), below) |
| P-2001-6, window height | **"Wall's top metre"**: (a) | A window lies on the slope just outside its wall, at the height of the wall's top metre, and lights the room through it (BUILD-MOUND-015) |
| P-2001-8, door front and colour | **"Our own, oak default"**: (a) | The approved elements stay as general burrow-home vocabulary. The art is our own: no centre knob, our own proportions, Redwall materials. Oak is the default colour; green, red and blue stay as choices |
| P-2001-2, -3, -4, -5, -7, -9, -10, -11, -12, -13 (all 13 items) and -14 | **"Approve all"**, as recommended | The name "Mound"; spoil as the heap's earth (free in the proof of concept); a 1 m cover and a 3-cell berm (see below); a 6-cell yard; no walking on the mound for the first slices; hills authored into the estuary preset; window daylight as presentation only for now; the proof of concept first; removal backfills and keeps the hill; the thirteen smaller rules, including windows underground only where a mound or hill face lies beyond the wall; and the build order as the mockup shows it |

**P-2001-15, the ground-height step: "1/8 m"**, (a), ruled later the same day (relayed by the coordinator). Ground
heights are integers in steps of 128 u. Today's land 512 u, ford −128 u and water 0 convert exactly. The step is ADR
1209's tread rise and the rounded walls' drawing step, and eight steps make one 1,024 u cut quantum. BUILD-MOUND-006
is unblocked as far as the step goes; it still waits for MOUND-TERRAIN's amendment of GDD §5.1.

**P-2001-4 under finer heights (reconciled at the coordinator's direction).** The recommendation was written for
whole-quantum ground: a 1 m cover, and a berm stepped 5 → 4 → 2 → 0 over 3 cells. Under P-2001-1 (b) the berm can be a
true slope. So P-2001-4 is recorded as **approved in intent**:

- a cover of 1 m (1,024 u) over each room;
- a berm footprint of 3 cells beyond each outer wall;
- the first cell outside a wall stands to the wall's top (4,096 u above the floor), so a wall is never open to the air.

The exact profile is drawn in the ruled 128 u step (P-2001-15 (a)) by MOUND-TERRAIN. It is drawn smooth.

**P-2001-6 checked under finer heights.** The recommendation's reasoning was that whole quanta force the first
outside cell to the wall's full height, so a window sits at least a cell out. Under finer heights that is no longer
forced by the ground's resolution. It is still forced by P-2001-4's approved intent: the first cell stands to the
wall's top, so a wall is never open.

So the reasoning holds, and the ruling stands. The slope reaches the wall's top metre just beyond the first cell,
and a window there lights the room through about a metre of earth, with no shaft. On the same 3-cell berm, the
mockup's 2.2 m window would sit about two cells out.

**What the rulings open.**

- **Movement on slopes (P-2001-1 (b)).** Walkers and haulers must handle real slopes. This opens work against
  SET-MOVE-001's gates; `docs/movement_direction_amendment.md` now notes it:
  - **MOVE-G01:** traversal profiles on slopes (limits by species, load and mode);
  - **MOVE-G02:** the height table's bytes, and route costs on slopes;
  - **MOVE-G03:** picking and ghosts on sloped ground;
  - **MOVE-G04:** walking and carrying clips on slopes;
  - **MOVE-G05:** slope fixtures and evidence.

  No slope limit is invented here.
- **Part-filled quanta.** With sub-metre ground, the top of a column of earth can end part-way through a 1 m³ cut
  quantum. MOUND-TERRAIN must state how such a quantum is dug, priced and counted, under ECON-002–005. That is
  engineering, with no ruling yet.
- **The step size** (P-2001-15, below; ruled "1/8 m", 128 u).
- **MOUND-POC is approved to build** (P-2001-11 (a)).

## Decision

A **Mound** is a **construction style**, not a room type. The player paints an ordinary room type (Kitchen, Bedroom,
Passage and the rest) on the **Surface** level and chooses the Mound style. The game heaps a hill that fits those
rooms, digs the rooms into it, frames them and tops the hill with turf. Doors and windows are items the player places
on the rooms' outer cell edges. A Way down placed in a Mound room leads to underground level 1. This is the answer to
W1 and W2.

For Mound-style rooms only, this is an exception to DEC-061 Q3's "walls and roof are generated from the painted
area". It is recorded as DEC-061's 2026-10-15 addendum in `docs/setting_decisions.md`. The rules are SET-BUILD-001 §12,
BUILD-MOUND-001 to -031.

**The design Brendan approved** (the mound mockup's final state, W14), each point traced to his words:

1. **The style** (W2, W14). Mound is a style chosen with a room type on the Surface. The room's purpose stays
   permanent (ADR 1081, BUILD-REQ-005). "Mound" is the working name (W2: "need a better name"; P-2001-2).
2. **Heap, dig, frame, top** (W4). This is the build order.
   1. **Heap.** Haulers pile and tamp earth into a heap.
   2. **Dig.** The rooms are dug into the heap like any dug room: the one claw stroke (decision 1971), the room
      foreman (decisions 1931–1933, on `feat/room-foreman-slice-c2`) and the rounded walls (decision 1914).
   3. **Frame.** This is the brace that ECON-002/003 install in every quantum before it is cut, with DEC-059's work.
      It is drawn as timber arch ribs, and it is not a second bill.
   4. **Top.** Thin cover is topped up to the cover rule, then turfed.

   How W4's four steps map onto the economy's phases is P-2001-14. The mockup heaps the whole hill first.
3. **The heap comes from the rooms** (W5, W13). There is no separately painted heap footprint. The heap is a
   smoothed union of the painted Mound rooms with a cover over them. From the rooms' outer walls it rolls down to the
   ground over a narrow berm. So **every Mound room sits at the hill's edge**, with no earth margin between a room and
   the open slope.
4. **The hill grows with the rooms** (W5). A new Mound room extends the heap only where the hill does not already
   cover it.
5. **The hill becomes real ground** (W2; P-2001-1 (b), "Finer heights"). The same ground data a natural hill uses,
   at heights finer than a metre. It needs MOUND-TERRAIN's change to GDD §5.1 first.
6. **Doors** (W6). The player places a door as a 2-cell-edge item on a room's outer edge, like the Furnish tab's door
   (decision 1921). Nothing is generated.
   - A small yard is cleared in front of each door.
   - The yard holds a small built front: plaster, timber posts, a curved timber eave with the turf carried over it, a
     round door ringed in brick, a lantern and stone steps (W9's inspiration, the mockup's final state).
   - A Mound with no door has no way in: "! No way in: place a door on an outer edge" (the mockup's words,
     BUILD-REQ-009).
7. **Windows** (W6, W7, W8, W10, W11, W12, W13). The player places a window as a 1-edge item on a room's outer edge.
   - It **lies flush on the turf slope**, tilted to the surface (W8, W10).
   - It sits at a **natural height, near the top of the wall** (W11). The mockup puts it where the slope is 2.2 m
     high, about 0.95 m out from its 3 m wall. That value is illustrative (P-2001-6).
   - It **never cuts, recesses, channels or flattens the mound** (W7, W8).
   - It **lights its room inside** (W12).
   - **Dressing never blocks it** (W11).
8. **Underground, the same way** (W6: "Similar to underground as well"). Underground doors are edge items placed by
   the player, never generated. A window goes only where there is a mound or hill face beyond the wall, never deep
   underground: the coordinator's reading of W6, ruled by "Approve all" (P-2001-13 item 12).
9. **A way down** (W2: "Stairs in the home leading to underground levels"; the mockup's section view; W14). A
   Way-down item (slice D's families: hatch with ladder, steep stair or ramp) placed on a Mound room's floor lands on
   level 1, 5,120 u down, as any Surface way down does (BUILD-REQ-015; SET-BUILD-001 §3 and §9). A connector may
   stand inside a Mound room, which changes §9 and §5.2 for this case (P-2001-13 item 13, ruled).
10. **Dressing** (W9, W11, W14). All of it is presentation:
    - a chimney on the hill above any Mound room with a hearth;
    - turf, shrubs and flowers, kept clear of windows;
    - a garden by the door: flower beds, a bench and a picket fence;
    - a tree on the crown;
    - a choice of door colour.

**DEC-010's boundary.** DEC-010 says "hobbit holes" "does not add Tolkien peoples, places, lore or copied film designs
to this Redwall setting". The round door ringed in brick, the plastered front under a curved eave, the lantern and the
garden all come from W9's Bag End images. The round green door with a centre knob is Bag End's signature. So the
approved look must be read as inspiration, and the game must make its own design and choose its own default door.
Brendan ruled it (P-2001-8 (a), "Our own, oak default"): our own design, no centre knob, oak by default.

## 1. What is ruled and what is not

As of Brendan's rulings of 2026-10-15.

| Item | Status | Source |
|---|---|---|
| Mound is a style, painted on the Surface with a room type; which types | Ruled | W2, W14; DEC-061 addendum; P-2001-13 item 10 |
| Mound rooms have no generated walls or roof (an exception to DEC-061 Q3) | Ruled | W4, W14; DEC-061 addendum |
| The name "Mound" | Ruled | P-2001-2 (a) |
| Heap → dig → frame → top, as the mockup shows it | Ruled | W4; P-2001-14 (a) |
| Heap computed from the rooms; no painted heap footprint | Ruled | W5 |
| The hill matches the rooms and grows as rooms are added | Ruled | W5 |
| Every Mound room at the hill's edge (no earth margin) | Ruled | W13 |
| Room height 4,096 u | Derived | DEC-054's 2026-10-15 addendum ("Rooms must fit every species") |
| A 1 m cover, a 3-cell berm, the first outside cell to the wall's top | Ruled in intent; the exact profile in 128 u steps is MOUND-TERRAIN's | P-2001-4 (a); P-2001-15 (a) |
| The finished heap is real ground, at heights finer than a metre | Ruled; blocked until MOUND-TERRAIN amends GDD §5.1 | W2; P-2001-1 (b) |
| The ground-height step: 128 u (1/8 m) | Ruled | P-2001-15 (a), "1/8 m" |
| Doors and windows are placed by the player as edge items, never generated | Ruled | W6 |
| Underground doors placed by the player, never generated | Ruled | W6 ("Similar to underground as well") |
| Underground windows only where a mound or hill face lies beyond the wall | Ruled | W6; P-2001-13 item 12 |
| The door's yard (6 cells wide to the berm's foot) and built front | Ruled | W9, W14; P-2001-5 (a), P-2001-8 (a) |
| Our own door design, no centre knob, oak by default | Ruled | P-2001-8 (a) |
| A window lies flush on the turf slope and never cuts the mound | Ruled | W7, W8, W10 |
| A window at the wall's top metre, just outside the first cell | Ruled | W11, W13; P-2001-6 (a) |
| A window lights its room, as presentation only for now | Ruled | W12; P-2001-10 (a) |
| Dressing never blocks a window | Ruled | W11 |
| A Way down in a Mound room leads to level 1; a connector may stand in the room | Ruled | W2, W14; P-2001-13 item 13 |
| Chimney, turf, shrubs, garden, tree, door colour; no bill | Ruled | W9, W14; P-2001-13 item 7 |
| Earth from spoil, tamped and recorded as BACKFILLED; free in the proof of concept | Ruled | P-2001-3 (a), (b) |
| No walking on the mound for the first slices; nothing dug into or built on the cover | Ruled | P-2001-7 (a); P-2001-13 item 9 |
| Hills authored into the estuary preset | Ruled | P-2001-9 (b) |
| A proof of concept first, free, drawn over unchanged ground | Ruled | P-2001-11 (a) |
| Removal backfills as underground and keeps the hill | Ruled | P-2001-12 (a) |
| The smaller rules of SET-BUILD-001 §12 | Ruled | P-2001-13, all thirteen items |
| Movement on slopes, and how part-filled quanta are dug | **Open engineering** | "Brendan's rulings" above; MOUND-TERRAIN |

## 2. How it fits the adopted model

Derived, with no new constant, except where marked as a proposal.

- **Grid and level.** Mound rooms are painted on level 0 on the 1 m cell grid (BUILD-REQ-001, -018). The 2 × 2 rule
  (BUILD-REQ-002), merging (BUILD-REQ-004, with BUILD-MOUND-002's one-style rule) and the room rules in cells
  (SET-BUILD-001 §4) all apply.
- **The floor.** A Mound room's floor is the ground it is painted on. Today that is land at 512 u, which is the level
  pack's datum (`initial_level_pack.json`: datum y 512 u). REQ-SET-122's terrain rules (BUILD-REQ-009) apply to the
  painted cells before any heap is raised.
- **The room height** is 4,096 u (4 quanta). DEC-054's 2026-10-15 addendum sets dug Rooms to that painted height:
  "Rooms must fit every species".
- **The heap's height.** With the ruled 1 m cover (P-2001-4), the heap stands 5,120 u above the floor at
  the walls. That equals the level spacing. The pack's domain runs from quantum −32 for 48 quanta, so it reaches
  quantum +15 above the datum. A heap of five or six quanta lies inside it.
- **Digging (ruled, P-2001-3 (a)).** A heap is earth above the datum. Under P-2001-1 (b) its surface is finer than
  a metre, so its top quantum may be part-filled (MOUND-TERRAIN's engineering).
  - The rooms are dug by the same 1 m³ brace/cut/finish rows (ECON-002/003, DEC-059's work).
  - Each heaped quantum is recorded as BACKFILLED. Cutting it then follows ECON-005's withdrawal branch and
    returns its 2,000 milli-U, so heaping and digging neither create nor lose earth.
  - ECON-002's tip compaction row (`ceil(q/4)` milli-WU) is the precedent for the tamping work. Earth tamped into a
    *tip* comes back only through the reclaim row, so the heap has its own source state.
- **Where the mole stands.** With the berm in place, the only wall face open at floor level is in the door's yard.
  The mole digs from there, striking the side face with decision 1971's wall rows, which strike a side face from a
  floor station. So a Mound needs its door before it can be dug (BUILD-MOUND-012), and needs no Entrance item.
- **No generated walls or roof.** A Mound room's walls are braced earth and its roof is the cover. So DEC-061 Q3's and
  BUILD-REQ-008's generated wall and roof, and §7.3's surface shell rate, do not apply to Mound rooms (W4: "dig into
  the dirt, frame the build, then fix the top"; the DEC-061 addendum).
- **Heat.** A Mound's rooms joined by open boundaries or interior doors are one room group for a hearth's 480 cells
  (SET-BUILD-001 §4). One hill is one roof, as one generated roof makes a roofed room group.
- **The protected roof.** The cover over a Mound room plays the part that the level pack's protected roof band
  (`protected_roof_band_u`, 1,024 u) plays over an underground room. Nothing should dig into it or build on it
  (P-2001-13 item 9; P-2001-7).
- **Doors.** BUILD-REQ-009 already requires a surface room to have a walk path to a door item on its group's outside
  boundary, and a Mound's door is that door. SET-BUILD-001 §10 already makes a door part of its room's project.
  §6's door rule wants walk cells on both sides of the door edge; decision 1921 E3 asks for dug floor on both sides.
  For an outside door, the yard's ground cells are the outside's walk cells (P-2001-13 item 11).
- **The way down.** Level 1's floor is at world y −4,608 u, 5,120 u below the land. That is the same drop as from
  any Surface entrance. A family whose geometry does not fit inside the room is refused with its reason (§9). For
  example the ramp's candidate slope (1:2.5, decision 0212) needs a run of at least 12,800 u.

## 3. Conflicts with adopted documents, and what this amends

- **DEC-061 Q3** ("walls and roof are generated from the painted area"). For Mound-style rooms only, this is set
  aside. W4 and W14 are the authority, recorded as DEC-061's 2026-10-15 addendum. Every other surface room keeps Q3.
- **GDD §5.1 (three surface heights).** The world has only land 512 u, ford −128 u and water 0
  (`world_init.gd elevation_y_units_of`). A heap that becomes real ground contradicts it.
  - **This record does not amend the GDD.** The change waits on P-2001-1 and lands in MOUND-TERRAIN, before any Mound
    is built as real ground.
  - The proof of concept draws the hill without changing the ground (§8).
- **DEC-054's 2026-10-15 addendum** fixes the room height at 4,096 u. This plan follows it. The mockup's 3 m rooms do
  not.
- **SET-BUILD-001** gains §12, "Mound homes", with BUILD-MOUND-001 to -031 (revision 1.1).
  - For Mound-style rooms it sets aside BUILD-REQ-008's generated walls and roof and §7.3's shell rate.
  - It proposes (P-2001-13 item 13) letting a Way-down item stand inside a Mound room. §9 places connectors on Surface
    cells or a Passage, and §5.2 lets a room hold only its key item and the shared fittings. Decision 1912 P-1912-2
    allowed a Way down in a room for the proof of concept only.
  - It proposes (P-2001-12) that a Mound room's removal backfills it, as underground (ECON-005, BUILD-REQ-007), not
    §7.5's surface demolition with a 50% return.
- **Underground doors after completion** (levels-and-connections D12, UG-LEVEL-025; furnishing UG-FURN-013). These
  are unchanged for underground rooms. A Mound room follows BUILD-REQ-009: its door can be placed in the same pending
  batch, because the room is not valid without one.
- **Decision 1921 E3** (a door needs dug floor on both sides). An outside door has its yard on one side. That is
  proposed as allowed (P-2001-13 item 11).
- **DEC-010's provenance boundary** (no copied film designs) applies to the door front, not only its colour (P-2001-8).
  DEC-010 ("styles of building into the ground (think burrows, hobbit holes)") and DEC-029 are otherwise served, not
  changed.
- **The Evil Genius 2 study §5** gains slice **M — Mound homes** and its dependency row.

## 4. The reference images (DEC-036)

On 2026-10-15 Brendan supplied four images of Bag End, saying "These should be your inspirations" (W9).

- **Where they are.** They are **not in the repository**; they were saved only in the session's uploads.
- **What is known.** Their creator, source and licence are unknown. The coordinator thinks they are probably film
  stills or fan art. That is a guess, and it does not belong in the provenance fields.
- **What they guided.** The mound mockup's design only: the yard before the door, the plastered front under a curved
  eave, the round door ringed in brick, the lantern and steps, the garden, the shrubs, the chimney and the tree. No
  pixel of them is in the mockup, which is drawn entirely by its own script.
- **Before any reference-guided generation** (image-to-image, image-to-3D, tracing or texturing), the images must be
  placed in the repository's reference folder with a provenance record. DEC-036: "Record input files/regions and
  transformations; keep unknown creator/edition/license fields unknown". That record is still to be written:
  - "supplied by Brendan, 2026-10-15, as inspiration";
  - creator, edition and licence: unknown.
- **DEC-010's boundary still applies.** The images inspire a Redwall burrow home. They do not license copying a film's
  designs (P-2001-8).
- **Paid generation** stays a separate, itemised approval (README §3.8, decision 0961). Nothing here approves any
  spend.

## 5. The mockups

| Mockup | Live | Committed copy |
|---|---|---|
| Mound home (the approved design, W14) | https://claude.ai/artifact/EQ31p3ZtSQ42KU8EvA7GVt | [`mound-home-3d.html`](../design/underground-planning/mockups/mound-home-3d.html) |
| Rounded burrow walls (decision 1914's source) | https://claude.ai/artifact/Gf55LFe2j2wfMTPeGV7hoC | [`burrow-walls-3d.html`](../design/underground-planning/mockups/burrow-walls-3d.html) |

Their scripts are the reference geometry. Their values are illustrative, and several differ from adopted rules.
Production must not copy these values.

- **Room height.** The mockup digs rooms 3 m deep (`CUT = 3.0`). The adopted height is 4,096 u (DEC-054's addendum).
- **Cover.** `COVER = 1.0` m over the rooms. The crown rises up to 1 m more over the 3.5 m inside the outer walls,
  plus a 0.12 m wobble.
- **Berm.** `EDGE_L = 3.6` m, measured in the smooth-min distance, with an exponential fall-off. At the two default
  windows the heap reaches the ground about 3.95 m from the wall (recomputed from `heapH`).
- **The yard.** The heap is cleared within 3.3 m of the door's centre line on each side, blending out over 2.2 m more,
  and 5.5 m out, blending out over 2.0 m more. The picket fence stands 5.6 m out.
- **The window.** `WIN_H = 2.2`: the first point outward from the wall edge where the slope is 2.2 m high. With the
  mockup's 3 m room that is 0.95 m out from the wall (recomputed for both default windows). The coordinator's notes
  said about 0.5 m; 0.95 m is correct.
- **Shrubs.**
  - They keep 2.6 m from a window, and out of a strip 2.2 m to each side of it, from 1 m behind it to 6 m out.
  - In front of a door they keep out of a strip 4.5 m to each side, from 0.5 m behind it to 6 m out.
  - They grow only where the slope is 0.2–1.1 m high.
- **The 2 × 2 rule.** The two links between the hall and its neighbours are one cell wide. That breaks BUILD-REQ-002.
- **The heap's shape.** The heap is a smooth-min of whole room boxes. Decision 1914 E1 found that a smooth-min over
  cells ripples, and used the distance to the cells instead. Production should do the same.
- **Outer edges.** An outer edge is a room cell edge whose other side is not in any room (`buildEdges`). A door takes
  two neighbouring outer edges facing the same way.
- **The section view** shows a steep stair to a level-1 cellar 5.12 m down. Its 9 treads are a drawing, not a
  qualified flight (SET-BUILD-001 §9, OPEN-10).
- **Leftovers.** `M.shaft` (from the rejected light wells) and `SLOPE` are unused.

## 6. Questions for Brendan

P-2001-1 to P-2001-14 were ruled on 2026-10-15 ("Brendan's rulings" above); they are kept here as asked.
P-2001-15 was added after those rulings and ruled the same day (below).

Each question gives options and a recommendation. **Do not invent the values.** Where the mockup has a number, it is
the candidate to test, not a ruling.

**P-2001-1 — Ground heights in the world (the main prerequisite).** Today the surface has three heights (GDD §5.1).
A heap that becomes real ground, and any natural hill, needs a height per place.

- **(a) Recommended: stepped whole-metre heights, drawn smooth.**
  - Each 1 m cell's ground is the top of its highest solid quantum. Heights are whole quanta (1,024 u) above the
    datum, on the same lattice the digging uses.
  - The drawing smooths between steps. That is presentation only, as with the rounded walls (decision 1914).
  - GDD §5.1 changes: land gets a height per cell, while water and the ford keep theirs. REQ-SET-122's slope and
    spread rules (and BUILD-REQ-009, which restates them) then read real heights.
  - Walking up and down steps needs movement rules (MOVE-G01; P-2001-7). A height per cell over the 256 × 256 surface
    cells needs a memory row (MOVE-G02).
- **(b)** Finer heights, below a metre. Slopes are smoother, but every rule that reads ground (placement, movement,
  digging) must handle part-quanta, which the 1 m³ cut quantum does not have.
- **(c)** Keep three heights, and make the hill a structure drawn as a hill. Natural hills then stay impossible, and
  the hill is not "built into" in the sense W2 asks.

**P-2001-2 — The style's name.** Brendan asked for "a better name" than "burrow-room" (W2).

- **(a) Recommended: "Mound".** It says what the player sees, and it is the working name in the mockup and here.
- **(b)** "Bankhouse": a house set into a bank.
- **(c)** "Hollow". "Holt" is avoided: it is already one of the GDD's three architecture kits (Abbey, Holt, Fortress).

**P-2001-3 — Where the heap's earth comes from, and its price.**

- **(a) Recommended for the real game: spoil.**
  - The heap uses stored `excavated_earth`, hauled and tamped, with ECON-002's tip compaction row as the precedent
    for the tamping work.
  - Each heaped quantum is recorded as BACKFILLED, so cutting the rooms back out returns 2,000 milli-U per quantum
    (ECON-005's withdrawal branch). The earth a Mound really uses is then its cover, crown and berm. For example, one
    4-quantum room cell with a 1-quantum cover takes 5 quanta heaped (10,000 milli-U) and gives 4 back (8,000
    milli-U).
  - The dig is priced as SET-BUILD-001 §7.2 prices any painted cell.
  - With too little earth in store, the heap waits with "! Blocked: needs earth" (BUILD-MOUND-031).
- **(b) Recommended for the proof of concept: free**, like decision 1912's "Free for now". The ledger shows the bill;
  nothing is deducted.
- **(c)** A borrow pit: the player marks ground to dig for earth, which leaves a pit.

**P-2001-4 — Cover depth and berm shape.** The room height is fixed at 4,096 u (DEC-054's addendum). The mockup's
cover (1 m plus a crown) and berm (3.6 m) were drawn for looks. The berm decides where a window can sit
(P-2001-6). Answer the two questions together.

**A constraint on whole-quantum ground** (P-2001-1 (a)). A Mound room's walls are braced earth (BUILD-MOUND-009).
So the first cell outside an outer wall must stand at least as high as the room, 4 quanta. Otherwise the top of the
wall would open onto the air. The mockup's thin, sloping earth beside the wall top cannot be built from whole quanta.

- **(a) Recommended: a one-quantum cover, and a berm steep near the wall.**
  - **Cover:** one quantum, 1,024 u. It is the level pack's `protected_roof_band_u`, an adopted value, and it matches
    the mockup's 1 m. The crown above it is presentation.
  - **Berm:** 5 quanta over the room, 4 in the first cell outside the wall, then two quanta down per cell (2, then 0).
    That is a 3-cell berm, drawn smooth: the mockup's profile on whole quanta.
- **(b)** 4 quanta in the first cell, then one quantum down per cell (3, 2, 1, 0): a 5-cell berm. It is gentler and
  better for shrubs, but uses more earth and land.
- **(c)** Finer ground heights (P-2001-1 (b)), so that the earth beside the wall can thin as the mockup's does.

**P-2001-5 — The door's yard.** The mockup clears the heap 3.3 m to each side of the door's centre line and 5.5 m out.

- **(a) Recommended:** the door's 2 cells plus 2 cells to each side (6 cells wide), out to the berm's foot, at ground
  height.
  - Placed before Confirm all, the yard is simply never heaped, so no earth is wasted.
  - Placed later, it is dug.
  - The garden beyond it is dressing on flat ground.
- **(b)** The mockup's fixed 6.6 m × 5.5 m. That is not whole cells.
- **(c)** The player paints the yard as an outdoor area.

**P-2001-6 — The window height rule.** On whole-quantum ground, the first cell outside a wall stands the room's full
height (P-2001-4). A window flush on the slope therefore sits at least a cell out from its wall. Its height decides
how much further out it goes.

- **(a) Recommended: the window lies on the slope just outside the first cell, at the height of the wall's top
  quantum** (about 3–4 m above the floor). It lights the room through that one metre of earth: one cell, with no
  shaft.
  - Against the wall, that is about where the mockup's window sits (2.2 m on a 3 m wall).
  - It is "near the top of the wall" (W11), and the earth between window and room is only the wall's own top (W13).
- **(b)** A fixed height above the floor (the mockup's 2.2 m, near the door's top). On P-2001-4 (a)'s berm that lands
  about 2 cells out. That is the kind of gap W13 rejected, unless P-2001-4 (c)'s finer heights are chosen.
- **(c)** A fixed distance from the wall (the mockup's is 0.95 m). This needs P-2001-4 (c).

**P-2001-7 — Can residents walk on the mound?**

- **(a) Recommended for the first slices: no.** The hill is the rooms' protected roof. Residents walk round it, and
  the turf, tree and chimney stand on it.
- **(b)** Yes, once P-2001-1 (a)'s steps have movement rules (MOVE-G01). Nothing may be built on or dug into the cover.
- **(c)** Only along a path item placed up the hill.

**P-2001-8 — The door front and its default colour, under DEC-010.** The approved look (W9, W14) borrows from Bag
End: the round door ringed in brick, the plastered front under a curved eave, the lantern and the garden. The mockup's
first door colour is green, and a round green door with a centre knob is Bag End's signature. DEC-010 forbids "copied
film designs".

- **(a) Recommended: keep the approved elements as general burrow-home vocabulary, and make the art our own.**
  - The art makes its own design: no centre knob, its own proportions, and Redwall materials.
  - The default colour is oak (natural timber). Green, red and blue stay as choices.
  - The DEC-061 addendum records that W14 approves this inspiration within DEC-010's boundary.
- **(b)** A door shape and colour chosen per scenario's architecture kit (Abbey, Holt, Fortress).
- **(c)** Keep the mockup as it is, with a green default. Not recommended under DEC-010.

**P-2001-9 — Natural hills.** W1 asks about "building into hillsides".

- **(a)** World generation adds hills using P-2001-1's ground heights. A Mound room painted against a hill heaps
  earth only where the hill does not already cover it (BUILD-MOUND-004 already says so).
- **(b) Recommended: author a few hills into the estuary preset.** The GDD's shipping map is "a deterministic
  authored estuary preset", so authoring fits it better than random hills. It uses the same data and rules as (a), and
  comes after MOUND-TERRAIN.
- **(c)** No natural hills; only Mounds make hills.

**P-2001-10 — Window daylight as a game rule.** The GDD has no light term. Comfort targets come from room type,
heat, upgrades and decoration (+250, capped at 1,000).

- **(a) Recommended for now: presentation only.** The room is drawn lit, with no rule effect.
- **(b)** Later, a comfort input. For example, a lit room's comfort target is raised like a decoration. That is a
  GDD §5.9 change, and it needs its own question with numbers.
- **(c)** A penalty for windowless rooms. Not recommended: underground rooms would all pay it.

**P-2001-11 — A proof of concept first.**

- **(a) Recommended: yes, in the demo, free, drawn first** (MOUND-POC). It works like decision 1912's:
  - paint Mound rooms on the Surface;
  - a resident heaps, digs and tops them;
  - place doors and windows on edges;
  - the hill grows;
  - a hatch leads to level 1.

  The hill is drawn over the unchanged ground, and nothing is saved. UG24's "never show unpaid work as done" would be
  knowingly waived again until MOUND-REAL.
- **(b)** No. Wait for MOUND-TERRAIN and slices C3, D, E and G, and build it once, for real.

**P-2001-12 — Removing a Mound room.** SET-BUILD-001 has two removal rules: underground cells are backfilled
(BUILD-REQ-007, ECON-005), and surface cells are demolished for a 50% return (§7.5). A Mound room is dug, like an
underground room.

- **(a) Recommended: backfill the room as underground, and keep the hill.** BUILD-REQ-006's review comes first, then
  each open quantum is backfilled with earth (ECON-005). The hill is ground now, and it stays.
- **(b)** Backfill, then take the heap down wherever no other Mound room's cover or berm needs it. The earth is
  reclaimed by ECON-002's reclaim row. The hill keeps matching the rooms (W5), but it costs more work.
- **(c)** Treat it as §7.5's surface demolition (a 50% return of what was paid).

**P-2001-13 — The smaller rules in SET-BUILD-001 §12 marked PROPOSAL.** Approve as a group, or pick out any one.

1. **One style per room.** A stroke of one style that touches a same-type room of the other style is refused: "Not
   possible: a Mound room cannot join a built room; leave a cell between them" (BUILD-MOUND-002).
2. **When doors and windows are placed.** They can go in the same pending batch as their rooms, or later on a
   finished room's outer edge from the Furnish tab. A door added later digs its yard then (BUILD-MOUND-010, -011,
   -013).
3. **An enclosed room.** A Mound room with no outer edge, because other Mound rooms surround it, is allowed. It can
   hold no window and no outside door. The literal reading of W13 ("the rooms are always on the edge of the mound")
   would refuse it instead (BUILD-MOUND-005).
4. **The ground under the heap.** The whole heap, berm included, must stand on land clear of water, the ford,
   resource nodes, fields, items, outdoor items and any room outside this Mound. REQ-SET-122 and ECON-004's tip siting
   are the precedents. Otherwise: "Not possible: the hill would cover <thing>" (BUILD-MOUND-008).
5. **An edge that stops being an outer edge.** If a new room covers an outer edge that holds a window or a door, that
   window or door is listed in the removal review (BUILD-REQ-006) (BUILD-MOUND-018).
6. **The window item.** A window is a new edge item, one cell edge long. Its bill, art and catalog entry are still to
   be authored in slice E, from a placeholder as OPEN-02 (a) did. It is free in the proof of concept
   (BUILD-MOUND-013).
7. **Presentation has no bill.** The door's built front, turf, shrubs, flowers, garden, tree and chimney carry no bill
   and decide nothing (BUILD-MOUND-023).
8. **The refusal words** in BUILD-MOUND-028, -030 and -031, besides those in -002 and -008.
9. **Nothing on the cover.** Nothing may be dug into or built on a Mound room's cover (BUILD-MOUND-026). Walking on
   it is P-2001-7.
10. **Which room types take the style.** Every type the Surface allows, except a type whose own rule a heap defeats.
    For example, a BOATHOUSE must touch the shore, but a heap may not cover water (BUILD-MOUND-001).
11. **The outside door's walk cells.** The yard's ground cells count as the walk cells outside the door, in place of
    the dug floor decision 1921 E3 asks for (BUILD-MOUND-010).
12. **Windows underground.** A window goes only on an outer edge of a Mound room, or later on a wall with a hill face
    beyond it. It never goes on an underground edge buried in earth: "Not possible: a window needs a mound or hill
    face beyond this wall". This is the coordinator's reading of "Similar to underground as well" (W6), and needs
    Brendan's word (BUILD-MOUND-020).
13. **A Way down inside a room.** A Way-down item may stand on a Mound room's floor (amending §9's "Surface cells or
    a Passage" and §5.2's allowed items for this case), as decision 1912 P-1912-2 allowed in the proof of concept
    (BUILD-MOUND-021).

**P-2001-14 — What "pile dirt, dig into the dirt, frame the build, then fix the top" means for the work.** The
economy braces each quantum before it cuts it (ECON-003). So "frame" cannot be a separate step after digging, as W4's
order reads.

- **(a) Recommended: as the mockup shows.**
  - Heap the whole hill, cover included.
  - Dig the rooms: each quantum is braced and then cut, and the braces are drawn as the frame once a cell is open.
  - Top up thin cover, and turf.
- **(b) Cut-and-cover, W4 read literally.**
  - Heap only to the rooms' height, and dig the rooms open from above (the claws' down stroke, M1).
  - Frame the open rooms with ribs: a new roof-frame item and bill.
  - Lay the cover over the frame, then turf.

  This is closer to W4's words, but it needs a roof-frame recipe the economy does not have.

**P-2001-15 — The ground-height step (new, after P-2001-1 (b)).** Ground heights are finer than a metre. They stay
integers (AGENTS.md: integer authoritative state), so they need a step.

- **(a) Recommended: 128 u (1/8 m).**
  - Today's three heights (land 512 u, ford −128 u, water 0) are all multiples of it, so the current map converts
    exactly.
  - It is the rise of ADR 1209's treads, the only qualified descent (128 u per 512 u run, SET-BUILD-001 §9).
  - It is the rounded walls' drawing step (decision 1914 E4, 0.125 m).
  - Eight steps make one 1,024 u cut quantum.
- **(b) 256 u (1/4 m).** Coarser and fewer slope cases, but the ford's −128 u is not a multiple and would move.
- **(c) 1 u (any integer height).** The finest, but every check (placement slope and spread, cover, part-filled
  quanta) works on arbitrary values.

Whatever the step, MOUND-TERRAIN budgets the height table (MOVE-G02) and states how part-filled quanta are dug.

**Ruled 2026-10-15: "1/8 m"**, (a), 128 u ("Brendan's rulings" above).

## 7. The slice

The Evil Genius 2 study §5 adds slice **M — Mound homes**, with three parts:

- **M0, MOUND-TERRAIN:** the ground-heights amendment and its data.
- **M1, MOUND-POC:** the demo's proof of concept. It can come first, like decision 1912's.
- **M2, MOUND-REAL:** the real pipeline.

The real Mound needs these slices:

- B and C (real digging, C3);
- D (doors and the way down as items, the entrance family);
- E (edge items, including the window);
- G (Surface rooms);
- H (polish).

It also needs the ground-heights amendment and a heap earthwork job (haul and tamp).

## 8. The packets (`docs/handoff/BACKLOG.md`, Part 9)

| Packet | What | Needs | Decisions |
|---|---|---|---|
| MOUND-POC | Demo proof of concept: paint, heap, dig, top, doors and windows, growth, hatch to level 1. Drawn first, free, unsaved | Approved (P-2001-11 (a)); the merged painted-room proof of concept (1912, 1913, 1914, 1921) | 2002–2009 |
| MOUND-TERRAIN | The finer ground-heights amendment (GDD §5.1, REQ-SET-122 and BUILD-REQ-009) in 128 u steps, movement on slopes against MOVE-G01–G05, part-filled quanta, and the data | P-2001-1 (b) and P-2001-15 (a) ruled | 2010–2014 |
| MOUND-REAL | The real pipeline: heap earthwork job, dig through the room foreman, frame, top, doors, windows and the way down | MOUND-TERRAIN; slices C3, D, E and G (its rulings are in) | 2015–2019 (more from the coordinator if needed) |

## Consequences

- MOUND-POC is approved to build (P-2001-11 (a)). MOUND-TERRAIN is ruled: finer heights in 128 u steps (P-2001-1
  (b), P-2001-15 (a)). MOUND-REAL waits on MOUND-TERRAIN and slices C3, D, E and G.
- No Mound may be built as real ground until MOUND-TERRAIN amends GDD §5.1. Until then a Mound is drawn, not ground.
- Finer heights open movement work on slopes against MOVE-G01–G05. No slope limit may be invented to close it.
- The mockup's numbers are candidates. A lane that uses one must cite the question that fixes it.
- A later ruling on any P-2001 item is written into this record under "Brendan's rulings (date)", into SET-BUILD-001
  §12's status column, and into DEC-061's addendum where it is a policy ruling.

## Review

An independent `code-reviewer` read the change before commit. It found two CRITICAL and eleven HIGH problems, and all
were fixed in this revision:

- **C1.** The underground window rule had been marked as ruled. It is now a proposal (P-2001-13 item 12).
- **C2.** The DEC-061 Q3 exception was not recorded at rank 1. DEC-061 now has its addendum, and SET-BUILD-001's
  header names it.
- **H1.** The window lies 0.95 m from the wall in the mockup, not 0.5 m.
- **H2.** P-2001-4 and P-2001-6 are now consistent with each other. A re-check found that the first cell outside a
  wall must stand the room's full height on whole-quantum ground, so the window recommendation now sits on the slope
  just outside that cell, at the wall's top quantum.
- **H3.** "Real ground" is now a proposal.
- **H4.** The heap's economy is a proposal, with a BACKFILLED source state.
- **H5.** The build-order mapping is now P-2001-14.
- **H6.** The Way down inside a room is a named change (P-2001-13 item 13).
- **H7.** The room height is derived from DEC-054's addendum.
- **H8.** DEC-010's boundary now covers the door front (P-2001-8).
- **H9.** The outside door's walk cells are now a named proposal (P-2001-13 item 11).
- **H10.** The yard timing is split out as a proposal.
- **H11.** The cross-references and refusal words are made consistent.

Its MEDIUM and LOW points were also taken:

- the heap's ground rule now names "any room outside this Mound";
- BUILD-REQ-012 is cited "as for underground cells";
- the mole digs from the door's yard;
- §7.5 versus backfill is named (P-2001-12);
- the refusal words are split into separate rows;
- the furnishing pointer is corrected;
- the room-type scope is a proposal;
- the provenance fields stay "unknown";
- the brace is cited to ECON-002/003;
- BUILD-REQ-009 is cited beside REQ-SET-122;
- decision 1933's refusal is marked as being on its branch.

## Source

- Brendan's words W1–W14, 2026-10-15, relayed by the coordinator; `docs/handoff/LIVE_WORK.md`, the 2026-10-15
  entries (in the main checkout; not committed).
- DEC-010, DEC-029, DEC-036, DEC-054 with its 2026-10-15 addendum, DEC-059, and DEC-061 with its 2026-10-15 addendum
  (`docs/setting_decisions.md`).
- SET-BUILD-001 (`docs/building_model_amendment.md`); SET-MOVE-ECON-001 ECON-002–005
  (`docs/underground_economy_hazard_amendment.md`); GDD §5.1 and §5.9 (`docs/game_gdd.md`).
- Decisions 1851, 1871, 1880, 1911, 1912, 1913, 1914, 1921 and 1971, and decisions 1931–1933 (on
  `feat/room-foreman-slice-c2`).
- `godot/data/underground/initial_level_pack.json` (datum, domain, clear height, roof band) and
  `godot/scripts/core/world_init.gd` (`elevation_y_units_of`).
- The two mockups' scripts (§5). The window distance and the berm's foot were recomputed from `heapH` and
  `slopeSpot` with a scratch script.
