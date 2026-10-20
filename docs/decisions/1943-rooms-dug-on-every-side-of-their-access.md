# 1943 — Rooms dug on every side of their access, and larger than the Corridor is wide

Date: 2026-10-19 · Status: Accepted (built). Plan of record: P-1942-1 (b), the coordinator's sequencing call: the
multi-heading lane straight after station-chain retirement (decision 1942, #276). Brendan ruled on the one item it
raised, P-1943-1 (pick moles on turned headings): "Claws for turns, warn" (below).

Lane `feat/room-multi-heading`, cut from the retirement lane's gated head `7ec4104d`. Number range 1943–1949.

## Decision

1. **The planner tries every heading.** The access's bound heading is tried first, exactly as before: its
   existing contact, else ADR 1213's straight approach, by master's own code path (`PLAN_MASTER`). Only when that
   reaches no contact does the planner try every heading (a quarter turn at a time, the bound one first) with a
   straight approach on the bound rows' own siblings at that yaw, and after that every heading with an L-shaped
   approach. A contact that already exists is only ever walked to, never planned again.
   - A room dug straight out from its access on master therefore plans, publishes and digs exactly as on master
     (the SHA trace is byte-identical, §5).
2. **An L-shaped ground approach** reaches cubes the Corridor cannot line up with: from the gateway along the
   heading's axis to a turning line, along that line to the root's line, then the heading run (each run split at
   section boundaries). It may publish up to **five stations**; a straight approach keeps ADR 1213's three.
3. **A room-frontier publication may add five stations** (Locations `FRONTIER_MAX_STATIONS`, decision 1943's one
   shared constant). Slice D agreed the edit to its held Locations and Routes functions.
4. **A stopped dig's paid phase is taken over on whichever heading can walk to its station.**
5. **The builder walks each cube on its heading's own travel rows** (the bound rows' siblings at the work row's
   yaw), and refuses `ROOM_BUILDER_HEADING_ROWS` when the content has none.

## 1. The gap (decision 1942 §4.2)

On master a room was dug only when every cube could be reached straight out from the access: a turn in the
Corridor at the gateway, then one run on the bound heading. In this lane's probes on the retirement head:
- a Kitchen north, south or west of the Corridor stopped at its first planned cube (`ROOM_STATION_GEOMETRY_CLOSED`:
  no root on the bound +X heading lies in open void);
- cubes past the Corridor's ends (a 7 x 7 or a 12 x 4 Kitchen east of the access) could not be lined up with any
  Corridor line, and the L-shaped approaches that reach them over the room's own floor needed four stations (the
  gateway turn, the Corridor/room section boundary, the turn inside the room, the WORK station), one more than a
  publication held.

## 2. What was built

| File | Change |
|---|---|
| `scripts/core/underground_room_station_planner.gd` | `next_contact_into` (an existing contact walked to on any heading, `_existing_contact`, `_walk_to_contact`, `_walkable`; else the bound heading's master plan, then straight and L-shaped plans on every heading, `_publish_at`, `_passable`); `_plan_into` with `PLAN_MASTER` / `PLAN_STRAIGHT` / `PLAN_CORNERED` (public `plan_into` is `PLAN_MASTER`, master's own); `_unreached`; `resume_contact_into` and `_resumable`; `_cornered`, `_turning`, `_turning_lines`, `_ground_reach`; `_run` (a run split at each section boundary, both directions); `_leg` (the leg's section is the one holding its floor-rounded midpoint, `_midpoint`; its departure's under `PLAN_MASTER`); `_patch_on_target` (the WORK patch must lie on the struck face, as WorkFace proves); `_cap` (`STRAIGHT_STATIONS` 3, or `MAX_STATIONS` for an L-shaped approach); the overlong bound `_cap + 2`; the planner's `_output` sized from `MAX_STATIONS` |
| `scripts/core/underground_room_frontier_publication.gd` | `MAX_STATIONS = Locations.FRONTIER_MAX_STATIONS`; every packet sized from it; `heap_precharge` (ADR 1161's figure through three stations); `_edge_into`: a run down across a section's low edge is published in the arrival's section, room and level |
| `scripts/core/underground_locations.gd` (slice D's, agreed) | `FRONTIER_MAX_STATIONS = 5`; `FRONTIER_HEAP_WORDS` 168 → 280; the cap in `hold_frontier`, `begin_frontier_prepare`, `frontier_scope_refusal`, `frontier_rows_refusal`, `frontier_heap_refusal` |
| `scripts/core/underground_routes.gd` (slice D's, agreed) | `frontier_leaf_refusal` sizes its edges from `FRONTIER_MAX_STATIONS` |
| `scripts/core/underground_room_builder.gd` (cleared functions) | `_plan_claim` walks on `_heading_row` siblings; `REFUSE_HEADING_ROWS`; `_contact` resumes through the planner's `resume_contact_into` |

### The heading passes

`next_contact_into` (one foreman step):
1. **An existing contact** is looked for on the bound heading's forward row, as before. Contacts are found whatever
   the approach row (Frontier's `_select` reads every WORK station striking the cube), so its result says whether a
   contact exists at all.
   - Found and walkable: returned, as before.
   - It exists but the bound row cannot walk to it (`ROUTE_NOT_CONNECTED`: it was published on another heading's
     chain): each other heading's forward row is tried. Nothing is planned or published: a second WORK station for
     the cube would make every later contact `REFUSE_AMBIGUOUS`.
   - A contact on a heading whose travel rows the builder lacks is refused `ROOM_STATION_RETREAT_HEADING`
     (`_walkable`), before any phase is opened.
2. **No contact: the bound heading's plan**, ADR 1213's straight approach by master's code (`PLAN_MASTER`: the
   gateway turn as one span, increasing runs split at section boundaries, each span in its departure's section).
   Any result other than "reaches no contact" (`_unreached`) is returned as before.
3. **Every heading, the bound one first, with a straight approach** (`PLAN_STRAIGHT`: the same shape, its runs split
   at section boundaries in both directions, each span in the section holding its midpoint).
4. **Every heading, the bound one first, with an L-shaped approach** (`PLAN_CORNERED`).
5. A publication ends the step whatever follows, as before. A refusal from steps 3–4 is returned unless the heading
   simply reaches no contact, has no travel rows, or its search ran out of checks (`_passable`); then the next
   heading is tried. When none succeeds, the bound heading's refusal is returned.

Straight approaches go first on every heading because they are cheaper and shorter. In the first build the
L-shaped search ran on the bound heading before any other heading was tried. On the 7 x 7 room it then exhausted
`Space.MAX_CHECKS` on cubes that a turned heading reached straight, and the dig stopped (§4).

### The L-shaped approach

- The turning lines are the void regions' planes along the heading, each set back by the ground row's reach (its
  body's farthest horizontal extent, so the body clears the region's edge). Lines behind the gateway are dropped.
  Each distinct line is tried once, nearest the gateway first (`_turning_lines`, a sorted insertion into the Query's
  `lines` scratch, paying one check per line kept and one per line it is sorted past).
- For each line: a ground run from the gateway along the heading's axis to the line, a ground run along the line to
  the root's line, then the heading run to the root (full travel, or the finite step as before). Each run is split
  at every section boundary it crosses.
- The chain may hold up to five stations. Straight approaches keep three, so they publish exactly as on master.

### Five stations a publication

`FRONTIER_MAX_STATIONS = 5` is the one constant. Publication's packets, the planner's output and the builder's
result are sized from it. The sparse heap patch replays two removals a station:
`2 × 5 × 14 × 2 = 280` words. The final leaf's prepaid heap replay is `2 × max(6, 2 × count) × 14 × 84 × 4`, ADR
1161's figure through three stations. Locations' and Routes' check spend for a chain of three stations or fewer is
unchanged (§5).

### Resume across headings

A stopped dig's paid phase is resumed on the bound forward row first, as before. When that row finds no contact,
or cannot walk to the station's chain (`ROUTE_NOT_CONNECTED`: the station was published on another heading's
chain), each other yaw's forward row is tried. Before this, a north room stopped mid-phase on a turned-heading cube
could not be taken over. The new mole then went on to the cube above it and refused `WORK_FACE_COLUMN_UNOPENED`.

## 3. Engineering choices

1. **Bound heading first, by master's own code.** The bound heading's first plan runs ADR 1213's straight approach
   with master's splitting and section rule (`PLAN_MASTER`), so a room master digs keeps its chains, stations,
   publications and route spend in every geometry, not only the fixtures'. Decision 1943's run splitting changes
   which root candidate succeeds first wherever a gateway turn or a decreasing run crosses a section boundary; it
   therefore applies only to the plans master never made. The gate is the SHA trace and the room suites' spend
   prints, both identical. `_patch_on_target` applies to every plan: it refuses only a root whose patch WorkFace
   would refuse, so it can change only a room master could not dig.
2. **Turning lines from the region table**, not a search over every coordinate. Void regions' planes are where the
   free space changes, so a line set back by the ground body's reach from one of them is the first line the body
   can run along. Deduplicating and ordering them keeps the search inside one plan's checks on every room of the
   matrix.
3. **Five stations, not more.** The L-shaped chains the probes needed were four stations long (§1); five leaves one
   more section boundary of margin.
   Six is refused (`ROOM_FRONTIER_PUBLICATION_SCOPE`, and `LOCATION_FRONTIER_CONTEXT` in Locations).
4. **The arrival's section for a down-crossing.** A run leaving a section across its low edge has every interior
   point in the next section. Departure-first is kept wherever the departure's section holds the run, so every
   master run is published as before.
5. **Each heading's plan has its own checks.** A step may now run up to nine plans (the bound heading's master plan,
   then four straight and four L-shaped), each within `Space.MAX_CHECKS`, inside the one cold lease. One budget for
   the whole step would starve the later headings: in the first build the L-shaped search on the bound heading used
   a whole `Space.MAX_CHECKS` on the 7 x 7 room and the dig stopped. The extra plans run
   only for a cube the bound heading's plan cannot reach, which on master was a dig that stopped; a room master digs
   runs exactly one plan a cube, as before. An existing contact is looked for once, on the bound row; other rows are
   tried only when it exists and the bound row cannot walk to it.
6. **Retirement's chain bound follows the cap.** `Retirement.MAX_CHAIN` is `2 × Publication.MAX_STATIONS`, so it rose
   from 6 to 10 with the cap, and the tests' "one chain of edges" margin (`CHAIN_EDGES = 2 × MAX_CHAIN`) from 12 to 20
   edges. The measured peaks (§4) stay within 7 edges of `RETIRE_FROM_EDGES`.

## 4. Coverage matrix (`room_heading_case.gd`)

Each room is dug by the room runtime from the one access with one mole, retirement in. Each asserts no refusal,
every painted cube dug, no live Project or cold lease, **every BRACE's wood paid exactly once** (wood made less what
M still holds equals one bill per cube), the live graph within one chain of the retirement bound, and every route
proof within `Space.MAX_CHECKS`.

| Room | Side | Cells | Cubes | Ticks | Peak edges | Peak Locations | Peak route-proof checks | Longest chain |
|---|---|---|---|---|---|---|---|---|
| Kitchen | east | 2 × 2 | 16 | 2,845 | 20 | 11 | 399,120 | 3 |
| Kitchen | north | 2 × 2 | 16 | 2,965 | 26 | 14 | 451,920 | 3 |
| Kitchen | south | 2 × 2 | 16 | 2,853 | 26 | 14 | 453,770 | 3 |
| Kitchen | west | 2 × 2 | 16 | 3,065 | 26 | 14 | 457,710 | 3 |
| Kitchen, pick mole | east | 2 × 2 | 16 | 2,977 | 20 | 11 | 399,130 | 3 |
| Kitchen | east | 7 × 7 | 196 | 41,883 | 42 | 22 | 582,956 | 4 |
| Kitchen | east | 4 wide × 12 deep | 192 | 40,837 | 40 | 21 | 582,956 | 3 |
| Kitchen | east | 12 wide × 4 deep | 192 | 42,581 | 42 | 22 | 582,956 | 4 |
| Kitchen, L-shaped | east | 4 deep, 2 wide, its far end 6 wide | 64 | 13,079 | 42 | 22 | 525,982 | 4 |
| Dormitory (3 tiles) | north | 2 × 6 | 48 | 9,469 | 38 | 20 | 488,212 | 3 |
| Infirmary (3 tiles) | south | 6 × 2 | 48 | 9,077 | 38 | 20 | 787,670 | 3 |
| Corridor (1 tile wide) | west | 2 × 4 | 32 | 6,371 | 38 | 20 | 497,594 | 3 |
| Pantry (4 tiles) | south | 4 × 4 | 64 | 12,163 | 38 | 20 | 787,670 | 3 |
| Kitchen (6 tiles) | west | 4 × 6 | 96 | 20,739 | 42 | 22 | 601,986 | 4 |
| Bedroom (6 tiles) | north | 6 × 4 | 96 | 19,387 | 38 | 20 | 785,604 | 3 |
| Dining room (8 tiles) | east | 8 × 4 | 128 | 26,829 | 42 | 22 | 582,956 | 4 |
| Common room (8 tiles) | north | 8 × 4 | 128 | 26,487 | 38 | 20 | 785,604 | 3 |

- The GDD minimum floor areas are `room_catalog.gd`'s, from `buildings.gd`: one bed's 3 tiles (Dormitory), one
  patient bed's 3 (Infirmary), 4 (Pantry), 6 (Kitchen, Bedroom), four seats' 8 (Dining room), 8 (Common room), and
  a Corridor one tile wide. A tile is 2 × 2 cells.
- Also proved on a turned heading (the north Kitchen):
  - a dig stopped while its mole earns a turned-heading cube's paid phase, ordered again with another mole: the
    phase is taken over and the room finished, every BRACE paid once;
  - a dig restored from its saved record before every tick ends as the uninterrupted dig: the same record after
    every tick, the same graph and Locations bytes at the end.
- The longest chain is the most Locations one tick added (net): a chain's stations are published at once. The
  L-shaped, 7 × 7 and 12 × 4 suites assert it exceeds three.
- **Retirement holds the graph down.** Peaks stay within one chain of `RETIRE_FROM_EDGES` (35), and the worst route
  proof spends 787,670 of 1,048,576 checks.

### Pick moles

A pick mole digs on the bound heading (content 12's pick READY rows 2–9 and wall rows 13–28). **On any other heading
it cannot reach a face**, and this is a content gap, not a planner one:
- its READY body reaches 910 u ahead, 142 u past its wall rows' 768 u anchor, so the last leg to a face must be the
  finite step;
- content 12 publishes the pick's step pair (rows 10 and 11) only at +X;
- its all-yaw ground rows (1, 12) reach ±1,256 u, which no Corridor span near the Corridor's ends clears.

Claws need neither: their READY body reaches no further than their wall row's anchor (521 u). P-1943-1, ruled
"Claws for turns, warn", is below.

## 5. Proof

**Exactness.** The dig benchmark's per-tick SHA-256 trace (`tools/benchmark_dig_tick.gd`, `REDWALL_DIG_TRACE`; the
room loop and the entry run) is byte-identical to master `8a7d045d`'s: 11,453 lines. Every `ROOM-*` and `FRONTIER-*`
spend line the room suites print (route and Location checks, edge and Location counts per phase) is identical to
the retirement head's, line for line.

**Station bound** (`test_underground_room_frontier_publication.gd`):
- five stations hold, prepare and stay in scope in Locations, and a sixth is refused by each;
- the actual coupled publication adds five stations (the lateral chain's last leg split in four), and a sixth is
  refused before any allocation, the caller's output untouched;
- the heap replay takes ten removals at every allocator extreme and refuses an eleventh, even where the patch would
  hold it;
- the precharge covers every station count, and is ADR 1161's through three.

**`_edge_into`**: a leg inside the section it leaves keeps that section even where the arrival's would hold it; a
leg down across a low edge takes the arrival's section, room and level both ways; a leg in neither is refused.

**Mutation testing.** 55 mutants of this lane's logic and decision 1942's two survivors, each run against the suites that cover it (the
multi-heading suite, the L-shaped room, the first room-type suite and the planner suite for the planner; the
publication suite for the cap and `_edge_into`; the retirement and foreign-claims suites for 1942's; the Confirm
suite for §8): **50 killed, 5 survived.**
- The station cap: 24 mutants (the constant at 3, 4 and 6; each of the five Locations functions' count, refs and
  edges checks back at the old literal or one past five; Routes' edge size; the heap words; the publication's
  `MAX_STATIONS`; the precharge at its old figure). All killed.
- `_edge_into`: no fallback, arrival first, the departure's room, section or level kept. All 6 killed.
- The planner and builder: 20 mutants, 16 killed (`_unreached`, the straight and L-shaped passes, an existing contact
  planned again, a search out of checks stopping the headings, `_resumable`, `_cap`, extended plans split as master,
  the run probe, the midpoint, the turning lines' dedupe, side and reach, the builder's heading row, the patch rule,
  the L's lateral run).
- P-1943-1's build (§8): no mid-dig stop, no pick words for a crew, a tool the order named also stopping. All 3
  killed.
- Decision 1942's two cost-only survivors: "the claims table ignored" is now killed (the table answers without
  scanning the owner, and the scan gives the same answers at its cost); "`_column_done` always true" survives (below).

| Survivor | Why it is acceptable |
|---|---|
| a publication does not end the step | only reachable when a heading publishes and its own re-derived contact then refuses with a passable code; the contact just published is on that heading's row, so in every fixture it is found. The guard is kept (the review's H1) |
| no master plan (`PLAN_MASTER` planned as `PLAN_STRAIGHT`) | the two differ only where the bound heading's gateway turn or a decreasing run crosses a section boundary; every fixture's bound heading is +X with a one-section Corridor. The split each plan uses is tested directly (`_legs` under both), and the SHA trace guards master's rooms |
| the contact's heading not checked walkable | content 12 publishes claw and pick READY rows at all four quarter turns, so every contact heading is walkable |
| the turning guard admits the gateway line | `_turning_lines` already drops every line at or behind the gateway |
| decision 1942's `_column_done` always true | accepted by the coordinator: no fixture has a builder idle mid-column while a dig runs, so a column is never offered early. The crowded one- and two-builder digs now assert no station is retired before its column is dug and that a crowded dig publishes exactly what an uncrowded one does; 1942 §5's note stands |


## 6. Memory (ADR 1212 census)

- No retained state is added: the planner, publication, retirement and the builder's new function are stateless
  or per-call.
- Publication's cold controls recount to **11,450 B** (ADR 1161's reviewed 8,050; two Requests' ADR 1215 air at
  five stations, 2 × 500; six Records' air, 6 × 80; and two further stations at 960 B each). `CONTROL_BYTES` is
  **12,288** (was 9,216), charged inside `Budget.COLD_BYTES` with Location, WorkFace and WorldRoutes peaks. The
  reviewed delta rows for `underground_locations.gd` and the publication are updated with their charges.
- The planner's cold slice is **56,040 B** (was 52,664): seven-station chain scratch (+304) and the turning lines
  (`2 × MAX_REGIONS` int64, +3,072), inside the same lease.
- The memory pack is regenerated: **headroom 44,201,316 B, unchanged.**

## 7. Gates

GATES_PLACEHOLDER

## 8. The ruling's build: a pick holder refused in words, and a worded mid-dig stop

Built on slice C3's Confirm route after it merged (#277), with no change to C3's crew rule (the coordinator's option
(a); see "Brendan's ruling" for why the per-cell warning has nothing to warn about yet):

| File | Change |
|---|---|
| `scripts/core/underground_room_confirm.gd` | `PICK_CREW_WORDS` ("Pick diggers can't dig rooms yet: choose a claw digger"), `PICK_TURN_WORDS`, and `pick_words(code, owners, crew)`: the words for a named crew member refused because they hold a tool, or for the mid-dig stop; "" for any other refusal (C3's `refusal_words` is unchanged) |
| `scripts/core/underground_room_builder.gd` (`_contact`, cleared) | `REFUSE_PICK_CANNOT_TURN` (`ROOM_DIG_PICK_CANNOT_TURN`): a builder whose crew order named no tool but who now holds one fails at its next cube's contact, so the room stops named, never with a bare planner refusal. A crew the order named with a tool (the test fixtures' pick moles) is unaffected |
| `scripts/systems/settlement_system.gd` (`order_painted_room`, `_alert_underground_room`, cleared) | the alert says the pick words when there are some, else the code as before |

Tests (`test_underground_room_confirm.gd`, on the real Confirm route): a named mole holding a pick is refused before
anything is admitted or the way in is asked, in those words, and other refusals get no pick words; a claw mole that
takes up a pick after its first cube stops the dig at its next cube with `ROOM_DIG_PICK_CANNOT_TURN`, in words, its
dug cubes kept.

**The crew line and the room card.** The demo's crew line and room card show the proof of concept's crews
(decision 1912's mole, demo actors that carry no tools) until slice D2 switches the demo to the real route, so no
pick holder can appear in them yet. The words live with the route (`pick_words`), for D2's host to show on both; the
settlement's alert says them now.


## Brendan's ruling

**P-1943-1, pick moles on turned headings: "Claws for turns, warn"** (Brendan, in chat, 2026-10-19; relayed by the
coordinator).
- No new pick content. A pick mole digs only where content 12's pick rows reach (§4, "Pick moles").
- At Confirm, a room with cells a pick-only crew cannot reach is reported in words, for example "Pick diggers can't
  reach 18 cells: add a claw digger", so a dig never stops halfway unexplained.
- If it still happens mid-dig (for example the crew changes), the room stops with a named, worded reason, never a
  bare `ROOM_STATION_GEOMETRY_CLOSED`.

**The question's premise, corrected by the coordinator** (2026-10-19, who is telling Brendan): the question assumed
pick moles dig in the game. They do not. Moles dig with their claws (DEC-052), and slice C3's crew rule
(decision 1991, `underground_room_composer.gd` `could_dig` / `crew_refusal`) accepts only living adult moles free of
tools: a named crew member holding a pick is refused before anything is admitted, and "the first idle mole" is chosen
among tool-free moles only. **C3's crew rule therefore already satisfies "Claws for turns, warn"**: no pick crew
reaches a dig, so no dig stops halfway for a pick. The coordinator's call (option (a)): no change to C3's rule, and
this lane adds only the words and the mid-dig stop (§8).

## Open obligation

**A future slice that lets pick holders crew a room dig must add the per-cell warning at Confirm** that Brendan
ruled: count the cells a pick-only crew cannot reach and say so in words ("Pick diggers can't reach 18 cells: add a
claw digger"). A suggested predicate: a cell is reachable by a pick only on the access's bound heading (content 12's
pick step pair is published at +X only), so it is reachable when its neighbour on the approach side is a reachable
cell of the room or existing open void; count the rest. A mixed crew digs every cell (claws take the turned
headings).

## Source

Decisions 1161, 1213, 1215, 1934 §2, 1938, 1939, 1942 §4.2 and P-1942-1, 1971, 1972; slice D's agreement to the
Locations and Routes edits; the coordinator's acceptance list for this lane; the scratch probe logs of this lane
(not committed).
