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

## Gates

Recorded at the end of the lane: see "Gates (final)" below.

## Source

Decisions 1880, 1912, 1933, 1936-1941, 1990; DEC-055, DEC-059, DEC-061; SET-BUILD-001 BUILD-REQ-002, -012, -013,
-019; `docs/ui_ux_controls.md` UI-BUILD-001-016.
