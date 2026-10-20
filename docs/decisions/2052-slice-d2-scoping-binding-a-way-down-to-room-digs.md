# 2052 — Slice D2 scoping: binding a finished way down to the room-dig runtime (stopped for rulings)

Date: 2026-10-20 · Status: Proposed. Scoping only: no code and no data changed. Stopped for Brendan's rulings on
P-2052-1 to P-2052-11.

**Number.** The coordinator allocated 2051–2069 to D2, with 2051 for this record. **2051 is already used** by
`docs/decisions/2051-frontier-renewal-replays-at-its-publishing-commit.md` on the local, unpushed branch
`fix/renew-work-approach-profiles-test` (`7e8a521a`, 2026-10-16), and **2061** by
`2061-entry-crew-with-no-relief-stalls-dec-059-gap.md` on `claude/magical-gould-7bddad` (the stalled-crew session).
Either would collide if its branch merges, so this record takes **2052**, the first number in the range that is free on
every local and remote ref (`git for-each-ref refs/heads refs/remotes` + `git ls-tree`) and passes
`decision_numbers.py`. D2's later records should skip 2061. Branch `docs/slice-d2-scoping`, from origin/master
`d41269dd`.

**What was read.** Every path under `godot/` is at origin/master `d41269dd` unless marked **[M5]**. [M5] means the
read-only M5 branch `origin/feat/slice-d-m5-full` at `e99d7afb` (decision 2045's second build phase, before
P-2045-11's turning stop R′ is built). Decisions 1912, 1936, 1937, 1941, 1990, 1991, 2001, 2002, 2021, 2022, 2041 (with
§2.8), 2042, 2043, 2044 and 2045 [M5]; SET-BUILD-001 §9 and §12; the study's §5 D; and the coordinator's
`LIVE_WORK_SLICE_D.md`.

## Decision (as proposed)

D2 is three phases, and only the first can start before M5 merges.

1. **Phase 1, now (new files only).** Build the production way in (`StairWayIn`, replacing the test-only `ClawWayIn`),
   with its front station, foot store and spoil pile. Build the landings and shapes readers too. Prove both on the
   claw Kitchen fixture and on M5's geometry module, which is already on master.
2. **Phase 2, after M5 merges.** Bind the way in from the real entry runtime when it finishes and again on every
   load. Prove the six foot facts (§1 F3–F6, F9) on the live chain. Add the game checkpoint recipe and the S7
   restore-rebind fixture. Dig one level-1 room end to end on the live chain, with the level-1 store stocked as the
   fixtures stock R today.
3. **Phase 3, after stair-leg Delivery (decision 1941 §2) merges.** Switch the demo to real digging, retire decision
   1912's mole and meet M-4, as P-2052-5 to P-2052-8 are ruled.

**What decides the plan.** M5's foot publishes the access endpoint F′, the walk to the surface and the open floor,
but not everything a room order needs. Four gaps are D2's own:
- a WORK station in front of the room, needed for its admission;
- ground joins from the bottom F′;
- parking at the foot;
- the level-1 store and spoil pile.

Two gaps belong to other lanes, and they decide when the demo can show real digging:
- **no wood or stone can reach level 1** until stair-leg Delivery is built;
- **no settlement stock reaches the surface staging container R** until HAUL-H3+ (ADR 1210 G4). The test fixtures
  create it there.

## 1. Findings

**F1 — The seam is one object, held by the host and never saved.** Three places reset it to the base `WayIn`, which
refuses every level `ROOM_DIG_NO_WAY_IN`:
- the field itself (`scripts/systems/settlement_system.gd:928-929`);
- `mount_underground` (:1879);
- release (:2214).

`bind_underground_way_in` (:2065-2073) refuses with nothing mounted or while resetting. `order_painted_room`
(:2076-2100) hands the seam to `UndergroundRoomConfirm.confirm` (`scripts/core/underground_room_confirm.gd:63-86`).
That function checks the crew, then `way_in.approach_into(request, order)`, then `Composer.access_refusal`, then
RoomOrders' `confirm_room`, then `Composer.order`. **No save field holds the way in**, so after a load it must be
derived again (F7).

**F2 — What `approach_into` must fill.** It fills two objects:
- **The admission request** (`underground_room_approach.gd:41-52`). It has the access, the **work location**, the
  travel and work profiles and their revisions, the content revision, the target origin, the face and the yaw. Its
  input check (:656-659) refuses an invalid `work_location`, a missing revision, a face outside 0–5 or a yaw outside
  0–65,535.
- **The order** (`underground_room_composer.gd:46-55`). It has the access, the retreat travel row, and the storage,
  output and staging containers.

C3's fixture shows the shape (`test/test_underground_room_confirm.gd:74-95`). Every value comes from the claw
Kitchen's hand-authored endpoints:
- the corridor access `_first`;
- the Kitchen's WORK endpoint `_last`, or a second WORK endpoint the fixture publishes in front of the northern room
  (`_joined_work`, :50-71);
- the bound travel row;
- the fixture's one container, used as both storage and output.

**F3 — M5's foot is level 1's floor, by arithmetic.** M5 module j is translated by (0, −1,024j, −5,120j)
(`data/underground/full-level-flight-v1/flight_geometry.gd:65, 301`), and its floor is 1,024 u below its L0. So the
fifth module's run-out is 5,120 u below the origin. The fixtures' origin is at the land, y 512
(`test/fixtures/underground_entry_chain.gd:14`). So the foot is at **−4,608 u, level 1's floor** (SET-BUILD-001 §3).

A room is admitted only when its origin's y equals a roofed level floor in one of the catalog's sections
(`underground_room_bindings.gd:308-320`). `Site.suggest` keeps `near.y` unchanged
(`underground_entry_site.gd:44-55`). So **the foot meets a level-1 floor only when the Stair-head stands on its
section's land**: the floor plus 5,120 u. The ghost must judge this, or every room at that foot is refused
`ROOM_AUTHORED_LEVEL`. It needs a probe in phase 2.

**F4 — The bottom F′ has no ground joins.** [M5] Each landing publishes its floor stops F, UF and F′, with the
descent onto F, the half-turn, the ascent, the walk-off F → F′ (row 71) and the back-up F′ → F (row 72). **"But for
the last landing"**, it also joins F′ to P′, H′ and the hub D on the narrow approach (43) and the narrow retreat (47)
(`underground_entry_stair_path.gd` [M5] :15-31, `_landing` :225-241, `if landing == MODULES: return out` :235). At
level 1, F′ is therefore reached only from the stair. Nothing joins it to a floor beyond.

**F5 — No WORK station in front of a level-1 room.** Admission needs a profile path from the access to a **published
WORK endpoint** whose contact patch faces one of the room's cubes (F2; `underground_room_approach.gd:148-191`). The
room's own station planner publishes stations only for Sites that already exist
(`underground_room_station_planner.gd:1-4`). Sites exist only after admission, so it cannot supply the first one.
The demo's search (`demo/burrow/modular_access.gd:1-2`) states that "existing completed endpoints ... are never
manufactured".

At the foot, M5 leaves only stair stops. The deep stations of each landing leave row by row (`retire_row`, [M5]
stair path :26-31), and the last landing has no deeper layer to cut. **So a painted level-1 room has no work location
to be admitted from.** Nothing in decisions 1936, 2041 §2.8 or 2021 lists this gap.

**F6 — Parking and containers at the foot.**
- **Parking.** The parking planner tries points 2 and 3 quanta off the access in four directions, with the body
  inside the access's envelope (`underground_room_parking.gd:42-62, 107`). Failing that it takes an endpoint
  already authored as parking (`_authored_parking` :62). F′ stands in a slot 2 cells wide, between treads, the end
  wall and the slot walls. Whether any candidate fits is unproved.
- **Containers.** The entry's containers are M (storage) and R (spoil) on the surface
  (`underground_entry_runtime.gd:358-368`). A BRACE takes its inputs from the room's storage. When the storage is
  short, it hauls from staging, but only on the same level: a staging container on another level is refused
  `ROOM_HAUL_NO_STAIR_CARRY` (`underground_room_builder.gd:76, 413-443`). The stair carry exists only from H to
  module 0's sill until stair-leg Delivery is built ([M5] stair path :26; decision 1941 §4).
- **Spoil.** It needs legal capacity on level 1 (ECON-003). One ground pile holds about 200 cubes, about 50 cells
  (decision 2042 F, line 82). Beyond that, the earth carry of 2b-2 must take spoil up the stair.

**F7 — Save and load.** The two records are restored in order: the entry's (`settlement_save_apply.gd:341-352`), then
the rooms' (:355-366). The rooms' record rebinds its contacts from the access it saved
(`underground_room_composer.gd:308-320`; `settlement_system.gd:2000-2012`). **The way in is not restored at all.**
After a load, a game whose way down is finished refuses every new painted room "No way in" until something binds
it again. Decision 1937's mutant S7, "the host's restore without its contact rebind", is still deferred: "no host fixture has a way in until
slice D" (1937 §8). Decision 1936 P-1936-4 (a) owes "the game checkpoint recipe when slice D makes a room diggable". The
only recipes today are `underground_entry` and `underground_spare` (`test/fixtures/checkpoint_recipes.gd`).

**F8 — Neither host composes enough to dig.**
- **The game** mounts only (`scripts/systems/ui_manager.gd:277`).
- **The demo** mounts and composes the room and route owners only (`demo/demo_village.gd:590-608`).

`begin_underground_entry` needs the surface anchor and the entry owners as well: prefix 17
(`underground_entry_runtime.gd:120-132`). The room runtime's owners are bound only in
`compose_underground_entry_owners` (`settlement_system.gd:2032-2047`). Today only the save path's re-mount
(`settlement_save_apply.gd:136-146`) and the test fixtures compose all four.

**F9 — The real entry may not start where the player placed it.** `begin_underground_entry(near)` surveys outward
up to `SEARCH_RINGS` = 8 rings from `near` and takes the first origin that passes (`underground_entry_runtime.gd:24,
327-336`; `underground_entry_site.gd:44-55`). If the panel's ghost judged only the placed anchor and the survey moved
the origin, the stair would be built somewhere the player did not choose. Ring 0 is the centre, so judging the ghost
with the same `Site.survey` makes the origin the anchor.

**F10 — The real entry needs stock staged at R, which only fixtures put there.** The entry's hauler carries from R to
M. When R is short it stops `ENTRY_HAUL_NO_STAGED_STOCK`, with the gap text "moving settlement stores to the entry
anchor is not built (ADR 1210)" (`underground_entry_hauler.gd:29`; `underground_entry_runtime.gd:63`). The chain
fixture creates the lots at R directly (`test/fixtures/underground_entry_chain.gd:37-51`). HAUL-H3, which builds
settlement hauling, is `blocked` in `docs/planning/work_queue.json`. M5's bill is wood 77,500 and stone 38,500
milli-U (SET-BUILD-001 §9).

**F11 — One real way in per World.** The host keeps one entry runtime, and the entry plans "the one live entry
Placement" (`settlement_system.gd:925`; `underground_entry_runtime.gd:468-478`). The room contacts bind once, to the
first order's access and travel row, and refuse another (`ROOM_DIG_OTHER_ACCESS`, `underground_room_composer.gd:252-285`;
P-1936-1 (a)). Only the earth/timber Stair-head is qualified; the Burrow mouth and Hatch are placeholders (decision
2022). Nothing builds a way between underground levels.

**F12 — The build is long.** [M5] Decision 2045's second build reached module 1's end and stopped at tick 51,157:
about 28 minutes at 1x for less than two of the five modules. The whole flight spans days, with rest hours in between
(P-2045-10). A demo player who confirms a Stair-head waits most of an hour or more at 1x.

**F13 — No real removal exists.**
- RoomOrders removes no room before slice F (decision 1991 E1), and nothing removes the entry's Placement.
- D1's BUILD-REQ-017 check (`scripts/ui/build_way_graph.gd`, bound in `demo/build_panel/demo_build.gd:290`) runs over
  the proof of concept's space.
- MOVE-REQ-008's check over Routes is not implemented (decision 2021 F6).

**F14 — Mound homes are demo-only.** BUILD-MOUND-021 places a Way-down on a Mound room's floor. Mounds in the game
wait for MOUND-REAL, "after MOUND-TERRAIN, C3, D, E, G" (`docs/handoff/BACKLOG.md:84`). M5 needs 2 × 27 cells, which a
typical home cannot hold. BUILD-MOUND-021 then refuses it with its reason (decision 2041 §2.7). The demo's Mound
hatch is a proof-of-concept 2 × 2 (decision 2002 E15).

**F15 — M-4.** RoomOrders' admission checks neither BUILD-REQ-002's 2 × 2 block nor the type minimum (decision 1991
§3b M-4). The demo's Stop puts the undug cells back in the plan as a new pending room (`build_batch.gd:1422-1438`).
In the real route, a stopped room stays confirmed and is re-ordered whole. So a separate new room made of its
put-back cells would be a second admission over cells the first room already reserved.

## 2. The nine questions

### 2.1 The binding: what, from where, and when

**What.** A `StairWayIn` (`extends UndergroundRoomConfirm.WayIn`, new file `scripts/core/underground_way_in.gd`)
holds a **Foot** packet:
- the level it serves (1);
- the access (the bottom F′);
- the retreat travel row (the claw floor walk, from the mounted content);
- the foot's open box;
- the three containers' handles once made.

Its `approach_into(request, order)`:
- refuses `ROOM_DIG_NO_WAY_IN` for any other level, with "No way in: needs a way down to level N" (C3's words);
- finds or publishes the room's front station (P-2052-1) and fills the request from it;
- sets `order.access` to F′ always (so `ROOM_DIG_OTHER_ACCESS` never fires on one foot) and the travel row;
- makes or finds the foot store and pile (P-2052-2) and puts them in the order.

**From where.** The finished entry runtime: its `step()` is `STEP_DONE` and its origin, R and M. The stair path's own
`Stops`/`classify` give the bottom F′, F and UF from live Locations ([M5] stair path :84-160). It reads them and edits
nothing. The Foot is a pure function of saved owners: the entry record, Locations, Inventory and Profiles.

**When.**
- **At M5's completion**: on the tick `UndergroundEntryRuntime.advance` returns `ENTRY_KITCHEN_UNBUILT` with
  `step() == STEP_DONE` (`underground_entry_runtime.gd:141-163`), inside the host's `_advance_underground_entry`
  (`settlement_system.gd:2367-2375`). The host then derives the Foot and calls `bind_underground_way_in`. The
  crew's walk-out (decision 1940) carries on; it does not hold up the binding.
- **On load**: right after `restore_underground_entry` adopts a `STEP_DONE` runtime (`settlement_system.gd:2019-2029`),
  and before the rooms' record is applied. Once the rooms' record is in, the host checks that its saved
  `contacts_access` equals the derived F′, and refuses the load `ROOM_DIG_OTHER_ACCESS` if they differ. The derivation
  adds **no save field**.
- **On a remount or release**: unchanged; C3 resets the seam (F1). **On removal of the way**: none exists before
  slice F (F13). The rule recorded for slice F is that a removal resets the seam through the same host call and is
  refused first under §2.7.
- **While the way is being built**: nothing is bound. Rooms confirmed then wait in the panel (P-2052-3).

**Several ways in.** One entry runtime per host, one access per World (F11). So D2 binds exactly one `StairWayIn`,
and a second Stair-head waits for a later slice (P-2052-4). A per-access binding needs
`underground_room_world_bindings.gd` (Slice C's) and several entry runtimes. Both are recorded as later work, not D2's.

### 2.2 The foot of the stair: what M5 publishes, and every gap

| # | A room order needs | M5's foot gives [M5] | Gap | Owner |
|---|---|---|---|---|
| 1 | A roofed level-1 floor at the room's origin | The run-out at origin y − 5,120 | Holds only when the Stair-head stands on its section's land (F3) | **D2** (ghost judgement + phase 2 probe) |
| 2 | An access Location (`Order.access`) | F′ at landing 5, on natural earth (P-1972-8) | Must be accepted by `bind_room_phase_contacts` as the retreat (`underground_room_world_bindings.gd:54-72`); unproved | **D2** probe; if refused, **M5** (its stop's role) |
| 3 | Routes to the surface | Empty WALK both ways (after P-2045-11's R′) | None for walking. Room crews do not use it in any case: their walk-in is ADR 1219's timed walk (P-1936-6 (a)) | — |
| 4 | Ground joins from the access | None at the last landing (F4) | Spans from F′ to the front station and the parking | **D2** (public staging calls, as `underground_room_parking.gd` does) |
| 5 | A WORK station facing the room (admission) | None (F5) | One front station per room | **D2** (P-2052-1) |
| 6 | A travel row (`Order.travel`) | The claw floor rows in content 12 | None; D2 names the row | **D2** |
| 7 | A SUPPORTED_VOID within one cube of the room's floor layer | The run-out's finished cubes | Probe that they are SUPPORTED_VOID regions (`underground_room_dig_order.gd:90-98`) | **D2** probe; **M5** if not |
| 8 | Parking off the access | — | The slot may hold no candidate (F6) | **D2** (publish one TRANSIT parking in the run-out if the planner finds none) |
| 9 | Storage on level 1 | — | No container on level 1 | **D2** (P-2052-2) |
| 10 | Stock in that storage | — | Nothing carries wood and stone below module 0's sill | **Stair-leg Delivery** (1941 §2) |
| 11 | Stock at the surface staging R | — | Settlement stores never reach R (F10) | **HAUL-H3+**; a demo stand-in under P-2052-7 |
| 12 | Spoil output on level 1 | — | No level-1 pile | **D2** (P-2052-2) |
| 13 | Spoil once that pile is full (about 50 cells) | — | Up the stair to the surface | **2b-2** earth carry (decision 2042, P-2042-4 (a)) |
| 14 | M5's own deep spoil and its own completion | M5's chain | — | **M5** |

**Rows 10 and 13 also depend on row 9's position.** Stair-leg Delivery delivers to the level-1 store's stand, and
2b-2 carries from the pile. So P-2052-2 fixes where both containers stand, before either lane builds.

### 2.3 The game's landings reader, and the build panel's view of built ways

- **The readers.** New stateless `scripts/core/underground_way_landings.gd` and two host queries:
  - `SettlementSystem.underground_way_landings(level) -> PackedInt32Array` gives the foot cells on level 1, in the
    panel's cell pairs. They are computed from the entry origin with `flight_geometry.gd`'s `layout_*` M5 functions,
    equal to D1's `Items.landings` for a Stair-head at that anchor (decision 2021 E4). They are returned while the
    entry is confirmed and running, because P-D1-7 (a) counts a confirmed way as a way in, and again once it is done.
  - `underground_way_shapes(level)` gives the real way as an (x, z, family, turn) quad for `bind_way_host`
    (`build_batch.gd:270-275`).
- **The game.** Its Build button stays off until slice G (ruling 1871; decision 2021 F4). So in D2 nothing in the game
  binds these readers. D2 writes them in core, tests them headless, and binds them in the demo at phase 3, in place
  of `works.landings_on` (`demo_build.gd:264`). **Slice G** binds them to the game's panel. The game's boot also
  composes only the mount (F8). Composing the prefix and calling `begin_underground_entry` from the Stair-head is a
  host call D2 adds, `build_underground_way(anchor)`, which the game reaches only through G's panel.
- **Built ways in the panel.** The real Stair-head is a confirmed way with its card's progress (P-2052-8). The Burrow
  mouth and the Hatch follow P-2052-4.

### 2.4 The demo switchover

**What has to change.** Retiring the mole means each of these:
- the demo composes the surface anchor and the entry owners at mount (F8);
- a confirmed Stair-head calls `build_underground_way`;
- rooms on level 1 go through `order_painted_room`, and Stop through `stop_underground_room` (C3's routes);
- the proof of concept's digging files are deleted: `demo_build_works.gd`'s ordering and digging,
  `demo_build_crews.gd`, `demo_build_below_task.gd` and `demo_build_figure.gd`;
- "Proof of concept" leaves the card.

**What the demo can show before stair-leg Delivery.**
- A real Stair-head being built, with stock at R (F10, P-2052-7). It takes most of an hour or more at 1x (F12).
- Then level-1 rooms admitted and ordered. **Every BRACE then stops `ROOM_HAUL_NO_STAIR_CARRY`**, because no wood or
  stone can reach the level-1 store (§2.2 rows 10–11). The room foreman treats that refusal as a stop with an alert
  (`settlement_system.gd:2377-2390`), not a wait.

**Keeping it honest.** Switching before stair-leg Delivery would replace a labelled proof of concept with rooms that
always stop. Switching later keeps the label. P-2052-6 recommends switching once, when a level-1 room can really be
dug in the demo. Whenever the switch comes:
- nothing is conjured: P-2052-7's stand-in moves real village stock and is labelled;
- nothing unpaid is drawn as dug (UG24 holds again);
- every refusal is shown in words.

### 2.5 Save, load and restore

**The game checkpoint recipe** (P-1936-4 (a)). Add `underground_level1` to `test/fixtures/checkpoint_recipes.gd`,
with two points:
- `way_in_bound`: the entry `STEP_DONE` and its crew walked out;
- `level1_room_brace`: a 2 × 2 room painted against the run-out's end face, in its first funded BRACE.

The recipe stocks the level-1 store the way the chain fixture stocks R (`underground_entry_chain.gd:47-51`), and says
so in its header. That stocking is removed when stair-leg Delivery lands. The chain is longer than 51,000 ticks
(F12), so generating the recipe takes tens of minutes. That is accepted: under decision 1240 a recipe is rebuilt only
when its fingerprint goes stale.

**The S7 restore-rebind fixture** (decision 1937 §8). A host suite loads `level1_room_brace` into a fresh host and
runs on. It checks:
- next-tick parity against the uninterrupted run (ARCH-SAVE-006);
- the room finishes;
- after the load, `order_painted_room` admits a second room, which proves the way in was derived again with no save
  field.

Mutants to kill:
- S7 (drop `UndergroundRoomComposer.rebind` in `restore_underground_rooms`);
- "no way-in rebind on load";
- "way in bound before the entry is restored".

### 2.6 M-4's obligations (decision 1991 §3b)

Under the real route, Stop keeps the room confirmed and **Resume** re-orders the same room through
`order_underground_room`, so a paid phase is taken over and never paid twice (P-1933-2 (a)). The undug cells are
never put back in the plan as a new room. So `return_cells` (`build_batch.gd:1422-1438`) is not used for a real room,
and E9's put-back judging is not needed for it. Erasing a stopped real room's cells is refused until slice F's
removal. This is P-2052-5. The other option, put-back cells refused by core's own rules, is (b) there.

### 2.7 The removal rule (BUILD-REQ-017) against the real runtime

Nothing can remove the real Stair-head or a real room before slice F (F13). In D2, a click on the real way therefore
asks nothing and says "Not yet: removing a way down comes with slice F" (P-2052-9). D1's graph check keeps judging
proof-of-concept ways until phase 3 retires them, and it keeps judging the demo's Mound doors.

Slice F, with its Remove tool, owns the real check (MOVE-REQ-008), built over Routes and Inventory. Before any
removal it must refuse while any of these hold:
- a room record is kept;
- a resident is registered below;
- a lot is stored in the level-1 store or pile;
- a reservation holds below.

### 2.8 Mound homes (BUILD-MOUND-021)

In the real route, M5 on a Mound floor is refused by BUILD-MOUND-021's own rule ("<Item> does not fit in this room:
it needs 2 × 27 cells", decision 2021 P-D1-12). The real Mound waits for MOUND-REAL, and a Mound way down needs a
compact family (OPEN-02 authoring). Under P-2052-4 the demo's Mound hatch is locked with the other Hatch at the
switchover. P-2052-10 asks whether to keep it as a labelled proof of concept instead.

### 2.9 File plan and sequencing: see §5 and §6.

## 3. PROPOSALS for Brendan

**P-2052-1 — Where a level-1 room is dug from (the front station, F5).**
- **(a) The way in publishes one WORK station for each room ordered.** It stands in the run-out, in front of the
  room's cube nearest F′, and uses the claw wall rows of content 12. It is joined to F′ by ground spans through the
  public staging calls, as parking already publishes endpoints. A room must touch the foot's open floor (the
  run-out's end face or sides). If the room is refused, the station is withdrawn. Once the dig ends, the station
  leaves with the room's other stations (decision 1942's retirement).
- (b) M5's foot publishes a fixed set of WORK stations around the run-out at completion. Rooms must face one of
  them. This needs M5's claimed files after M5 merges, and every room shape is limited to those faces.
- (c) Only cells that a station already facing them reaches.

**Recommendation: (a).** It is the fixture's own `_joined_work` shape, made production, and it touches no M5 file.

**P-2052-2 — Where the first level-1 room's materials and spoil go.**
- **(a) One level-1 store and one level-1 spoil pile, each a ground staging on a new endpoint beside F′, at fixed
  offsets clear of the stair and of parking.** They are made on the first order and found again by their points after
  a load. Staging is the surface R. Stair-leg Delivery delivers to the store's stand, and 2b-2 carries from the pile.
- (b) The surface M as storage and R as output. Every BRACE is then refused at route time, because no carry route
  reaches level 1.
- (c) One level-1 container for both, as the fixture does. The earth then takes the space the wood and stone need.

**Recommendation: (a).**

**P-2052-3 — Rooms confirmed while the way down is still being built.** BUILD-REQ-013 (OPEN-07 (a)) confirms them,
and their digging waits. RoomOrders cannot admit them before the foot exists.
- **(a) The panel holds them as "Waiting for the way down"**, unsaved like the batch, and sends them through the real
  route on the tick the way in binds. Slice G saves them, with decision 1880's painted store.
- (b) A saved waiting list now: a new saved owner, a registry entry and a census row.
- (c) Admit them without an approach. This changes RoomOrders and the approach witness, which are Slice C's.

**Recommendation: (a).** The game has no panel until G, and the demo does not save.

**P-2052-4 — More than one way down.**
- **(a) One real way down per settlement for now.** Only the Stair-head is offered for real, and once. A second shows
  "! Blocked: one way down for now". The Burrow mouth and the Hatch, and every way on levels 1–3, are locked "Not
  yet: ...".
- (b) Keep the other families as free, labelled proof-of-concept ways beside the real one. Rooms reached only through
  them are refused "No way in".
- (c) Several real ways: a per-access contact binding (Slice C's file) and several entry runtimes.

**Recommendation: (a).** (b) mixes free and real in one view. (c) is a slice of its own.

**P-2052-5 — Stop and Resume in the real route (M-4).**
- **(a) Stop keeps the room confirmed.** Its undug cells stay drawn as that room ("Stopped: 5 of 16 cubes dug"), its
  card offers "Resume digging", which re-orders the same room, and Erase on them is refused "Not yet: removing a
  confirmed room comes with slice F".
- (b) As in the demo today, the cells go back to the plan as a new room. Confirm refuses it by core's 2 × 2 and
  minimum rules, judged with the dug part.

**Recommendation: (a).** It is what core does. (b) would ask RoomOrders to admit over cells it already reserved.

**P-2052-6 — When the demo switches over.**
- **(a) Once, at D2's phase 3, after stair-leg Delivery merges.** Until then the mole stays, labelled "Proof of
  concept" (decision 1991).
- (b) At phase 2. The mole is retired, the real Stair-head is built, and level-1 rooms are ordered, but each stops
  "No way to bring wood and stone down yet".
- (c) At phase 2, with a labelled stand-in that fills the level-1 store.

**Recommendation: (a).** P-1990-1 (b) kept the mole so that the demo stays playable and claims nothing real that is
not. (b) breaks the first, and (c) repeats the stand-in that P-1990-2 (b) rejected.

**P-2052-7 — Stock at R for the demo's real Stair-head and rooms (F10).**
- **(a) A labelled stand-in for ADR 1210's G4 only.** When the entry's or a room's haul finds R short, the demo moves
  exactly the missing whole units from the village's stores into R, says "Carried to the stair site (stand-in for
  hauling)", and waits "! Not enough wood" when the village is short. The stock is deducted, never conjured. HAUL-H3+
  replaces it.
- (b) Wait for HAUL-H3+, which is blocked. The demo keeps the mole until then.
- (c) Put the stock at R free, as the test fixtures do, labelled "free".

**Recommendation: (a).** It covers exactly the one missing capability, by the economy's own lots. Unlike P-1990-2
(b), it moves stock rather than consuming it: BUILD-REQ-019's payment still happens when each phase starts.

**P-2052-8 — An hour-long build in the demo (F12).**
- **(a) No shortcut.** The way's card shows progress ("Module 2 of 5; the crew rests at night"), and the time
  controls do the rest.
- (b) A demo boot option that starts at the foot from a committed save. The demo has no load path.
- (c) A shorter demo-only stair. It would not be qualified.

**Recommendation: (a).**

**P-2052-9 — Removing a real way (BUILD-REQ-017; F13).**
- **(a) Refused for now, "Not yet: removing a way down comes with slice F".** D1's graph check stays on
  proof-of-concept ways and Mound doors. Slice F builds the Routes check.
- (b) Build the Routes and Inventory check now, with nothing but a test to call it.
- (c) Feed D1's graph from the real state, so the refusal names what it would cut off.

**Recommendation: (a).**

**P-2052-10 — The demo's Mound hatch at the switchover.**
- **(a) Locked with the Hatch "Not yet"**. In the real route, M5 on a Mound floor is BUILD-MOUND-021's "does not
  fit" refusal.
- (b) Kept as a labelled proof-of-concept way. That contradicts P-2052-4 (a) for one case.

**Recommendation: (a).**

**P-2052-11 — New words.** "Way down to level 1 built: paint rooms against its foot", replacing the
`ENTRY_KITCHEN_UNBUILT` gap alert (`settlement_system.gd:2399-2403`) with a notice. "Waiting for the way down". "!
Blocked: one way down for now". "Not yet: removing a way down comes with slice F". "Not yet: removing a confirmed room
comes with slice F". "Resume digging". "Module j of 5". "Carried to the stair site (stand-in for hauling)".
- (a) As worded.
- (b) Other words.

**Recommendation: (a).**

## 4. Engineering choices (recorded, not asked)

- **E1 — No save field.** The way in, the Foot and the containers' handles are derived again from the entry record,
  Locations and Inventory (§2.1). The memory census counts **0 B** for the way in, because one object is live at a
  time (as C3 counted it, decision 1991 §5). The front stations, spans, parking, store and pile live in Locations and
  Inventory, which are already bounded and saved. The phase 2 census proves the room-dig peak against Locations'
  capacity of 1,024 (decision 2044) before anything grows.
- **E2 — Reading the entry without editing it before M5 merges.** The host reads `step()` and `origin()`. Public
  `storage()` and `output()` readers on `underground_entry_runtime.gd` come in phase 2 (one small edit to a file M5
  claims), replacing the fixture's reads of `_storage` and `_output`.
- **E3 — The Stair-head's ghost uses `Site.survey` at the placed anchor**, so the survey's ring 0 is the origin (F9).
  Its words come from the survey's refusal, plus F3's check that the land lies a level-1 floor's 5,120 u above.
- **E4 — The finishing tick's alert becomes a notice** (P-2052-11). `ENTRY_KITCHEN_UNBUILT` stays the entry's
  terminal code, so no entry file changes.
- **E5 — Phase 1 proves the production way in on the claw Kitchen** by giving it a Foot built from the fixture
  (access `_first`, the bound row, the fixture's level). C3's `ClawWayIn` then becomes a thin test of the real class.

## 5. Files

| Phase | File | Change | Held by |
|---|---|---|---|
| 1 | `scripts/core/underground_way_in.gd` (new) | `StairWayIn`, `Foot`, front station, foot store and pile | D2 |
| 1 | `scripts/core/underground_way_landings.gd` (new) | Landings and shapes from origin + `flight_geometry.gd` M5 | D2 |
| 1 | `test/test_underground_way_in.gd`, `test_underground_way_landings.gd` (new); `test_underground_room_confirm.gd` (its WayIn) | Tests | D2 (C3's suite: an additive change) |
| 2 | `scripts/systems/settlement_system.gd` | Bind at finish and after entry restore; `build_underground_way`, the two readers, the notice | Host (C3 edited the order, stop and release routes only) |
| 2 | `scripts/core/underground_entry_runtime.gd` | `storage()`, `output()` readers | **M5** (after it merges) |
| 2 | `test/fixtures/checkpoint_recipes.gd`, `test/fixtures/checkpoints/underground_level1*` (new), `test_underground_way_in_host.gd` (new) | Recipe, S7, live gate | D2 |
| 3 | `demo/demo_village.gd`, `demo/build_panel/demo_build.gd`, `demo_build_way_host.gd`, `demo_build_ways.gd`; delete `demo_build_crews.gd`, `demo_build_below_task.gd`, `demo_build_figure.gd`; `demo_build_works.gd` reduced to drawing; `demo_build_orders.gd` retired | The switchover | D2 (C3 and the Mound lane have merged) |
| 3 | `scripts/ui/build_room_card.gd`, `build_batch.gd`, `build_connector_families.gd`, `build_catalog.gd`, `build_validity.gd` | Resume, waiting rooms, locks, words | D2 |
| 3 | `test/live/demo_build_dig_live.gd`, `demo_build_crew_live.gd`; `godot/demo/README.md`; guide text; `docs/ui_ux_controls.md`; `docs/underground-integration-status.md`; UG09 in `docs/tasks/underground-build-queue.json` | Harness, words, status | D2 |

**Not touched by D2.**
- M5's claims (2044 and 2045): stair path, entry bindings, the named Locations functions, foreman, work area, site,
  compositions, Frontier, retirement scope, installer, progress, the six held WorldRoutes functions, the journal and
  the budget.
- Stair-leg Delivery's and 2b-2's: `underground_connector_delivery.gd`, `underground_entry_hauler.gd`,
  `underground_room_builder.gd` and the certificates.
- Slice C's `underground_room_world_bindings.gd`, `underground_room_orders.gd` and the approach.

D2 reads the stair path's `Stops` and `classify` only.

## 6. Phased build plan and gates

**Phase 0 — rulings.** Brendan rules P-2052-1 to -11. They are recorded here and in `docs/handoff/RULINGS.md`.

**Phase 1 — now, before M5 merges.**
- **Work.** §5's phase 1 files.
- **Gates.**
  - Focused suites.
  - The analyzer, 0 warnings, on a port the coordinator assigns.
  - `decision_numbers.py`.
  - `git diff --name-only origin/master` naming no file M5, Delivery, 2b-2 or Slice C holds.
  - Mutation testing and an independent review.
- **Stop** if the front station cannot be published from the fixture's access with the claw rows. Report with
  options before any phase 2 work.

**Phase 2 — after M5 merges** (merge master, regenerate pins, census and checkpoints; never hand-merge them).
1. **The probe, first.** On the live chain at `STEP_DONE`, prove the foot facts and stop on the first that fails:
   - F3: the foot is a level-1 floor;
   - row 2: F′ is accepted as the room contacts' retreat;
   - row 7: the run-out is SUPPORTED_VOID within one cube of a room painted against it;
   - row 8: parking at the foot;
   - row 4: the front station's spans from F′.
2. The host binding, the readers, E2's readers, the recipe and S7.
3. The live gate: a room painted against the run-out is admitted, ordered and dug to its last cube on the live chain,
   with the level-1 store stocked by the fixture. A room with an empty store refuses `ROOM_HAUL_NO_STAIR_CARRY`,
   pinned until stair-leg Delivery.

**Phase 2 gates:**
- the full suite CI-style at master's shard count (12 after #278);
- the analyzer;
- every contract, the `underground-memory` job's three commands included;
- the SHA trace byte-identical on the room and entry benches;
- checkpoints regenerated, with the saves byte-identical where the simulation did not move;
- mutation testing and an independent review;
- frames at 1280 × 720 and 1920 × 1080 of the level-1 room opening at the foot.

**Phase 3 — after stair-leg Delivery merges**, with P-2052-6 and -7 as ruled; 2b-2 merged for rooms past the first
pile.
- **Work.** §5's phase 3 files. Retire the mole. Move UG09 to `review`.
- **Gates.**
  - The phase 2 gates.
  - The live harnesses at both sizes: Stair-head confirmed, the way built, a room painted, dug, stopped, resumed and
    finished, the Mound hatch locked.
  - Every frame looked at.

**Before M5 merges, only phase 1 can start.** Phases 2 and 3 wait for M5, and phase 3 also waits for stair-leg
Delivery. Stair-leg Delivery needs P-2052-2's store position, so phase 2 should land, or at least fix that position,
before it builds.

## 7. Risks

- **The foot probe may fail** (rows 1, 2, 7, 8). Each failure is either D2's to fix in its own files, or M5's stop
  geometry after M5 merges. Phase 2 stops and reports either way.
- **Cold-operation cost.** Every front station, span and parking publication requalifies the live graph. M5's peaks
  are 91.8 % (WorldRoutes) and 92.5 % (bindings) of the check bound ([M5] 2045, "Second build phase"). A level-1 room's
  publications may overflow `Space.MAX_CHECKS`; there is no headroom to raise it (P-2044-15, "Exact cost fixes"). The
  probe measures it first.
- **The recipe's length** (F12) makes each checkpoint regeneration tens of minutes.
- **The two number collisions** above, 2051 and 2061, belong to other branches. The coordinator should see that they
  are renumbered or abandoned.

## Gates run (this record)

`python3 docs/validation/decision_numbers.py`: `decision_numbers: PASS` (see the commit). No Godot run was needed
(docs only).

## Source

DEC-054, DEC-059, DEC-061; SET-BUILD-001 §3, §7, §9, §12, BUILD-REQ-002, -012, -013, -015, -016, -017, -019,
BUILD-MOUND-021; MOVE-REQ-002, -008; decisions 1871, 1880, 1912, 1933, 1936, 1937, 1940, 1941, 1942, 1990, 1991,
2001, 2002, 2021, 2022, 2041–2045; the study's §5 D; `docs/handoff/LIVE_WORK_SLICE_D.md` (2026-10-20); the code cited
above at origin/master `d41269dd` and [M5] `origin/feat/slice-d-m5-full` `e99d7afb`.
