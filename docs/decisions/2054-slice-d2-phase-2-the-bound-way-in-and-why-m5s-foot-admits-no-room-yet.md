# 2054 — Slice D2 phase 2: the bound way in, and why M5's foot admits no room yet (stopped for rulings)

Date: 2026-10-21 · Status: Built in part, then **stopped**: the brief's "stop and report" applies to four findings, two
of them in M5's held files. Branch `feat/slice-d2-phase2`, cut from M5's pushed head `ea9c7ed6`
(`feat/slice-d-m5-full`) with origin/master `e0e7065a` merged (D2 phase 1, #281; the pacing record, #280). Number
range 2054–2060 (2051 and 2061 are other branches').

## Decision

Phase 2 of decision 2052 (§6), with decision 2053 §3's inheritance and P-2091-7 (a) (Brendan, 2026-10-21, relayed by
the coordinator: "D2 phase 2 adds the level-1 store's grip stand and the CARRY span from F′ to it"). What is built:

| Piece | Where | Rule |
|---|---|---|
| The finished flight's Foot, derived from the entry record (`step`, `origin`, `crew`) and the live Locations; the panel's landing and shape readers | `scripts/core/underground_way_foot.gd` (new) | 2052 §2.1, §2.3, E1 |
| The foot made ready in the run-out's floor air: a hub joined to F′(5), a parking, the level-1 store and pile, the store's grip stand and a CARRY span into it | `scripts/core/underground_way_in_foot_prep.gd` (new) | P-2052-1/-2 (a), 2052 §2.2 rows 4, 8, 9, 12; P-2091-7 (a) |
| `StairWayIn`: kept fronts, retired once a room's record is released, recalled from the rooms' Sites after a load; `order_into` (Resume); the foot made ready only once a front is found | `scripts/core/underground_way_in.gd` | 2053 §3; 1991 M-4; P-2052-5 (a) |
| Fronts: the heading's own retreat row; the corner must hold the ground row's turn; a reused station or corner joined to anything else is refused | `scripts/core/underground_way_in_front.gd` | 2053 §3 (review M3) |
| Host: bind on the finishing tick (with P-2052-11's notice) and after `restore_underground_entry`; `settle` after every confirm and Resume; retire fronts each tick; check a loaded record's contacts against the way in's access (`ROOM_DIG_OTHER_ACCESS`); `resume_underground_room`; `underground_way_landings` / `underground_way_shapes`; a busy session named | `scripts/systems/settlement_system.gd` | 2052 §2.1, §2.3, §2.5 |

The way in is never saved: binding derives, publishes nothing, and a load recalls without publishing (2052 E1). The
memory census counts 0 B (one way in live at a time; its kept-front list is native overhead): a reviewed allocation-site
row for the host, live 106,178,061 B, headroom 43,821,939 B, unchanged.

## 1. The probe (the foot facts, on the live chain)

Run in a scratch suite (`scratchpad/d2p2_probe_suite.gd.txt`, not committed): the committed `underground_flight` point
`tick_075000` loaded, flown on to its finish, cache checks off. Eight runs; each finished on tick **92,559**,
byte-identical to the committed finish point, and the host bound the way in on that tick (2052 §2.1).

| Fact | Finding |
|---|---|
| F3: the foot is level 1's floor | **Holds.** F′(5) is at y 512 − 5,120 = −4,608 (level 1's floor), on the slot's centre line, 850 u from the run-out's end wall (`RUN_OUT` − `FLOOR_WALK_OFF`) |
| F′(5)'s envelope (2052 finding 2) | **One body.** x −485..479, z −521..412, 930 high around F′: exactly row 43's body box (the claw endpoint certificate's air). Its only edges are the walk-off F → F′ and the back-up F′ → F: **no ground join** |
| Heading | The foot faces **down the flight (−Z, yaw 0)**: only rows 43/47 (and 45/49 facing up) fit F′'s air. The all-yaw ground row 42 (±712) cannot turn on F′: its turn sweep meets the last sill (26 u) |
| Loaded rows at F′ | **None fits.** A CARRY (and a WALK) span from F′ across the flight refuses `WORLD_ROUTE_NO_FITTING_PROFILE`; so does a CARRY span F′ → hub down the flight. Carry rows 32/37 are ±679/±556 wide; the loaded stair rows reach 779–1,052 u ahead |
| Parking | The planner's candidates (2–3 cells off the access) all leave the 2-cell slot; D2 publishes one parking (2052 row 8), which the planner's authored-parking fallback takes |
| The foot made ready | **Works live:** hub (TRANSIT, the run-out's air) joined to F′ both ways; parking joined to the hub on the retreat family (45/49); store and pile (ground staging); the grip stand (WORK at `Grip.stock_offset(QUARTER)` from the store) with a **CARRY span from the hub certified** by WorldRoutes. 190–310 ms for the whole foot |
| A painted end-wall room | **Refused, and cannot be admitted at this foot today**: see B1 and B4 |

## 2. Why no level-1 room can be dug yet (stop findings)

**B1 — After M5 finishes, the Session never becomes quiescent (M5's held files).** `Session.current_refusal()` stays
`WORLD_RETIREMENT_BUSY` after the crew has walked out (242 ticks after the finish and on): the entry bindings keep
`_timber_token` (156), set by `_workpiece_refusal` for the last workpiece operation and never discarded
(`underground_entry_bindings.gd` `_workpiece_refusal` / `_discard_timber`). With that cleared by hand (scratch only),
Contacts still holds `_valid = true` (`CONNECTOR_CONTACT_SCOPE`, `underground_connector_contacts.gd`
`retirement_refusal_in`). So `Session.room_orders()` lends nothing and every painted room is refused; before this phase
the host's `order_painted_room` crashed on that null (fixed here: the session's own code is named,
`_room_orders_refusal`, tested). Both files are M5's; nothing here edits them.

**B2 — Level-1 saves do not load at `ea9c7ed6` (P-2045-14).** The finish point refuses `SPACE_OPERATION_BUDGET`
(section 1, the Space owner's overlap validation). M5's fix is on its local, unpushed `faae397d`. Until it lands, the
`underground_level1` checkpoint recipe, the S7 restore-rebind fixture and a committed live-dig suite cannot start from a
level-1 point (the probe flew 17,559 ticks, about 7 minutes, instead). Not built.

**B3 — F′(5)'s air holds no loaded row (M5's stop geometry).** P-2091-7 (a) asked for the CARRY span *from F′*. It
cannot be certified while F′'s air is one empty-gait body (§1). Built instead: the span **from the hub** (joined to F′,
82 u down the flight), which WorldRoutes certifies. A loaded runner still cannot get from F′ to the hub; stair-leg
Delivery needs F′'s air widened by M5 (with the loaded rows' landing clearance its own phase 1 owes, 2091 F8).

**B4 — No front station in M5's run-out both strikes one cube and can be turned into (geometry).** Proved by
`test_no_front_station_at_m5s_foot_both_strikes_one_cube_and_is_turned_into` and confirmed live:

- A front station strikes one cube only (`underground_work_face.gd` `stroke_refusal`) when its stroke, 893 u across
  (wall row 67: x −478..415), lies in that cube: the station stands 478–609 u into the cell across its heading.
- It is reached on its heading's exact rows only from a corner on its own line where the all-yaw ground row turns. In
  the run-out (2 cells, 2,048 u wide; 1,536 u long) the ±712 turn sweep fits only 312 u either side of the centre line
  and 712–824 u from the end wall.
- Those ranges never meet: not for the end wall (stations at 415–546 u off the centre line), nor either side wall
  (stations 415–546 u or 1,439–1,570 u from the end wall).
- Live: a station placed nearer the centre line was refused `WORK_FACE_STROKE` by RoomOrders' witness (it struck the
  neighbouring cell); with the station on its cell's centre line, as now built, the way in refuses `WAY_IN_NO_FRONT`.

So whatever D2 publishes, today's M5 foot cannot admit a painted room with today's qualified claw rows. The same holds
for any 2-cell slot. D2 refuses it, named, and changes nothing.

## 3. PROPOSALS (for the coordinator and Brendan)

**P-2054-1 — The finished entry's leftover scopes (B1).**
- **(a) M5 closes them when the entry finishes:** the workpiece-set timber scope is discarded when its operation ends,
  and Contacts drops `_valid` after its last phase. Exact, in M5's own files, with a test that the Session is quiescent
  once the crew has left.
- (b) The Session's quiescence check excuses a finished entry's settled scopes. Wider: it weakens the retirement guard
  for every caller.
- (c) D2 clears them from the host. Rejected: it edits M5's state from outside its files.

**Recommendation: (a).**

**P-2054-2 — F′(5)'s air (B3).**
- **(a) M5 widens F′(5)'s published air** to the run-out ahead of it and the space above the sill deck (extra air
  boxes, ADR 1215), proved against the sill like P-2044-16, so the loaded rows and the carry rows can stand and leave
  there. Stair-leg Delivery then joins F′ → hub loaded, and the stand's span from the hub stays.
- (b) Stair-leg Delivery ends its loaded legs on a new loaded landing stop of its own. More motion proof, same file.

**Recommendation: (a)**, decided with stair-leg Delivery (decision 2091).

**P-2054-3 — A foot that can admit a room (B4).**
- **(a) M5's last landing gets a wider foot:** the bottom run-out cut one cell wider on each side (4 cells, 4,096 u), so
  a turn spot lies on a station line (a station 478–609 u into the outer cells, its corner ±712 clear inside 2,048 u).
  More cubes at the foot and a change to M5's geometry and bundle; no new motion; every proof stays as it is.
- (b) Qualified narrow-turn or side-step claw rows (new motion authoring), so a station off the turn spot is reached
  in the 2-cell slot.
- (c) Rooms on level 1 wait for a later connector (or a dug foot chamber) that is not a 2-cell slot.

**Recommendation: (a)**, scoped by the M5 / D-flight lane, because it needs no new motion and keeps the qualified rows.

## 4. Engineering choices (recorded, not asked)

- **E1 — A hub, not F′, is the rooms' access.** F′'s air is one body and nothing turns on it, so the parking planner
  (Slice C's, which proves bodies in the access's air) and every front would refuse at F′. The hub (82 u down the flight
  from F′, where the all-yaw row turns) carries the run-out's floor air (2 cells × `RUN_OUT`, one cube high) and is
  joined to F′ both ways. Every order's access is the hub, so `ROOM_DIG_OTHER_ACCESS` still never fires on one foot.
- **E2 — The 2054 layout,** in u from the end wall on the centre line: hub (0, 768), parking (0, 948), store (−832, 714),
  stand (−256, 714), pile (600, 1,088). Each is held by a clearance test against the walls and the sill; the margins
  are tight (64 u off and the stand meets a wall; one unit off and the turn spot is gone).
- **E3 — The retreat row the contacts bind is 49** (yaw 32768): the parking must lie up the flight from the hub, out of
  the way of a room at the end wall (`_between`), and 45/49 reach it there.
- **E4 — The CARRY span bends once:** down the flight to the stand's line, then −X, so it enters the stand on the grip
  heading (as the work area's `_carry_approach` does).
- **E5 — Fronts are found before anything is published,** from the hub's record as it will be published, so a refused
  order makes nothing at the foot.
- **E6 — Kept fronts,** one per admitted room, are retired once the room's record is released (dug, or stopped with its
  crew out); a front another kept front shares keeps its endpoints, and the access is never retired. After a load they
  are recalled from the rooms' Sites by the same geometry, publishing nothing. Resume (`order_into`) finds the room's
  front again, publishing it again if it was retired.
- **E7 — The station stands on its cell's centre line only.** A fallback nearer the access line was built and then
  removed: it strikes the neighbouring cube (B4).
- **E8 — Settle on every confirm,** admitted or not, so a front published before RoomOrders refused is withdrawn (2053
  review H2).

## Not done (with reasons)

- **The `underground_level1` checkpoint recipe and the S7 restore-rebind fixture:** B1 (no room can be admitted), B2 (no
  level-1 point loads) and B4.
- **A level-1 room dug end to end, and its frames at 1280×720 and 1920×1080:** B1 and B4. The probe dug nothing.
- **M-4's panel half** (erasing a stopped real room refused; put-back cells judged by core) waits for the demo
  switchover (phase 3), as decision 2052 §2.6 has it; the core half (Resume) is built and tested on the claw Kitchen.

## Source

Decisions 1936, 1937, 1941, 1942, 1990, 1991, 2041–2045, 2052, 2053, 2081, 2091 (P-2091-7 (a), Brendan 2026-10-21,
relayed); SET-BUILD-001 §3, §9; ADR 1209 D2, ADR 1213, ADR 1215, ADR 1219; the code at `ea9c7ed6` + `e0e7065a`.
