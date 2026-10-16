# 2002 — Mound homes: the proof of concept in the demo

Date: 2026-10-15, amended 2026-10-16 · Status: Accepted (Brendan, 2026-10-15: "yes, start the Mound proof of
concept"; P-2001-11 (a)). His rulings of 2026-10-16 are below: the hill's shape, and every PROPOSAL approved

Number range: 2002–2009, allocated to this lane (MOUND-POC) by the coordinator; checked with `decision_numbers.py` and
over every ref. This is the lane record; 2003–2009 are unused.

## Decision

Decision 2001's **Mound homes** now work in the demo as a proof of concept, on top of the painted-room loop of decisions
1912, 1913, 1914 and 1921, as P-2001-11 (a) ruled it: **in the demo, free, drawn over unchanged ground, unsaved**.

- **Style.** The build panel's Rooms tab has two toggles after its tabs, **Built** and **Mound**. On the Surface room
  types paint in the Mound style; below, in the Built style; the other style's cards are locked and say why
  (BUILD-MOUND-001, -028).
- **Heap.** The hill is worked out from the confirmed Mound rooms alone and grows as rooms are added (BUILD-MOUND-003,
  -004, -005). It goes through the ruled stages, heap → dig → frame (timber ribs) → top (turf and dressing)
  (BUILD-MOUND-007; P-2001-14 (a)). The dug rooms reuse decision 1914's rounded-walls field.
- **Doors and windows** are Furnish-tab items: the **Front door** on two outer edges side by side, the **Window** on
  one. Each is placed, taken back and removed with its validity in words (BUILD-MOUND-010, -013, -029, -030).
  - A door keeps a 6-cell-wide yard to the berm's foot, with its built front. The door is our own design: no centre
    knob, oak by default, green, red and blue as choices (BUILD-MOUND-011; P-2001-5 (a), P-2001-8 (a)).
  - A window lies flush on the turf slope at the wall's top metre. It never cuts the hill, and by day it lights its
    room inside. Dressing never blocks it (BUILD-MOUND-014–017; P-2001-6 (a)).
- **No way in.** A Mound with no door says "! No way in: place a door on an outer edge" on every cell, and Confirm all
  waits (BUILD-MOUND-012).
- **Way down.** The Entrance card placed on a Mound room's floor is its hatch: "Way down, connects to Underground
  level 1". It lands on level 1, and residents reach it through the door (BUILD-MOUND-021).
- **Dressing.** A finished hill grows turf, shrubs on its lower slope, a tree on its crown and a chimney over each
  fitted hearth. Flower beds, a bench and a picket fence stand by the door (BUILD-MOUND-022, -023).
- **The work.** One resident does it, in the proof of concept's simple way (decision 1912). Nothing is charged and
  nothing is saved.

The rules and words are in `godot/scripts/ui/`: `build_mound.gd`, `build_mound_edges.gd`, and the batch's MOUND HOMES.
The store, the builder and the drawing are in `godot/demo/build_panel/demo_build_mound*.gd` and `build_mound.gdshader`.
No core simulation owner is touched: `scripts/core/` and the settlement systems are unchanged. MOUND-TERRAIN and
MOUND-REAL replace the drawing with real ground and the settlement's own work.

## Brendan's rulings (2026-10-16)

Given in chat to the coordinator on the proof of concept's frames, and relayed.

| Question | Ruling | What it means |
|---|---|---|
| The hill's shape | **"Rounder, like the mockup"** | The finished side view read as a flat-topped ridge with steep sides, from the 3-cell berm (5 m over 3 m). The hill takes the approved mockup's domed crown and a smoother, wider fall-off of about 4 cells (its `heapH`, `edgeFall` and the crown's `q` term). The rules stay: the first cell outside a wall stands to the wall's top, so no wall is ever open; windows stay at the wall's top metre; the yard is 6 wide. **This amends P-2001-4's 3-cell berm to about 4 cells** (noted in decision 2001, BUILD-MOUND-003 and `docs/handoff/RULINGS.md`). Built as E6 and E8 now describe |
| P-2002-1 to P-2002-9 | **"Approve all"**, as recommended | Each (a) below, including P-2002-9 (a): no room within 2 cells of a yard's side and no window within 3; no cheek walls |

## What was built

| Part | File | What it does |
|---|---|---|
| Rules and words | `scripts/ui/build_mound.gd` | Edges, outer edges, a door's two edges, the yard, the heap's footprint, Mounds as joined rooms, the ruled words |
| Pending doors and windows | `scripts/ui/build_mound_edges.gd` | Packed rows, live flags for Undo; `judge` says where one may stand |
| The batch | `scripts/ui/build_batch.gd` | The stroke's style, the per-cell "No way in", the hill's ground, a way down on the hill, edges as Undo steps, Confirm all's `submit_edge` |
| The panel and catalog | `build_panel.gd`, `build_catalog.gd` | Style toggles, the Front door and Window cards, the colour strip, the ledger's lines |
| The store | `demo_build_mounds.gd` | Each cell's stage; confirmed doors and windows (early or late, fitted) |
| The job order | `demo_build_mound_jobs.gd` | The builder's next job, worked out from the store |
| The builder | `demo_build_mound_task.gd` | One resident: from the yard, or inside behind a stand-in figure |
| The hill | `demo_build_mound_field.gd`, `_hill.gd`, `_mesh.gd`, `build_mound.gdshader` | The heights, the two looks and the meshes |
| The parts | `demo_build_mound_front.gd`, `_parts.gd` | The front door, windows, ribs, hatch and dressing |
| Showing it | `demo_build_mound_view.gd`, `_marks.gd` | The hill whole or cut away, lights, words, door and window slots |
| The ground | `demo_build_mound_ground.gd` | What a hill would cover, read from the village; the scenery it hides |
| The host | `demo_build_mound_host.gd` | Owns the above for `demo_build.gd`; Confirm all's routes; residents walk round the hills |

`demo_build_works.gd` and `demo_build_fittings.gd` now take level 0 (the Surface's Mound rooms and their furniture).
`demo_build_below_task.gd` goes down a given way from a given site, and `cast_space.gd` stands the hills as obstacles.

## Engineering choices

- **E1 — The style follows the level.** Mound on the Surface and Built below, chosen automatically when the level
  changes. The other toggle can be pressed to read why its cards are locked: "! Not yet: built rooms on the surface come
  in a later update; choose the Mound style", or "X Not possible: Mound rooms are painted on the Surface". So the
  batch's -002 refusal cannot be reached from the panel until slice G puts built rooms on the Surface (P-2002-1). Its
  test sets a room's style directly, as slice G would let it be.
- **E2 — A Mound is its rooms joined cell to cell**, pending and confirmed together.
  - Its way in is a door, pending or confirmed, on any of its rooms' outer edges. A pending removal takes a door away.
  - While it has none, every pending cell carries `CELL_NO_DOOR`: "! No way in: place a door on an outer edge". It
    replaces the underground's connector way in, which the Surface does not judge (`judge_level(..., way_in = false)`).
  - It is "!", not "X": the stroke is kept and Confirm all is held back, as BUILD-REQ-013's "No way in" is.
- **E3 — Edges.** An edge is (x, z, side): 0 north, 1 east, 2 south, 3 west. A door's second edge is the next one
  along: east for a north or south wall, south for an east or west wall.
  - The pointer picks the outer edge nearest the ground point. A door runs on from it, or back when the pointer is on
    the near half and that fits, or when only that fits.
  - Enter places one at the cursor cell, on the side R / Shift+R names, as decision 1921 E3 does.
  - A click on a pending one takes it back; a click on a built one asks for its removal (Confirm all carries it out).
    Each is one Undo step (`MOUND_TAG` 3 << 24; taking back is `VERB_REMOVE`).
- **E4 — Where a door or window may stand** (`build_mound_edges.gd judge`), in this order:
  - Off the Surface: a window is refused in BUILD-MOUND-020's words, a door in -030's.
  - Its first edge not outer: -030's words. Its second edge not outer, or taken: -029's.
  - An edge already holding a door or window, pending or confirmed (P-2002-2).
  - A door's YARD KEEP with a room in it: the yard, a cell past its foot and two cells either side. A room there would
    have a wall open onto the cut, since the yard's sides fall at 2 m a metre and the hill beside it stands under the
    wall's top for two cells (P-2002-2).
  - A window within three cells of a yard's side, or a door whose zone takes a window's slope. The slope there is cut
    below the window's height, and the garden and fence stand there (P-2002-2).
  - A window with another room within the berm beyond it: the hill never falls to the window's height in so narrow a
    gap, so there is no slope to lie on (BUILD-MOUND-020's words).
- **E5 — The yard** (P-2001-5 (a)): the door's two cells and two more each side, out to the berm's foot: four cells
  since the 2026-10-16 ruling.
  - A door confirmed with its rooms (EARLY) has its yard never heaped.
  - A door added to a heaped hill has its yard cut when it is fitted (P-2001-13 item 2).
- **E6 — The heap's footprint**: every cell within the berm, gx² + gz² < 16 (4 cells, rounded at the corners; 3 cells
  and gx² + gz² < 9 before the 2026-10-16 ruling). Each
  Mound's rooms and footprint are checked against the village (`demo_build_mound_ground.gd`):
  - water, read at the cell's middle and at four points 0.2 m inside its corners, so a shoreline cell is judged by
    what lies in it;
  - trees (resource nodes), buildings, and items or outdoor items standing in the open, read from their blocking
    circles or where they stand;
  - a way down not wholly on one room's floor: across a wall it is "split", on the berm it is "on the hill".

  Refusals use BUILD-MOUND-008's words ("Not possible: the hill would cover water"). The woods' scenery (rocks, a
  boulder, a fallen log, a mossy stump) is heaped over and hidden (P-2002-3).
- **E7 — A room by a door or window.** A stroke whose room would cover the slope beyond a confirmed door or window is
  refused in words: "this would cover the Window on a room's outer edge; remove it first". This stands in for
  BUILD-MOUND-018's removal review, which needs BUILD-REQ-006 (slice F). A stroke into the yard keep of any door that
  will stand, pending or confirmed, is refused too ("a door's yard and the ground beside it stay clear of rooms").
  Both are judged again on every pending Mound room whenever a door or window changes, so withdrawing a removal
  under a new room makes that room "X" and holds Confirm all back.
- **E8 — The hill's heights** (`demo_build_mound_field.gd`, presentation over unchanged ground):
  - **Cover:** the wall's top (4 m, 4,096 u) and the ruled 1 m cover. The mockup's crown adds 1 m over the 3.5 m
    inside the outer walls, with a fixed wobble of ±0.12 m on the crown only, so the cover is never thinner than the
    rule. Since the 2026-10-16 ruling the crown is eased out, 1 − (1 − t)², so it rises from the wall itself. The
    mockup's smoothstep (its `q` term) suits its wide rooms. A 4-cell-deep Mound never gets past 0.65 m of it, and that
    is what made the top read flat; eased out, the same room's crown reaches 0.82 m in a dome.
  - **Berm** (the 2026-10-16 ruling, "Rounder, like the mockup"): a smooth fall over about 4 cells. It is half a
    cosine, from a top 0.25 m inside the wall to the ground 4 m out, so it is already falling at the wall, continuing
    the crown's dome, and eases out at its foot. The heights a metre apart are 5.0, 4.04, 2.29, 0.66 and 0 m, and the
    cross-section reads as one dome from foot to foot.
    - The first metre out stands above the wall's top (P-2001-4's intent: a wall is never open), and no earth lies
      past the berm (W13).
    - The mockup's own curve, exp(−(d / 1.25 m)^1.6), would leave a wall's top metre open a metre out on a 5 m hill,
      so the fall is widened.
    - A bell curve level at the wall was tried first. It kept a flat band along the walls, so the top still read flat.
    - Before the ruling the berm was level for 0.35 m, then a smoothstep to the ground 3 m out.
  - **Distances** are exact to the union of the cells' squares (decision 1914 E1), searched ring by ring from cached
    ring maps.
  - **The yard:** at the ground. Past its first cell its sides rise at 2 m per metre (so the yard keep of E4).
  - **The eave:** behind the built front, across the yard's width, the turf comes down over the eave within 1.2 m.
    This is the one place the drawn cover is thinner than a metre (P-2002-4).
- **E9 — A window's place.** Outward from its edge's middle, the first point where the hill falls to the middle of the
  wall's top metre (3.5 m). On a straight wall that is 1.34 m out: just beyond the first cell, as P-2001-6 (a) reads.
  - It is turned to the slope's normal.
  - The hill is never cut for it. Its heights are the same with or without the window (tested).
  - Inside, a fitted window is a disc at the wall's top metre. By day, with the cutaway showing, the sky shows in it,
    with a beam, a pool of light 1.6 m into the room and a spotlight (BUILD-MOUND-016, presentation only).
- **E10 — The build order** (P-2001-14 (a), `demo_build_mound_jobs.gd`). Each Mound with a door, in the order of its
  first cell:
  1. Heap every cell from the yard, nearest the door first.
  2. Dig breadth first through open cells from where the builder stands. Each dug cell is framed before the next is
     dug: its braces drawn as ribs once every cell across the room there is framed.
  3. Top every cell from the yard, nearest the door first.
  4. Fit the doors and windows, then the furniture on the floor.

  A job takes heap 0.6 s, dig 1.5 s (the mole's), frame 0.5 s, top 0.4 s, fit 1.5 s, all in game time. A 24-cell
  Kitchen takes 97 jobs.
- **E11 — The builder.** Picked as decision 1921's fitter is: the selected resident, else the first free one who is
  not a mole, else anyone (P-2002-5).
  - It works from the door's yard, playing the forager's work clip.
  - Inside, it is indoors and a stand-in figure walks the dug cells. The figure is shown only in the cutaway.
  - A meal call cancels any task in the demo (the kitchen's `_call_diners`). So every 2 s the host looks for work and,
    when some waits and nobody is at it, sends a builder; it says "Nobody can build the Mound" once when nobody can go.
    The job search runs only then, never a frame.
  - A job holds a door's or window's first edge, and finds its row again when done: rows shift when one is removed.
- **E12 — The drawing** (`demo_build_mound_hill.gd`, `_view.gd`).
  - One height pass over a 0.25 m lattice gives both looks: the hill whole, and cut off at the wall's top. In the cut
    look each dug cell's floor is whole at 0.012 m, and an undug cell stays square (decision 1914 rules (a) and (b)).
  - It is built on a WorkerThreadPool task from a snapshot taken on the main thread, and only when what it reads
    changes: the Mounds, the Surface's ways down and its fitted furniture. The works and the furniture also move as the
    mole digs below, so those are compared only when their revisions move. About 92 ms for the harness's 64-cell
    Mound.
  - The parts are primitives gathered into one mesh per material. The shader colours the hill by vertex: turf, a dug
    floor, heaped earth and cut earth. The staged earth textures are applied triplanar.
  - Ordered cells are pegged out in chalk. Each Mound's state is in words over it ("Heaping the hill: 12 cells to go",
    "Fitting the window").
- **E13 — Words on the Surface.** The Surface's tags are drawn at a constant screen size. The tag spacer measures them
  at their drawn size (`demo_build_tags.gd world_size`). The rooms' lines show on the Surface only on the Furnish and
  Decor tabs, where they are wanted.
- **E14 — Walking.** From Confirm all on, each Mound stands as obstacle circles: one every 3 cells over its rooms and
  their first cells out, 2.1 m wide, plus one for any cell they miss, at most 128 in all. The harness's grown 96-cell
  Mound needs fewer than half of them (tested). A cut yard is left open, so
  residents walk round a hill and in only at a door. Nobody walks on the hill (P-2001-7 (a)).
- **E15 — The hatch.** A way down standing wholly on a Mound room's floor is reachable once its cell is dug and its
  Mound's door is fitted (`way_in`).
  - The mole and the fitter go down it from the door's yard, landing on level 1 as at any Entrance.
  - The dug view draws no burrow mouth for it. The Mound's cutaway draws it with its lid and ladder.
- **E16 — The ledger** lists each pending door, window or removal and its validity. A heap line gives P-2001-3's
  measures: five quanta heaped over each room cell and four dug back out. The berm's earth waits for MOUND-TERRAIN's
  heights. Everything is free.
- **E17 — The live suite runs on its own, in the slow tier.**
  - `test/live/demo_build_mound_live.gd` runs the whole loop in 152 s at 1280×720, through `test_demo_build_mound_live.gd`.
  - Its `--capture <directory>` option writes the frames.
  - The site it paints, south of the clearing, is the demo's only free ground near the village on both levels: the
    Bedroom at (1, 22), the Hall at (7, 22), the Kitchen at (11, 22), the door on the Hall's north wall at (8, 22), the
    windows on the Bedroom's and the Kitchen's north walls at (2, 22) and (15, 22), and a Pantry 2 cells wide grown
    on at (1, 26) with its hatch at (1, 32). Under the village, level 1 is under the stream up to z 31.
  - The wider berm moved the site. A probe of every placement over the build host's own surface reader found only this
    one, near the village and in the camera's bounds, where the 4-cell hill covers no water and no tree and the hatch
    lands on dry level 1. The Pantry is the old 4 × 8 cut to 2 wide, so that its berm clears the trees south of it.

## Where P-2001-13's thirteen items fit

| Item | Applied as | Status |
|---|---|---|
| 1. One style per room (-002) | Refused by the batch, in its words | Applied; cannot be reached from the panel yet (E1, P-2002-1) |
| 2. When doors and windows are placed | With their rooms, or later on a finished room; a later door's yard is cut when fitted | Applied (E5) |
| 3. An enclosed room | Allowed: a Mound room needs no outer edge of its own | Applied |
| 4. The ground under the heap | Water, trees, buildings, items and outdoor items refused; also a way down on the hill | Applied, except: scenery is covered (P-2002-3), and two Mounds whose berms meet are drawn as one hill, not refused, because the demo has no other surface rooms (P-2002-6) |
| 5. An edge that stops being outer | The stroke is refused in words until the door or window is removed | Stood in for (E7): the removal review is slice F's |
| 6. The window item | Free, a placeholder card and drawing | Applied |
| 7. Presentation has no bill | The front, garden, dressing and colour decide nothing | Applied |
| 8. The refusal words (-028, -030, -031) | -028 and -030 word for word | -031 ("! Blocked: needs earth") does not fit: the proof of concept is free, so no heap waits for earth |
| 9. Nothing on the cover | A way down on the berm is refused; furniture stands only on a dug floor; nobody walks on the hill | Applied |
| 10. Which types take the style | The eight painted types and Passage | Applied: the demo offers no type a heap defeats |
| 11. The outside door's walk cells | The yard is where the builder stands and where residents come in | Applied |
| 12. Windows underground | The Window card is offered below and refused in -020's words, since no hill face meets the air below yet | Applied |
| 13. A Way down inside a room | The Entrance card on a Mound room's floor is its hatch to level 1 | Applied (E15) |

## Deviations from the brief

- **"Hall".** The brief's room was a "Hall", but the GDD has no Hall type. The harness paints a Passage between the
  Bedroom and the Kitchen, which is what a hall is.
- **The eave** draws the cover thinner than the rule over a strip behind the door's front (E8, P-2002-4).
- **BUILD-MOUND-018** is stood in for by a refusal (E7).
- **The scenery** under a hill is covered and hidden (P-2002-3).

## PROPOSALS for Brendan

All nine were **approved as recommended** on 2026-10-16 ("Approve all"; each (a)).

- **P-2002-1 — Built rooms on the Surface.**
  - (a) As built: the style follows the level. Built rooms on the Surface wait for slice G, and -002's refusal waits
    with them.
  - (b) Let both styles stand on the Surface now: that needs slice G's walls and roofs.
- **P-2002-2 — The door and window words this lane added** (E4):
  - "this edge already holds a front door; click it to remove it";
  - "a room stands in or beside this door's yard; the yard must be clear ground";
  - "a door's yard and the ground beside it stay clear of rooms";
  - "a window lies on the turf slope, never in or beside a door's yard";
  - "nothing is dug into or built on a Mound's hill" (a way down on the berm);
  - "a way down stands wholly on one room's floor or off the hill";
  - "this would cover the Window on a room's outer edge; remove it first" (E7).

  (a) As built; (b) other words.
- **P-2002-3 — Scenery under a hill.** Rocks, boulders, fallen logs and mossy stumps are not among item 4's things.
  - (a) As built: the hill is heaped over them and they are hidden.
  - (b) Refuse them like items.
  - (c) The builder clears them first, as a job.
- **P-2002-4 — The turf over the eave.** To draw the mockup's front, the turf comes down over the eave within 1.2 m
  of the front, thinner than the 1 m cover.
  - (a) As built: a presentation exception, since the front's timber and plaster close the wall there.
  - (b) Keep the full cover and stand the front taller: the mockup's look is lost.
- **P-2002-5 — Who builds** (E11).
  - (a) As built: decision 1921's fitter rule.
  - (b) A named crew from the work board (slice C3's room foreman).
- **P-2002-6 — Two Mounds whose berms meet.**
  - (a) As built: drawn as one hill, each keeping its own door and rooms.
  - (b) Refuse a stroke whose berm reaches another Mound's room, under item 4's "any room outside this Mound".
- **P-2002-7 — Frame interleaved with dig** (E10). P-2001-14 (a) draws the braces as the frame once a cell is open.
  - (a) As built: each dug cell is framed before the next is dug, so the frame follows the digging.
  - (b) Dig every cell, then frame them all.
- **P-2002-8 — A door across two rooms.** A door's two edges may lie on two rooms of one Mound (say the Hall and the
  Kitchen). BUILD-MOUND-010 says "of a Mound room".
  - (a) As built: allowed, since the two rooms are one hill and one way in.
  - (b) Refuse it: a door's two edges on one room.
- **P-2002-9 — The ground round a yard** (E4, E8). The yard's sides slope 2 m a metre past its first cell.
  - (a) As built: no room within two cells of a yard's side or a cell past its foot, and no window within three.
  - (b) Stone cheek walls along the yard's sides, holding the hill up to the wall's top. Rooms and windows could
    then stand beside a yard, and the yard's sides would read less boxy than the drawn slope.

## The review

An independent `code-reviewer` read the whole change. It found no CRITICAL issue: the hill's worker build reads only
its own snapshot, nothing leaks, Undo and Redo of the doors and windows are consistent, no core owner changed, and
every function is typed, documented and 30 lines or fewer. Its four HIGH findings were fixed:

- **H1.** The host searched for the builder's next job every frame while there was no work. Now it looks every 2 s
  (E11).
- **H2.** A window just beside a door's yard was drawn on the yard's cut side, about 1 m up, with the garden in its
  clear strip. Now no window looks out within three cells of a yard's side (E4).
- **H3.** A room could stand in front of or beside a door's yard, its wall open onto the cut, and a confirmed door's
  yard was not protected at all. Now no room stands in any door's yard keep, pending or confirmed (E4, E7).
- **H4.** A removal withdrawn by the keyboard after a room was painted over its slope let Confirm all order a buried
  door. Now every pending Mound room is judged again against the doors and windows (E7).

Of its MEDIUM findings these were fixed:

- a job holding a stale row after a removal (E11);
- the obstacle cap (E14);
- the hill rebuilt on every underground dig (E12);
- a window accepted with no slope to lie on (E4);
- the per-frame key allocated by the marks;
- small allocations in the field's ring search;
- the record's claim that -002 was tested through the panel (E1).

LOW findings fixed: the hatch's words are now one string, a stale hover judgement is cleared, and `_op_hill` runs once
a judgement. A door across two rooms is P-2002-8.

Left as they are, with reasons:

- Edge judgements are not cached per layout, and a stroke recomputes its Mound's hill as it is dragged. The demo's
  Mounds are a few dozen cells, and the live loop holds its frame budget. MOUND-REAL's planner owns the real cost.
- "Remove Window" is said when a pending removal is withdrawn. It is a step's name, as Undo names it.
- The test that a window never changes the hill's heights cannot fail today, since the field is never given windows.
  It stays as a guard.

## Gates

- **Unit suites**: every new public function has a test.
  - Rules: `test_build_mound.gd`, `test_build_mound_edges.gd`, `test_build_batch_mound.gd`, `test_build_panel_mound.gd`.
  - The demo: `test_demo_build_mounds.gd` (store and job order), `test_demo_build_mound_field.gd`,
    `test_demo_build_mound_mesh.gd`, `test_demo_build_mound_parts.gd`, `test_demo_build_mound_view.gd` and
    `test_demo_build_mound_host.gd` (host, ground and builder).
  - Additions to `test_build_catalog.gd`, `test_build_cell_validity.gd`, `test_build_panel.gd`,
    `test_demo_build_dig.gd`, `test_demo_build_furnish.gd`, `test_demo_build_panel.gd`, `test_demo_build_works.gd`,
    `test_demo_cast.gd` and `test_demo_world.gd`.
  - The field's suite checks, at a quarter-metre spacing, that the cover lies over every room point, that no wall is
    open, that nothing lies past the berm, that the hill only grows, that the yard is cut, and where windows go.
- **The full CI-style run**: demo art moved aside, `godot/.godot` deleted, a clean import, then
  `./tools/run_tests_parallel.sh`. Result, run again after the 2026-10-16 ruling: 522 suites, 12,704 tests,
  1,252,217 assertions, 0 failures, 0 unexpected errors or warnings, 0 leaks, verify passed. The art was put back and imported again, and
  `demo_texture_imports.py --check` passed.
  - The first run failed two checks in `test/live/demo_input_live.gd`. They expected surface room types to be locked;
    they now check the Mound style and the Built toggle's reason. Every run since has passed.
- **Analyzer**: `tools/gdscript_warnings.py --max 0` reports 0 warnings in 1,580 files. `decision_numbers.py`
  passes.
- **Mutation testing**: 66 hand-written mutants of the heap, edge, door, window, yard, field, store, job and dressing
  logic, run against the ten Mound suites. 63 were killed. Three survive, and each is equivalent:
  - `placed()` skipping its own row: the kind it lists never equals that row's kind wherever it is called.
  - The field's berm bound `d < BERM_M` → `d < BERM_M + 1`: `berm(d)` is already 0 from `BERM_M` on.
  - The ring search's early stop one ring later: ring k's cells lie at least k − 1 away, so only the work changes.

  Three earlier survivors were killed by new tests: a water cell kept under "No way in", a way down at an inner
  corner, and a stroke's hill judged with its own Mound only.
- **Mutation testing again, after the 2026-10-16 ruling.** The heap, footprint, yard, edge and field mutants were run
  again: 38 of them, 11 written for the new berm and crown. Two were retired, because the old berm and crown lines they
  changed are gone. 34 were killed. The two that survive are the equivalent ones above (the berm bound and the ring
  search's stop). One more, the berm's own bound (`d >= BERM_M` → `d >= BERM_M + 1`), survived at first: the cosine
  rises again past its foot, and no test looked there. A new assertion now kills it.
- **The live loop** (`test/live/demo_build_mound_live.gd`, 45 checks) passes headless at 1280×720 in the slow tier
  (141 s on the new site), and windowed with its frames at 1280×720 and 1920×1080, before and after the ruling. It
  covers:
  - painting the Bedroom, Hall and Kitchen, and the cells' "No way in";
  - the door and two windows, and a window refused in words;
  - Confirm all, then each stage in turn: heap, dig, frame and top;
  - the hill's own rules checked on the drawn heights;
  - the cutaway, with daylight inside by day;
  - the Pantry grown on, and the hill growing with it;
  - the hatch landing on level 1 with "Way up to the surface";
  - the hearth fitted, and the chimney over it.

## CI follow-up (2026-10-16): the live loop and a stall

PR #267's CI failed the live loop at the hearth in shard 5. These three checks failed:
- "a hearth placed on the Kitchen's floor", with no refusal words;
- "the hearth is ordered", which said "Nothing to confirm yet";
- "the hearth is fitted by the Mound's builder".

**The cause.**
1. The first drawing of level 1 is a long frame: 198 ms on Brendan's Mac, and that frame is level 1's own drawing, not the Mound's.
2. On CI's slower runner, with the clock at 4x, that hitch put the clock into its overload pause (REQ-SET-008).
3. The stall banner then holds the build panel's world input until the player presses Resume, as `demo_village.gd`'s `_build_blocked` intends.
4. The harness never pressed Resume, so the hearth's click was held.

**Reproduced locally.** A scratch copy of the harness forced a 1.5 s hitch after level 1 is drawn, and the same three checks failed with the same words.

**The fix is in the harness, not the game.** Before each frame's step, if the banner shows while the clock is paused, the harness presses Resume for the player with `acknowledge_overload`, the banner's own call, and prints a NOTE saying so. The feast and hall harnesses already do the same. With the forced hitch the loop then passes 45/0 and prints one NOTE.

## Source

Brendan's rulings on decision 2001 (2026-10-15), relayed by the coordinator. MOUND-POC's brief (2026-10-15), from the
coordinator. `docs/building_model_amendment.md` BUILD-MOUND-001–031. Decision 2001 §5's mockups.
