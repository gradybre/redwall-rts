# 1991 — Slice C3: the real Confirm route, the player's crew and one Stop digging

Date: 2026-10-19 · Status: Built (the build record of decision 1990; Brendan's rulings P-1990-1 to P-1990-5, all as
recommended, 2026-10-19). Branch `feat/slice-c3-confirm` from origin/master `8a7d045d`. Number range 1990–1999.

## Decision

C3 is built as decision 1990 scoped it and Brendan ruled. **Two halves:**

1. **The game's real route, in core, behind one seam slice D2 fills** (P-1990-1 (b)). A painted room is admitted
   through RoomOrders, ordered with the crew the player named, dug by the room foreman and paid phase by phase when
   work starts (BUILD-REQ-019; P-1990-2 (a)). Until a level has a way in, the game refuses every painted room
   `ROOM_DIG_NO_WAY_IN`, "No way in: needs a way down to level N", before anything is admitted.
2. **The demo keeps decision 1912's mole**, labelled "Proof of concept", free and unsaved, now with **the crew**
   (P-1990-4 (a)) and **Stop digging** (P-1990-5 (a)). D2 switches the demo to the real route and retires the mole.

Decision 1880's store is **not** allocated (P-1990-3 (c)); its fold passes to slice G (1880's "Deferred" table and
note, ARCH-BUILD-001's text).

## 1. The real route (`scripts/core/`)

| Piece | File | What |
|---|---|---|
| Painted Confirm route | `underground_room_confirm.gd` (new, stateless) | `Painted` (level, type, origin, cells, the panel's dug height, the crew), `WayIn` (the seam), `confirm`: the crew checked, then the way in and its access, then RoomOrders' admission, then the composer's order |
| The seam D2 fills | `settlement_system.gd` `bind_underground_way_in` | Held by the host; the base `WayIn` refuses every level |
| Order, Stop | `settlement_system.gd` `order_painted_room`, `stop_underground_room` | Named refusals and alerts, as `order_underground_room` |
| Waiting rooms start | `settlement_system.gd` `_advance_underground_rooms` | After the runtime's advance (see "The tick order") |
| The crew | `underground_room_composer.gd` `Order.crew`, `crew_refusal`, `start_waiting` | 1-4 named residents, each a living adult mole free of tools; none named: the first idle mole (P-1936-2 (a)'s rule) |
| The record | `underground_room_runtime.gd` `order_room(…, crew)`, `crew_of`, `queued_into`, `stop_room` | Each slot names its crew and a release-once-out flag; saved |
| The Stop | `underground_room_foreman.gd` `stop` | `_halt(ROOM_DIG_STOPPED)`: the one stopping path |
| Record version 2 | `underground_room_progress.gd` | Each record row adds 33 bytes |

**E1 — Order of checks, so a refusal changes nothing.** The crew (`Composer.crew_refusal`), then the way in
(`WayIn.approach_into`) and its access (`Composer.access_refusal`, read without binding: one access until a per-access
binding exists, P-1936-1 (a)), then `RoomOrders.confirm_room`. Once RoomOrders has admitted the room, only a
parking or a plan refused at the start can still fail. The room then stays confirmed and undug, the refusal is named,
and `order_underground_room` may order it again (RoomOrders removes no room before slice F).

**E2 — A busy crew is waited for, not refused.** A resident digs one room at a time. A batch's later rooms, or any
room whose named crew holds a Job, is reserved by another dispatcher or is seeking food or rest, stay QUEUED with
their crew and hold nothing: no foreman, no builder, no parking, no phase Project or Job, and no route actor.
`start_waiting` starts each on the first fixed tick its crew is free, in room-row order, so a load resumes the same
way. The same applies with no crew named: the first idle mole digs when one is idle. Only a crew that could never dig
is refused (`ROOM_DIG_CREW_SIZE`, `ROOM_DIG_CREW_NOT_A_DIGGER`, or `ROOM_DIG_NO_IDLE_MOLE` when no resident in the
village could dig at all).

  - Named members who later can no longer dig (they left, died, or picked up a tool) are dropped at the start. With
    none left, the first idle mole digs.
  - A start refused on the tick (no parking, or the foreman's plan) forgets the record and is alerted.
  - This replaces C2's `ROOM_DIG_NO_IDLE_MOLE` for a busy village. `test_underground_room_composer.gd` now waits, then
    starts the room.

**E3 — The tick order** (the coordinator's requirement, 2026-10-19):

1. the runtime's `advance`;
2. at its end, the retirement lane's `Retirement.retire_finished` (on its branch);
3. then `_release_done`;
4. then, back in the host, `UndergroundRoomComposer.start_waiting`.

Retirement therefore sees a stopped dig's stations before its record is released, and a crew that walked out on this
tick is free for the next room on the same tick.

**E4 — One Stop.** `stop_room` takes three cases:

- **A QUEUED room** is forgotten.
- **A dig under way** is halted through the foreman's own `_halt`. An unstarted phase is cancelled (nothing was paid).
  A started, paid phase is kept for a re-order to take over (P-1933-2 (a)). The crew walks out from rest, and the
  record is released once the crew is out.
- **A record a refusal had stopped** is released the same way.

A finished dig has nothing to stop. No refund falls due, because Stop cancels nothing that was paid: BUILD-REQ-019's
80% refund applies when a room is removed, which is slice F's. A player's stop raises no alert.

**E5 — Saving.** Each record row adds `_crew` (4 resident references, -1 pairs after the last member) and
`_release_out` (1 byte), declared category 1 and hash-free inside the record (C202; registry: 852 fields, 709 packed
source fields, `progress_record` bound 1,215,432). **The record's VERSION goes from 1 to 2. A version-1 record is
refused, `ROOM_SAVE_VERSION`.** This is the coordinator's call under DEC-055 item 1 (until 1.0, a save from another
revision is refused) and Brendan's precedent P-1972-3 ("Refuse them, recorded"); it is not a new ruling. The load
re-proves the record's cross-record invariants (decision 1937's review M3, below).

**E6 — Where the height and the way in come from.** The route takes the dug height from the caller: the panel prices
and plans with `modular_runtime.gd dug_height_u`, the one place DEC-054's height is read. It takes the approach and
the containers from the seam, which D2 fills from a finished connector. Nothing here invents a row, price or height.

## 2. Decision 1937's open review items, closed

| Item | Fix |
|---|---|
| M3: the load re-proved no cross-record invariant | `Runtime._records_agree`: every foreman names a kept record and no record has two; only a QUEUED record has no foreman; DIGGING runs, DONE is finished with its crew out, STOPPED failed; a named crew is well formed. `ROOM_SAVE_SHAPE` otherwise |
| M5: a parking whose spans never joined added two spans on every later order | `Parking._span_between`: spans already published between the two are never published again; the candidate is passed over |
| M7: `reserves_resident` scanned every kept foreman for each resident | A byte per Resident row (`_builder_rows`), rebuilt when a foreman is added (the count or the last foreman changes; every append changes the last). A resident no builder names is answered from it; one a builder names takes the full check, so the answer is exact |
| The actor-Job change (item 24) | Tested: a Stop on the hand-over tick asks for READY under the Job and row the actor holds, waits without a refusal, and walks out (`test_underground_room_confirm.gd`) |

## 3. A C2 defect found by C3 (item 24)

**Stopped on the tick a BRACE hands its working source over to CUT, a cube is left BRACED with the CUT cancelled
unpaid.** The same happens at the CUT to FINISH hand-over (the cube is left open and unfinished), whether the stop came
from the player or from a refusal. A re-order then always opened BRACE on that cube. Sites refused it
(`EXCAVATION_PHYSICAL_PHASE`), and the room never finished.

Decision 1938's resume covered only a *started* phase, which `_take_paid_phase` takes over; this case has no live
phase. The fix is in `underground_room_builder.gd`:

- `begin` and `continue_column` now open the phase the cube needs next, by Sites' own record (`_next_operation`):
  - BRACED or CUTTING gives CUT;
  - OPEN_UNFINISHED or FINISHING gives FINISH;
  - anything else gives BRACE.
- The coordinator cleared these two one-line changes and the helper on 2026-10-19.
- Tests: the stop at either hand-over, then a re-order that finishes the room with every BRACE paid exactly once; and
  the mapping for each phase in isolation.

## 3a. A second C2 defect found by C3: the room phases refused while anyone who is not crew lived

**Every room phase refused `ROOM_PHASE_WORKER` as soon as one living resident was not a Routes actor.** That
includes every mole still on the surface, so it covers the game always. `_ordinary_occupants_leaf`
(`underground_room_world_bindings.gd`) still required every living resident to be a route actor. ADR 1219 replaced
that requirement in the five other occupancy proofs, and its amendment added a sixth
(`Routes._assembly_occupants_leaf`): an unregistered resident occupies a reach cube of `UNREGISTERED_REACH_U` around
its Transform. The room bindings' leaf was never changed.

**Why the fixtures missed it.** Every resident in them was crew. A second mole was spawned only as a crew member,
which registers when it arrives.

**How it was found.** The unexplained C06 result reported earlier was one far-off claw mole, not named, making a
one-mole dig on the claw Kitchen refuse at 0 of 16 cubes. The review's two-mole crews failed for the same reason: a
member not yet arrived blocked the other.

**The fix.** The coordinator cleared it on 2026-10-19. The leaf now mirrors `_assembly_occupants_leaf`:

- A living resident with no Routes registration, other than the working actor itself, is tested with
  `Routes.unregistered_body_refusal` at the working actor's WORK location (`_ordinary_work_point`, the point
  `_ordinary_worker_leaf` proved its selection stands on).
- The test is charged ADR 1219's 16 checks for the row, on top of the leaf's 8.
- A registered resident keeps the exact body proof, unchanged.

**Tests** (`test_underground_room_occupants.gd`):

- a far bystander: the dig finishes, 16 of 16;
- a bystander that comes within reach while the builder works: `ROUTE_UNREGISTERED_RESIDENT_NEAR`;
- the leaf itself:
  - NEAR above the WORK location;
  - clear far off, charging exactly 8 × 512 + 16;
  - `ROOM_PHASE_OPERATION_CAPACITY` one check short;
- a registered resident who is not crew: the exact proof runs, more than the reach charge;
- a two-mole crew digging while its second member is still on the surface;
- a named crew of four.

Decision 1152's test that pinned the old whole-host contract (a remote unregistered resident refuses) now pins this
rule: never placed refuses, far off is clear, within reach is NEAR, removed passes. Decision 1152 has a note.

The real-route fixture (`test_underground_room_confirm.gd`'s TwoRooms) now always has one mole who is not crew. Five
mutants on the new branch were all killed: no branch, a zero point, a point 20,000 u low, no charge, and registered
rows sent to the reach test. The SHA trace is unchanged (the benches have only crew residents).

## 3b. The review's findings, fixed

An independent `code-reviewer` read `8a7d045d..2079f7d4` and returned 1 CRITICAL, 3 HIGH and 7 MEDIUM findings.

**C-1, cost of waiting rooms.** Before the fix, `start_waiting` scanned all 512 resident slots for each waiting room
with no live named crew, every fixed tick, and allocated an `IntResult` and a `StringName` per adult. The reviewer
measured 954 µs per tick for 1 waiting room, 9.2 ms for 10 and 45.8 ms for 50, with 255 hungry moles in a debug
build. Now:

- One `Idle` scan serves every waiting room on a tick: slots are handed out in order and each is checked again when
  handed out.
- The species is compared by its raw id, read once per tick (`_could_dig_as`).
- `queued_into` returns at once, through a native `count`, while nothing waits.
- On the tick, the scan covers one eighth of the slots (`IDLE_WINDOWS` = 8, a window keyed by the tick index, which
  is saved). A room waiting for "the first idle mole" can therefore start up to seven ticks later than a full scan
  would. This is a choice of cost, not a rule. A player order still scans every slot.

Measured on the same probe: 78 µs for 1 waiting room, 94 µs for 10 and 173 µs for 50.

**H-1, crews of more than one never finished.** There were two causes, both in parking:

- The second builder parked in the corridor between the access and the room, on the first builder's way.
- It parked on the storage container's endpoint (the claw fixture's "access" endpoints are STORAGE). A body there
  blocks every fetch: `ROOM_FOREMAN_CREW_BLOCKED` at 11 or 14 of 16 cubes.

`underground_room_parking.gd` now:

- never parks between the access and the room (`_between`);
- never reuses an endpoint some span joins to anything but the access (`_routed_elsewhere`: a route's TRANSIT node);
- never parks on the order's containers (`keep_clear`, read from the runtime's `containers_into` and Inventory's
  `spatial_location_of`);
- failing the access's floor, takes an endpoint already authored as a parking (`_authored_parking`), publishing
  nothing.

A member beyond the parkings the access has room for is left out of that dig and stays free. The first member must
park. On the claw Kitchen, a named crew of four digs with two parked moles to 16 of 16, and the other two stay free.

**H-2.** A crew reference is checked with its kind (`is_valid_of_kind(…, KIND_RESIDENT)`, ARCH-ID-003).

**H-3.** D2's way in belongs to the mounted session:

- it is reset to the base `WayIn` at mount and at release;
- binding it is refused while resetting or with nothing mounted;
- a test covers bind, reset, remount, then refused.

**M-1.** Pinning a way, or arming a card, puts the room card away.

**M-2.** Stop during a paint stroke cancels the stroke first, so the cells always go back into the plan.

**M-3.** More of what `order` refuses is now read before admission: a full record pool, and a retreat row out of range
before the first bind. `order_painted_room` returns the whole `Result`. Still possible after admission: the
provider's own first bind, a parking, and a reused row whose old crew is still out. In each case the room stays
confirmed and undug, and may be ordered again.

**M-4, recorded as a D2 obligation.** RoomOrders' admission (`confirm_room`) checks only connectivity and topology:
neither BUILD-REQ-002's 2 × 2 block nor the type minimum, and it never joins a leftover to the room it came from. The
demo's E9 judges cells put back against the room's dug part, but in the real route a stopped room stays confirmed
and is re-ordered whole. When D2 switches the panel to the real route, the panel's put-back cells must be either:

- re-ordered as the same room (the real Stop), or
- refused by the same rules core enforces.

**M-5 and M-6.** The surviving mutants now have tests:

- access read before admission;
- `_span_between`, on the path itself;
- the stop that releases at once;
- the busy named member;
- filter freshness.

Vacuous assertions were made strict:

- the release flag at capture;
- the save at QUEUED;
- the crew's words after a Stop;
- the host test's alert claim, removed.

The live harness's header now says the staged village sends its one mole.

**M-7, recorded and not changed.** QUEUED rooms reserve nothing, and the host selects Jobs before rooms start, so a
named mole freed and immediately given another Job could keep its room waiting. A soft reservation for a waiting
room's named crew would also hold the mole idle. That is a player-facing choice for slice H's "who is assigned"
work.

**LOW items:**

- The load refuses a release flag on a record nobody stopped.
- A demo mole digging a cell that another mole now holds lets it go.

The rest are recorded here as known:

- A malformed crew is named `ROOM_DIG_CREW_BUSY` by the runtime (the composer refuses it first as `CREW_SIZE`).
- A QUEUED record of a deleted room is replaced when its row is reused.
- A partial parking failure leaves an unjoined endpoint, which is reused and never re-spanned.
- The demo crew number wraps after 255 live batches.
- The card reads "Stopped" for a never-stopped room with a pending same-type extension beside it.
- `order` may start a new room ahead of an older one waiting for the same mole.

## 4. The demo (P-1990-1 (b), P-1990-4 (a), P-1990-5 (a))

| Piece | Files |
|---|---|
| Each ordered cell carries its Confirm all's crew number; a crew digs only its cells; each cell claimed by one mole | `demo_build_works.gd` (`crew_of`, `waiting_for`, `claim`, `next_dig`'s crews) |
| The crews of the Confirm alls | `demo_build_crews.gd` (new) |
| Up to four moles digging side by side; the footer names the crew; the room card; Stop digging | `demo_build.gd`, `demo_build_below_task.gd` |
| UI-BUILD-015 Room card, UI-BUILD-016 Stop digging | `scripts/ui/build_room_card.gd` (new), `build_panel.gd`, `build_layout.gd`, `ui_registry.gd`, `docs/ui_ux_controls.md` |
| A stopped room's cells back in the plan as one step | `build_batch.gd` `return_cells` |

**E7 — Moles only.** The crew is the selected moles in selection order, four at most ("four at most dig a room"
beyond that), as the real route's `could_dig` has it. With no mole in the village (the art-free placeholders, as in
CI), any selected resident digs (decision 1912 P-1912-3).

**E8 — The footer names the crew by first name.** "Crew: Tuppen, Bramble" is on the ledger's second line, after the
work when both fit the button's width; otherwise it replaces the work, which stays in the tooltip, the accessible name
and the expanded ledger. The ledger is 44 px high, so it holds two lines.

**E9 — Cells put back in the plan are judged with the room's dug part.** BUILD-REQ-002 asks that every cell lie in "a
2 × 2 block of its room", and SET-BUILD-001 §4's minimum is the room's. So `build_cell_validity.gd` counts the room's
own confirmed cells (the host's room-type reader) toward a pending cell's block, and `build_batch.gd` counts the room's
joined confirmed cells toward its minimum. Without this, nearly every Stop left an "X Too narrow" or "! Too small" part
holding Confirm all back.

The rule is general for pending rooms: a pending room's cells beside a confirmed room of its own type are judged with
it, as OPEN-06's merging of same-type rooms implies; beside another type, nothing changes. A stroke's own shape is
still judged on its own (`all_in_blocks`), so a one-cell-wide stroke is refused as before.

**E10 — The room card stands where the connector card does, 184 px high** (280 × 128 in NARROW, its words then
scroll), so its three lines show whole: how far it is dug and the crew, then the proof of concept's note.

## 5. Memory (ADR 1212 census; DEC-053 gate 150,000,000 B)

`room_dig_runtime` goes from 5,349,494 to **5,383,814 B (+34,320)**:

- the record pool's 33 more bytes a slot (+16,896);
- the reserved-resident filter and its two scalars (+528);
- the record image's wider bound (+16,896).

The declaration adds +106 B (four fields, 46 key bytes). **Live goes from 105,798,684 to 105,833,110 B (+34,426).
Headroom goes from 44,201,316 to 44,166,890 B.** With decision 1880's held budget, the fold-in figures are
122,790,550 and 27,209,450. C+G's projection leaves 3,944,170 B for slice G.

The census, the pack, `ready07_arithmetic.py`, ARCH-MEM-009's trail and the registry rows move together. The demo's
crews and claims are presentation-side, unsaved and outside the census.

## 6. Engineering choices also recorded

- **E11 — The demo's earth draws one cell deepening at a time:** the first crew member's. The others' cells open
  when their wait ends. The drawing has one progress slot, and a second one is presentation work for D2's real view.
- **E12 — Two rooms in the claw Kitchen fixture.** The northern room is admitted through an approach from a corridor
  endpoint level with its station, while its dig keeps the one access the contacts are bound to. That is why its
  admission request's `access` differs from its order's.
- **E13 — The two-room stop case stops after the first cube.** Stopped after five, on master the second room ends
  `ROOM_STATION_GEOMETRY_CLOSED` at eight cubes. The station-chain retirement lane (decisions 1942/1943) traced it to
  the station planner treating other rooms' reservation markers as nonphysical while Locations' Site survey does not:
  once room A has a dug void, B's WORK box spills 7 u into A's cell and publication is refused. That lane fixes it and
  proved stops after 5-15 cubes on a copy of this work. Whichever of the two lanes merges second raises this test's
  stop point to five cubes as a cross-check. C3 does not touch the station planner.

## Gates (final, at `14fd5103`; origin/master `8a7d045d` had not moved)

- **Full CI-style run:** fresh import (exit 0) in a clean worktree, art-free, `./tools/run_tests_parallel.sh`, 10
  shards:
  - every shard and the verify passed: 551 suite files, each run exactly once;
  - 13,060 tests and 1,475,436 assertions, 0 failures;
  - 0 unexpected errors and 0 unexpected warnings (289 expected, 456 tolerated);
  - 0 leaked objects and 0 leaked resources.
- **The run before it found two pins.** The earlier run, at `d57fc567`, failed one suite: decision 1152's pin of the
  old whole-host contract (§3a), since updated. The run before that, at `f28e805a`, failed the registry pins for
  record version 2 and the demo input harness's Opened words, both since updated.
- **Analyzer:** `tools/gdscript_warnings.py --max 0`: 0 warnings in 1,634 files.
- **Contracts:** 30 of 30 pass, including:
  - `decision_numbers.py`;
  - `ready07_arithmetic.py`;
  - the memory budget, census and registry checks;
  - `generate_canonical_state_table.py --check`.
- **SHA trace** (`tools/benchmark_dig_tick.gd`): byte-identical to master on both benches (room `007e8e18…`, entry
  `189417c8…`).
- **Checkpoints:** regenerated. The saves are byte-identical; only the source fingerprints moved.
- **Memory:** this lane adds +34,426 B (runtime +34,320, declarations +106). Headroom goes from 44,201,316 to
  44,166,890 B, and 3,944,170 B are left for slice G. The review fixes add 0 B: three reviewed allocation sites, one
  way-in live at a time.
- **Live harness** `demo_build_crew_live.gd`:
  - 40 of 40 at 1280×720 and at 1920×1080, windowed with frames captured, and 40 of 40 headless;
  - the dig loop harness and the input harness pass inside the full run.
- **Independent review:** one `code-reviewer` pass. All of CRITICAL, HIGH and MEDIUM were fixed, or recorded as D2's
  or slice H's (§3b).
- **Mutation:** 97 of my own mutants (core 40 + 19, occupancy 5, demo 33).
  - All killed except four that are equivalent:
    - R15: the reserved-resident byte filter is only a shortcut before the exact check;
    - C10: no-Sites refused before or after the contacts, with the same outcome and nothing kept;
    - N19: the way-in reset at mount is redundant with the reset at release and the gated bind;
    - D10: every crew number that has waiting cells is held.
  - The reviewer's M6 survives: a DONE record whose foreman's crew is not out. It needs a forged foreman image, and
    no tick produces one.

## Source

Decisions 1880, 1912, 1933, 1936-1941, 1990; DEC-055, DEC-059, DEC-061; SET-BUILD-001 BUILD-REQ-002, -012, -013,
-019; `docs/ui_ux_controls.md` UI-BUILD-001-016.
