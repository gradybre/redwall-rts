# 1911 — Slice C scoping: what "paint a room on earth = the dig order" needs, and what exists today

Date: 2026-10-12 · Status: Accepted (Brendan ruled P-C1–P-C9 on 2026-10-12, recorded below; C1 is implemented under
this record)

Number range: 1911–1929 was allocated to this lane by the coordinator; checked free on every local and remote ref
(`git ls-tree` over `refs/heads` and `refs/remotes`) and with `decision_numbers.py`. It replaces no BACKLOG range.
This is the lane record; later records of the lane take 1912 onwards.

## Decision

Slice C of DEC-061 (study §5 C) is scoped against the code at `origin/master` 5977191b. **The digging half of slice C
cannot be finished in this slice**, for two reasons found in the code, not in the documents:

1. **No room dispatcher exists in the game.** The only automatic underground driver is the first-entry foreman. A
   confirmed room gets Sites and geometry but no Project, Job or worker, and nothing digs it.
2. **Nothing can reach underground level 1.** The only buildable way down, the first-entry stair, ends on a floor
   1024 u (1 m) below the surface. Level 1's floor is 5120 u down (SET-BUILD-001 §3). Every painted room on levels
   1–4 therefore has no way in until slice D qualifies an entrance (OPEN-10 (a)).

This record proposes splitting the slice (P-C1). **C1** is all the painting work on the actual World, which needs
neither missing piece. **C2** is the production room dispatcher, which can run beside C1 because it touches different
files. **C3** wires Confirm all to C2 once slice D gives level 1 a way in.

## Brendan's rulings (2026-10-12)

Relayed by the coordinator: on 2026-10-12, in chat to the coordinator, Brendan answered P-C1–P-C9.

| Item | Ruling |
|---|---|
| P-C1 | **(b) split.** "You do C1 now. C2 (room foreman) starts as a separate lane in parallel. C3 comes after slice D and C2." |
| P-C2 | **(c) remove them now** (not this record's recommendation). "The Passage / Burrow home / Root cellar cards no longer open the old tunnel and template tools; remove those entries from the panel. The demo has no playable digging until C3, so make the panel/words honest about that." Deleting the old tool code itself is optional, only where nothing else uses it |
| P-C3 | **(a)** "price the height actually cut (2 quanta per cell on the current rows), and add a DEC-054 note to SET-BUILD-001 §7.2" |
| P-C4 | **(a)**, a chain of drafted cells of any type on the level to finished space or a connector is a way in; "No way in" holds Confirm all back |
| P-C5 | **(a)**, keep the shared frame and draw the actual terrain |
| P-C6 | **(a)**, levels 1–4 show the actual World at 5 m; the legacy warren is hidden while painting |
| P-C7 | **(a)**, the Rectangle · Oval · Paint · Erase strip with a 2 × 2 brush; Erase removes pending cells only |
| P-C8 | **(a)**, fold decision 1880's bytes in when the columns are first allocated (C3, or C2 if first) |
| P-C9 | **(a)**, C2 digs in BUILD-REQ-012's breadth-first order with up to 4 builders |

**Corrected the same day (Brendan's rulings on decision 1931, relayed by the coordinator).** P-C3 (a)'s "2 quanta"
came from identity −1 ("any row"), which counts the retired pick's rows (decision 1931 F2). Brendan ruled P-C2-3 (a):
"price and plan by the claw crew's identity, never 'any row'". The principle of P-C3 (a) stands; its number is
the claw crew's result, read in one place (`modular_runtime.gd dug_height_u`): 1,024 u, 1 quantum per cell on master,
until slice C2.1 changes the room-digging rule (P-C2-1: rooms are dug with the claws' down stroke).

Written in: SET-BUILD-001 §7.2 (the DEC-054 note, corrected for P-C2-3), the study's §5 dependency rows (C1 needs B; C3 needs C2 and D),
`docs/handoff/RULINGS.md`. File boundary with the C2 lane (coordinator, same message): C2 owns `godot/scripts/core/`
(the room foreman, `room_projects.gd`, the `settlement_system.gd` tick wiring, `underground_room_orders.gd`) and its
own tests and decisions (1931+); C1 edits none of them and keeps `docs/underground-integration-status.md`.

## 1. What slice C must deliver

Sources: the study §5 C and its dependency row, SET-BUILD-001 (BUILD-REQ-nnn), UI-BUILD-001–014 with "Input in build
mode" and "Validity in words", ARCH-BUILD-001, decisions 1851, 1871 and 1880.

| # | Item | Owning requirement | Sub-step |
|---|---|---|---|
| 1 | Rectangle drag with a live size label in cells and metres: "17 × 6 cells (17 m × 6 m)" | SET-BUILD-001 §3; UI-BUILD-010 | Done in B (`build_batch.gd size_text`); kept |
| 2 | Oval, Paint and Erase beside Rectangle, on the 1 m grid | Study §5 C; BUILD-REQ-002 | C1 |
| 3 | The 8 GDD purposes as room types. Passage (`CORRIDOR`) is just another type, at least 2 cells wide, offered on every level. There is no polyline tunnel tool | BUILD-REQ-014; UI-BUILD-003; SET-BUILD-001 §4 | C1 for the card; retiring the old tool depends on P-C2 |
| 4 | Every painted cell lies in a 2 × 2 block of its own room, judged per cell | BUILD-REQ-002; "Too narrow" | C1 |
| 5 | Each 4-connected same-type set is one room. A stroke grows the room it touches. A stroke that joins two pending same-type rooms merges them (P-B2 (b), ruled for slice C) | BUILD-REQ-003, -004; P-B2 (b) | C1 |
| 6 | No painting over another type | BUILD-REQ-005 | Done in B; kept per cell |
| 7 | Validity per cell, shown on the ghost before Confirm all: way in ("No way in"), GDD minimums ("Too small"), diggable ground ("Cannot dig here: water / protected ground / occupied / protected route") | BUILD-REQ-013, -021; ECON-003; SET-BUILD-001 §4, §8; "Validity in words" | C1 |
| 8 | A cell reached only through a connector drafted in the same batch is valid, and its digging waits for that connector | BUILD-REQ-013; OPEN-07 (a) | C1 as a rule; no connector exists before slice D |
| 9 | Ghost: GOLD outline when valid, WARNING dashed when blocked, DANGER hatched and numbered against the reason list when impossible (P-B9 (a), ruled for C) | UI-BUILD-010; UX-BUILD-T03; MOVE-REQ-018 | C1 |
| 10 | Keyboard cell cursor moves relative to the camera (P-B10 (b), ruled for C) | UI-BUILD input table; P-B10 | C1 |
| 11 | Painting on the settlement's actual World, not the legacy demo warren (1871 "Not done", P-B5) | SET-BUILD-001 §3; UG-VIEW D29 ("actual world dirt is the drawing surface") | C1 (frame and view: P-C5, P-C6) |
| 12 | Retire `modular_demo_mode.gd`'s separate view (P-B7 (a), ruled for C) | P-B7 | C1 |
| 13 | Replace the Passage, Burrow home and Root cellar cards that open the old tunnel and template tools | 1871 ruling 2; OPEN-11 (a); BUILD-REQ-014 | Depends on P-C2 |
| 14 | The ledger prices each cell from the adopted 1 m³ quantum economy (brace/cut/finish, earth out), never an invented number | SET-BUILD-001 §7.2; BAL-ROOM-001; DEC-059 | Done in B; height question P-C3 |
| 15 | Confirm all turns every drafted room into excavation, one project per room, dug cell by cell outward from the access face in breadth-first order, ties by cell index, up to 4 builders | BUILD-REQ-012, -019; SET-BUILD-001 §8, §10; 1880 Q1 | C2 (dispatcher) and C3 (wiring) |
| 16 | Bind painted room deltas to RoomProjects/ExcavationSites and ledger their project bytes | ARCH-BUILD-001 obligation 3; 1880 Q1 | C2/C3 |
| 17 | Fold decision 1880's 16957440 bytes into the live total when the painted columns are first allocated | 1880 Q2; ARCH-BUILD-001 | Whichever step first allocates them (P-C8) |
| 18 | Spoil: each cut posts 2000 milli-U of earth to adjacent legal capacity, and the ledger shows the batch's total earth. Underground spoil piles need an owner and bound | SET-BUILD-001 §8; ECON-003; decision 1075; 1880 "Deferred" | Ledger done in B; logistics C2 |
| 19 | Unfinished space is not a route. A room is published only when its cells are finished | MOVE-REQ-002; SET-BUILD-001 §8 | C2 |
| 20 | Nothing is deducted at Confirm all. Undo and Redo touch only pending work | BUILD-REQ-019, -020; REQ-SET-124–126; UX-BUILD-T04 | Kept from B |
| 21 | Scratch memory for room re-derivation and breadth-first order over up to 65536 cells per level | 1880 "Deferred" (slices C, F) | C1 (presentation scratch), C2 (authoritative) |

**Every slice-B deferral, and where it goes.** Each is recorded in 1871:

- P-B2 (b), merging joined pending rooms: C1, item 5.
- P-B5, the paint frame: C1, P-C5.
- P-B7, retiring the separate view: C1, item 12.
- P-B9, dashed and hatched outlines: C1, item 9.
- P-B10, the camera-relative cursor: C1, item 10.
- P-B11, no room orderable until C/D add the way in: still true after C1. Cleared by D plus C3.
- "No way in" per cell before confirm: C1, item 7.
- Painting on the actual World: C1, item 11.
- The three legacy cards: P-C2.
- E8, the demo's 4 m levels against DEC-061's 5 m: C1 paints at the level catalog's 5 m floors (P-C6).
- E27, the legacy cards' 0.2 s note refresh: goes when the legacy cards go.

## 2. Dependency truth, with evidence

Paths are under `godot/` unless stated otherwise. Line numbers are at 5977191b.

### 2.1 UG24, the underground dispatcher

`docs/underground-integration-status.md` (2026-10-05) is out of date. A production dispatcher now exists, but **only
for the first entry**.

- **The first entry: a fixed-tick driver exists, but nothing in the game starts it.**
  - The driver: `scripts/systems/settlement_system.gd:2239` calls `_advance_underground_entry` every tick, after
    `_run_productive_work`. At :2244–2250 it advances `UndergroundEntryRuntime` when one is running (ADR 1210 G7).
  - The runtime is the Jobs dispatcher for the entry (`bind_dispatcher`, ADR 1223). Its foreman
    (`scripts/core/underground_entry_foreman.gd`) runs open → travel → enter → start → earn → recover → install →
    haul → rest. It creates BUILD and HAUL Jobs, assigns the crew mole, and runs BRACE, CUT and FINISH through the
    Sites phase API.
  - It digs **only the authored first-entry stair**: frontier EPISODE rows, 8 installations (L0, T0, T1–T6;
    runtime :34). It does not dig arbitrary cells.
  - What starts it: `begin_underground_entry` (`settlement_system.gd:1948`). It needs the session at prefix 17,
    which is reached only after `compose_underground_surface_anchor` and `compose_underground_entry_owners`.
    Outside a save restore (`settlement_save_apply.gd:141`), no `scripts/` or `demo/` code calls either. Only
    tests do (`test/test_underground_host_whole_chain.gd` and others).
  - The demo stops short. `demo/demo_village.gd:600–604` composes room and route owners only.
  - It cannot run unaided even when started. Settlement stock is never moved to the entry's staging container
    (`ENTRY_HAUL_NO_STAGED_STOCK`, runtime :63); tests stage wood and stone by hand.
  - It ends at `ENTRY_KITCHEN_UNBUILT` (G9).
  - **Its floor is 1024 u below the surface** (ADR 1209: "floor −1024", source-local). Level 1's floor is world y
    512 − 5120 = −4608 (`underground_level_catalog.gd level_into` :260–277, pack `level_spacing_u` 5120). So even
    a finished entry is no way into level 1.
- **Confirmed rooms: no driver at all.**
  - `RoomOrders.confirm_room` (`scripts/core/underground_room_orders.gd:846`) publishes a spatial room, one Site per
    metre cube (`Sites.publish_room_claim_preflighted`), the Space geometry and the approach witness. It creates no
    Project, Job, worker or reservation.
  - `room_projects.gd` is not composed in production (`settlement_save_owners.gd:13`).
  - The "foreman-style Room loop" of ADR 1213 is test-only: `StepFixture.room_loop` in
    `test/test_underground_room_station_planner.gd:235–286`. It digs the DEC-054-clamped 8-cube fixture Kitchen.
  - It walks Sites in canonical key order (`underground_room_frontier.gd:78–104`), **not** BUILD-REQ-012's
    breadth-first order from finished space.
  - ADR 1202 "Kitchen excavation" steps 3, 4, 7 and 8 are open:
    - a runtime `Approach.Request` builder;
    - composing `bind_room_phase_contacts`;
    - a production Room foreman;
    - Delivery pinning for Room Projects (Delivery pins only the one entry Placement:
      `underground_connector_delivery.gd:245, 268–276`);
    - underground input and spoil logistics.
  - ADR 1213 adds two limits. A full Kitchen's station edges (60–100) reach the route budget (about 94 edges)
    unless finished station chains are retired. Each room is dug only as high as the published WORK rows reach
    (DEC-054).
- **Why the build panel's rooms are refused today.** `PROSPECTIVE_ENTRY_CONTACT_UNBOUND` (`underground_room_bindings.gd:40,
  155–158`) needs an `Approach.Request` with an existing completed access Location. Only
  `demo/burrow/modular_access.gd` (via `modular_room_mode.bind_access`) could build one, and nothing calls it.
- **The queue.** `docs/tasks/underground-build-queue.json` UG24 ("Actual demo owner, confirmation and fixed-tick
  composition") and UG09 ("First playable blueprint to empty Kitchen") are both `queued`.

### 2.2 HAUL-H3 and later

**Not landed.** H0–H2 merged as PR #225 and H6 as PR #220. (`work_queue.json` still shows H0–H2 as `review`; that
is stale.)

- `scripts/core/movement.gd:576–592`: `profile_clearance_class_into` still "ALWAYS REFUSES". No provisional class
  constant exists.
- `settlement_system.gd:132–135`: Movement is not composed, and nothing calls `advance()`.
- `settlement_system.gd:278–281`: nothing writes `JOB_STATE_WORK`.
- `settlement_system.gd:422–423, 916`: no HAUL job is posted.

**Slice C does not need HAUL-H3 for underground work.** The underground has its own live haul path, independent of
Movement:

- the chain is `underground_entry_hauler.gd` → `underground_connector_delivery.gd`, on `underground_routes.gd` and
  `underground_world_routes.gd`;
- it moves only wood and stone (`grip_certificate.gd:48`, "only wood and stone are certified");
- it serves only the entry Placement.

What a room dig would need from it:

- a room variant of Delivery's placement and endpoint leaves;
- staging settlement stock underground.

Spoil from a cut is made into a spatial ground pile (`excavation_inventory.gd:633–647, 728`), up to 400000 g per
pile (`inventory.gd:438`). It is never carried away, because earth has no certified carry. A room dig would also
need either more pile capacity next to each face or certified earth hauling. **HAUL-H3+ matters only for surface
legs**, such as moving settlement stores to the underground staging. The entry already declares that leg missing
(`ENTRY_HAUL_NO_STAGED_STOCK`).

### 2.3 What slice C cannot finish without, and what it can do now

- **Cannot finish without:**
  - a production room dispatcher (UG24's room half, ADR 1202 steps 3–8);
  - a qualified way into level 1 (slice D, OPEN-10 (a));
  - underground stock staging and spoil capacity.

  Until all three exist, Confirm all can order nothing that will ever be dug.
- **Can do now (C1):** everything a player sees and touches before Confirm all:
  - the shapes;
  - per-cell validity, including "No way in" and "Cannot dig here", read from the actual World's terrain survey
    (`underground_terrain.gd dig_refusal`) and its Sites;
  - merging, the ghost outlines and the camera-relative cursor;
  - painting on the actual World at the catalog's 5 m levels;
  - retiring the separate planner view.

## 3. Proposed sub-steps (P-C1 (b) as recommended)

One writer per file. Each step ends green: focused suites, the analyzer at `--port 6417`, the decision-number check
and the live harness frames.

| Step | Commit (in order) | Files (sole writer) |
|---|---|---|
| C1.1 | `feat(build): oval, paint and erase strokes, and merging joined pending rooms` | `scripts/ui/build_batch.gd`, `build_validity.gd`, `build_panel.gd` (shape strip, P-C7); `test/test_build_batch.gd`, `test_build_validity.gd`, `test_build_panel.gd` |
| C1.2 | `feat(build): validity per cell: 2 × 2, overlap, ground the crew can dig, and the way in` | new `scripts/ui/build_cell_validity.gd` (packed presentation scratch, one level of 65536 cells; injected terrain and finished-space readers); `build_batch.gd`; new `test/test_build_cell_validity.gd` |
| C1.3 | `feat(build): dashed and hatched, numbered ghost outlines` | `demo/build_panel/demo_build_ghost.gd`, a new ghost shader beside it (the planner's `modular_plan.gdshader` stays untouched); `test/test_demo_build_panel.gd` |
| C1.4 | `feat(build): the cell cursor follows the camera` | `demo/build_panel/demo_build.gd`; `test/test_demo_build.gd` |
| C1.5 | `feat(demo): paint on the actual World's levels; retire the separate planner view` | `demo/build_panel/demo_build_paint.gd`, `demo_build.gd`, `demo_build_orders.gd` (Confirm all holds back "No way in" cells, BUILD-REQ-013); `demo/demo_village.gd` (`_build_modular_room_mode` removed); delete `demo/burrow/modular_demo_mode.gd`, `modular_demo_live.gd/.tscn`, `test/test_modular_demo_live.gd`; `tools/ci_test_shard_weights.json`; `test/live/demo_input_live.gd` build steps |
| C1.6 | `docs(build): slice C1 records` | this record (gates, review, mutation); `godot/demo/README.md` section; `docs/ui_ux_controls.md` follow-up note; `docs/handoff/RULINGS.md`; `docs/underground-integration-status.md` corrected (§2.1) |
| C2 (own lane) | `feat(underground): a production room foreman on the fixed tick` | `scripts/core/` only, plus `settlement_system.gd`: ADR 1202 steps 3–7 (`Approach.Request` from live Locations, `bind_room_phase_contacts` composed, a room foreman with breadth-first order and up to 4 builders, Delivery's room pin, station-chain retirement); RoomProjects composed as one project per room; proven on fixtures with bootstrapped access. **No file is shared with C1**, so it can run in parallel |
| C3 (after D and C2) | `feat(build): Confirm all digs painted rooms` | `demo_build_orders.gd` and the panel's order route; the painted columns and the 1880 fold-in (P-C8); live dig frames |

C1 creates no authoritative state. The pending batch is presentation-side (ARCH-BUILD-001), and the per-cell
validity is presentation scratch, about 320 KB for one level. C1 therefore adds no ledger rows. Not one C1 file is a
pinned consumer: `tools/renew_source_pins.py` pins five `scripts/core/underground_*` files, two `demo/cast` actor
files and three `data/underground/mole-worker` programs.

## 4. Proposals for Brendan

**P-C1 — How to run slice C, given no room dispatcher and no way into level 1.**

- **(a)** Slice C builds the minimal dispatcher itself. That is ADR 1202 steps 3–8, Delivery's room variant, stock
  staging and spoil capacity. Even then nothing on level 1 could be dug before slice D, so the result is not
  playable. This would be several lanes' work inside one slice.
- **(b) Split.**
  - C1 now: everything before Confirm all, on the actual World.
  - C2 as its own lane, in parallel: the production room foreman, proven on fixtures.
  - C3 after D and C2: Confirm all digs.
- **(c)** Like (b), but C1 also lets the demo's legacy presentation warren dig painted rooms on its 4 m levels, so
  rooms can be dug in the demo now. It builds on code DEC-061 retires, never reaches the simulation, and goes
  against UG24's "never depicts unpaid completion".

**Recommendation: (b).** C1 delivers every visible part of EG2's painting now. C2 is the real dispatcher the GDD path
needs whatever the panel looks like. The study's dependency row is wrong in one direction: C's digging needs D's
entrance, so the order should be C1 ∥ C2 → D → C3. If (b) is chosen, the row should be corrected to say so.

**P-C2 — The Passage, Burrow home and Root cellar cards that open the old tools.**

- **(a) Keep them working until C3 makes painted rooms diggable.** Today they are the demo's only playable digging.
  In C1 the Passage *room type* card paints Passages; the old tunnel tool keeps its own card, renamed "Dig tunnel
  (old tool)".
- **(b)** Lock all three now with "Not yet: …".
- **(c)** Remove them now.

**Recommendation: (a).** Removing them before C3 takes digging out of the demo for one or more slices.

**P-C3 — How high a painted underground cell is priced and dug.**

SET-BUILD-001 §7.2 prices 4 quanta per cell, the level's 4096 u clear height. **DEC-054** ("build to needed height
and if claw strokes don't match that height that is Ok") caps a room at the band the published dig rows reach from
the floor. That cap is derived live: 2 m on content 6, and it follows the claw rows. RoomOrders already plans at that
height (`demo/burrow/modular_runtime.gd:381–386`). DEC-054 is Brendan's decision and outranks the amendment.

- **(a) The ledger prices the excavated height RoomOrders will actually cut**, `min(clear height, reachable height)`
  in whole quanta. §7.2 gets a DEC-054 note. On content 6 that is 2 quanta per cell: wood 500, stone 500,
  8460 milli-WU and earth 4000 milli-U.
- **(b)** Keep the 4-quanta price and change what RoomOrders cuts, which reverses DEC-054.

**Recommendation: (a).** No new number is needed.

**P-C4 — What counts as a way in for a drafted cell** (BUILD-REQ-013).

- **(a)** A drafted cell has a way in when a 4-connected chain of drafted cells on the same level, of any room type,
  links it to a cell face-adjacent to finished space, or to a built or drafted connector's landing. EG2 behaves this
  way: a room drawn beside a drafted corridor is fine.
- **(b)** Count only the cell's own room's cells.

**Recommendation: (a).** Under BUILD-REQ-013, "No way in" cells then hold Confirm all back. This replaces slice B's
"refused, retried" behaviour for that one reason. Until slice D, every room on levels 1–4 reads "! No way in" with a
dashed outline. That is honest, and C1's tests prove the rule on fixtures that do have finished space.

**P-C5 — Where the actual World sits under the demo village** (P-B5 revisited).

The actual underground covers the level pack's 0..256 m square. The demo village is drawn at ±20 m around the
origin, and it is not laid out from the settlement's starter positions. Today the build panel gives refusals under
the village ("water") with nothing drawn there.

- **(a) Keep the shared frame.** Show the actual World's refusals in words, and draw the actual terrain on the
  painted level so the player sees why.
- **(b)** Offset the cells so the village's centre lands on the settlement hall cell (116, 118). No document states
  this offset, and it still would not line the buildings up.

**Recommendation: (a).**

**P-C6 — What the view shows on levels 1–4 in build mode.**

- **(a)** The actual World's level at the catalog's 5 m spacing, with the actual World view inside the main camera.
  The legacy 4 m warren is hidden while a room type is armed on that level, and shown again for the old tools
  (P-C2 (a)).
- **(b)** Keep drawing the legacy warren and paint at the actual floors beneath it.

**Recommendation: (a).** Under (b) the ghosts would sit 3.25 m (level 1: legacy floor −1.25 m, actual −4.5 m) and 4.25 m (level 2) below the floors drawn, and levels 3–4 have no legacy floor at all.

**P-C7 — How shapes are chosen.**

- **(a) A four-button strip, "Rectangle · Oval · Paint · Erase", in the info card.** No new key; Tab reaches it.
  - Paint and Erase stamp a 2 × 2-cell brush, the smallest that meets BUILD-REQ-002.
  - Erase removes only pending cells.
  - An erase that would leave a strip is refused with BUILD-REQ-006's "Too narrow: this would leave part of …"
    words.
  - Removing confirmed cells stays slice F's Earth.
- **(b)** Also add Rounded and larger brush sizes.

**Recommendation: (a).**

**P-C8 — When decision 1880's 17.0 MB is folded in.** C1 allocates no painted column, so under 1880 Q2 the fold-in
moves to C3 (or C2, if it allocates first). Once it is folded in and C2/C3 ledger one project per room (23265280
bytes), **about 1.4 MB of headroom remains** (1880).

- **(a)** As ruled: fold it in when allocated.
- **(b)** Fold it in now, so no other lane spends it.

**Recommendation: (a).** It keeps C1 free of the pack tool and its pinned tests. Coordinators should know the
headroom is really 32.8 MB, not 49.7 MB.

**P-C9 — Where C2's dug order and crews come from.** BUILD-REQ-012 requires breadth-first order from finished space,
ties by cell index, with up to 4 builders. The existing room frontier walks canonical Site keys with one worker.

- **(a)** C2 changes the frontier to BUILD-REQ-012's order and adds parallel faces.
- **(b)** Amend BUILD-REQ-012 to the frontier's order.

**Recommendation: (a).** It is what the player sees ("the room opens outward"), and the change is in C2's own files.

## Also found (for the coordinator)

- `docs/underground-integration-status.md` "Next, in order" item 1 is stale. The entry dispatcher exists (§2.1). C1.6
  corrects it.
- `docs/planning/work_queue.json` lists HAUL-H0–H2 as `review`, but they merged (#225). This lane does not own the
  queue.
- The study's dependency table puts D after C. C's digging actually needs D's entrance (P-C1).

## Source

DEC-054, DEC-059 and DEC-061 (`docs/setting_decisions.md`); SET-BUILD-001; `docs/ui_ux_controls.md` UI-BUILD-001–014;
`docs/systems_architecture.md` ARCH-BUILD-001; decisions 1075, 1202, 1209, 1210, 1213, 1220, 1223, 1851, 1871 and
1880; `docs/tasks/underground-build-queue.json` UG09 and UG24; `docs/handoff/BACKLOG.md` HAUL-H3–H8; the code
citations in §2.
