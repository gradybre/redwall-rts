# 1990 — Slice C3 scoping: every open Slice C item, and what C3 can build before M5

Date: 2026-10-19 · Status: Accepted in part. Brendan's "Keep waiting for M5" (2026-10-19) is recorded below. P-1990-1
to P-1990-5 await his word; nothing is built under this record until they are ruled.

Number range: 1990–1999 (the coordinator's, for C3); checked free on every local and remote ref and with
`decision_numbers.py`. This is the scoping record; later records of the lane take 1991 onwards. Branch
`feat/slice-c3-confirm`, from origin/master `8a7d045d`.

## Decision

C3 was scoped (decisions 1911 §3, 1931, 1936) as "Confirm all digs painted rooms": Confirm creates the real dig through
`RoomOrders.confirm_room`, the dispatcher and the room foreman; the economy pays; the player picks the crew; a dig can be
released; decision 1880's 17 MB is folded in. **The code at `8a7d045d` shows that the central part, a painted room
really dug, cannot run anywhere before slice D's M5 flight and D2**, because nothing reaches a level floor (§1).
Brendan has now ruled to keep waiting for M5 and to close Slice C when C3 and the station-chain retirement lane merge.
So this record:

1. lists every open Slice C item with evidence and classifies it (§2);
2. names what C3 can build now and prove on fixtures and in the demo (§3);
3. asks Brendan five questions (P-1990-1 to -5), chiefly what the demo's digging is until D2 (P-1990-1).

## Brendan's ruling (2026-10-19)

Relayed by the coordinator, 2026-10-19: **"Keep waiting for M5".** Slice C closes once C3 and the station-chain
retirement lane (`feat/room-station-retirement`, decisions 1942–1949) merge. The stair-leg Delivery (decision 1941,
P-1941-1 "Wait for M5") and phase-spreading stage 2 (decision 1953, P-1953-2 "After M5, re-measure") become follow-ups
right after M5 lands, not Slice C close-out blockers. Both are classified (iii) below.

## 1. Why no painted room can be dug for real before M5 and D2

Paths under `godot/` at `8a7d045d`.

- **No level floor is reachable.** Room digs are admitted only at a roofed level's authored floor; level 1's floors are
  −5,632, −4,608 and −3,584 u, and the only qualified stair ends at the sill, local y −896 (decision 1941 §1; decision
  1972 "What the stair carry supplies"; the slice D finding in LIVE_WORK 2026-10-16: `ROOM_AUTHORED_LEVEL_REQUIRED`).
  The flight to level 1 is slice D's M5 (decision 2043 P-2043-1 (a)), in progress on `feat/slice-d-m5-flight`.
- **Nothing binds a way in to the room runtime.** `UndergroundRoomComposer.order` needs an access endpoint, a retreat
  travel row and three containers (`scripts/core/underground_room_composer.gd:26-33, 46-60`). Nothing in the game makes
  them: binding a finished connector to the room-dig runtime is **D2** (decision 2021 "Decision"; LIVE_WORK_SLICE_D
  §1, range 2051–2069, not started). `SettlementSystem.order_underground_room` says so itself: "C3's order route calls
  this; nothing in the game does yet" (`scripts/systems/settlement_system.gd:2046-2048`).
- **The demo never binds the room runtime's owners.** It mounts and composes room and route owners only
  (`demo/demo_village.gd:592-605`); the runtime's owners are bound in `compose_underground_entry_owners`
  (`settlement_system.gd:2028-2043`), which no `demo/` or `scripts/` code calls outside a save restore. So in the demo
  `order_underground_room` is refused `ROOM_DIG_SCOPE` (`underground_room_composer.gd:46-48`).
- **Materials cannot reach a level below the surface.** Delivery serves the same level only; `ROOM_HAUL_NO_STAIR_CARRY`
  stays raised for every live level until the stair-leg Delivery is built on M5 (`underground_room_builder.gd:76`;
  decision 1941). And settlement stock is never moved to an underground staging container
  (`ENTRY_HAUL_NO_STAGED_STOCK`, `scripts/core/underground_entry_hauler.gd:29`, `underground_entry_runtime.gd:65`; ADR
  1210; HAUL-H3+, decision 1911 §2.2).
- **The game has no build panel.** The settlement's Build button stays disabled until slice G (decision 1871, RULINGS
  "Slice B, the build panel shell"; decision 2021 F4). In the game, C3 can only give the order route; the panel is the
  demo's.
- **The demo has no save or load for the player.** Saves exist only through the settlement save path the suites drive
  (`scripts/core/settlement_save_apply.gd`); no `demo/` code saves. "Saves and loads work" can therefore be proved only
  through that path, as decisions 1937 §4 and 1938 did.

So today's demo digging is still decision 1912's proof of concept: Confirm all hands the batch to
`demo_build_works.gd`, a mole digs, nothing is paid or saved (`demo/build_panel/demo_build.gd:33-34, 722-741`).
`demo_build_orders.gd submit` (the real route through `modular_runtime.gd` and `RoomOrders.confirm_room`) is kept but
not reached from the panel (its header, `demo/build_panel/demo_build_orders.gd:16-19`).

**Cost at Confirm.** The brief says "real costs paid at Confirm". Brendan ruled the opposite on 2026-10-11 (DEC-061,
"don't deduct at confirm, keep as we currently do"), written as BUILD-REQ-019: nothing is deducted at Confirm all;
materials are consumed when work starts; a cancel refunds 100% before work and 80% after
(`docs/building_model_amendment.md:48`; decision 1911 item 20). C3 follows BUILD-REQ-019: Confirm creates the priced
order, and each phase pays when it starts. This is not put to Brendan again; P-1990-2 asks only what the demo shows
until the real route can pay.

## 2. Every open Slice C item

Sources searched: decisions 1880, 1911–1914, 1921, 1931–1941, 1951–1953, 1971, 1972, 1981, 2001, 2002, 2021, 2022;
`docs/handoff/RULINGS.md`; `docs/handoff/LIVE_WORK.md` and `LIVE_WORK_SLICE_D.md`; `docs/handoff/BACKLOG.md`;
`docs/tasks/` (`underground-build-queue.json`, `underground-modular-build.md`); the building study §5 C and H; and the
code. Classes: **(i)** C3 builds it now; **(ii)** a parallel lane owns it; **(iii)** blocked on slice D's M5 flight or
D2; **(iv)** not Slice C.

| # | Item | Evidence | Class |
|---|---|---|---|
| 1 | Confirm all creates the real dig: painted cells → `RoomOrders.confirm_room` → composer → foreman | 1911 §1 item 15, §3 row C3; 1936:105; 1937:35-37; `settlement_system.gd:2046` | **(i) the route, proved on fixtures; (iii) live in the demo and game** (§1). P-1990-1 |
| 2 | The demo's digging stays a free, unsaved proof of concept until C3 | 1912:41-51, P-1912-4; `demo_build.gd:33-34` | P-1990-1 |
| 3 | The real economy pays (BUILD-REQ-019, DEC-059 per phase); UG24's "never show unpaid work as done" holds again | 1912:43, 50-51; SET-BUILD-001 BUILD-REQ-019 | **(i)** in the real route (phases already pay through Sites: 1933, 1935, 1938); **(iii)** live, since Delivery cannot reach a level (item 12). P-1990-2 for the demo |
| 4 | The player chooses the crew; up to 4 builders a room | P-1936-2 "(c) the player chooses when C3 lands" (1936:185-188, 229; RULINGS:206); P-C9 (a) up to 4 (1911:39); BUILD-REQ-012 | **(i)**. P-1990-4 for the interaction |
| 5 | Releasing a dig: a STOPPED record waits for `release_room`; 512 STOPPED records refuse orders; no player can stop or release | `underground_room_runtime.gd:293-305` (no caller: grep); 1937:61-63, 148, 172-173 | **(i)**. P-1990-5 for what Stop means |
| 6 | Decision 1880's 16,957,440 B folded when the painted columns are first allocated | 1880 Q2 (RULINGS:165); P-C8 (a) (1911:38); 1936:166 | P-1990-3 |
| 7 | 1880's projects and containers (Q1, 23,265,280 B) and "one project per room" | 1880 "Projects and containers"; P-C2-4 (a) one packed record per room plus per-phase projects (RULINGS line for 1931) | Covered by C2's record (1937 §5) for room digs; the Q1 bytes go with P-1990-3 |
| 8 | Retire the superseded tile-based room rows (1,802,240 B) | 1880 "Added, not replacing" | Goes with P-1990-3 (only when the painted store exists) |
| 9 | Registry, capacity audit and canonical-table reruns for each allocated column | 1880 "Deferred" | Goes with P-1990-3 |
| 10 | Underground spoil piles' owner and bound | 1880 "Deferred" (C; decision 1075; ECON-003); 1911 item 18 | **(iii)**: a real order's spoil container is one of the three containers D2's binding supplies (`Order.output`) |
| 11 | Settlement stock staged underground for a room dig | `underground_entry_hauler.gd:29`; 1911 §2.2-2.3 | **(iv)** HAUL-H3+ (BACKLOG); it blocks the live dig with item 12 |
| 12 | Stair-leg Delivery: an upstairs container supplies a dig below | 1941; P-1941-1 "Wait for M5" (RULINGS:235) | **(iii)** post-M5 follow-up (Brendan, 2026-10-19) |
| 13 | Phase spreading stage 2; REQ-SET-163's 2 ms tick | 1953 P-1953-2 "After M5, re-measure" (RULINGS:237) | **(iii)** post-M5 follow-up (Brendan, 2026-10-19) |
| 14 | Per-tick worker verdict tokens (P-1952-1 "Later, if needed") | 1952; RULINGS 2026-10-16 | **(iii)**: re-measured with item 13 |
| 15 | Station-chain retirement (past about 94 route edges) | 1934 §2; P-C22-2 (a); 1933:139-141 | **(ii)** `feat/room-station-retirement` |
| 16 | A room on a second access: `ROOM_DIG_OTHER_ACCESS` until a per-access binding exists | P-1936-1 (a); `underground_room_composer.gd:66-79` | **(iii)** D2 (more than one way in needs more than one bound connector) |
| 17 | The game checkpoint of a room dig (P-1936-4: "the game checkpoint with slice D") | RULINGS:206; 1936 | **(iii)** D2 |
| 18 | The host's restore without its contact rebind (mutant S7) | 1937 §8: "no host fixture has a way in until slice D" | **(iii)** D2 |
| 19 | Review M3: load range-checks only some cursor fields; cross-record invariants not re-proved | 1937:177-178 | **(i)** engineering |
| 20 | Review M5: a parking whose spans publish but never join adds two spans on every later order | 1937:179 | **(i)** engineering |
| 21 | Review M7: `reserves_resident` scans every kept foreman for each resident Jobs evaluates | 1937:180 | **(i)** engineering (crew choice reads it per candidate) |
| 22 | 1937 LOWs: walk-out codes alert every tick; the haul queue's bound is implicit; stale comments | 1937:181-182 | **(i)** engineering, where C3 touches the file |
| 23 | Deferred mutants B13/B14 (512-box and plan-list caps at set-off) and S3 (record near `MAX_WIRE_BYTES`) | 1937 §8 | **(i)**: a synthetic plan at the cap is a unit fixture, no level needed |
| 24 | The actor-Job change (READY requested under the actor's Job) needs a stop between a hand-over and READY | 1937:175-176 | **(i)** if P-1990-5 gives a player stop (it makes that stop reachable); else stays deferred |
| 25 | "C3's real view": merged floor quads, fixed-size tags at 1280×720, the actors' own rigs underground instead of the capsule figure | 1913:91, 133-135 | **(iii)**: the real view draws the real dig, live only after D2. Under P-1990-1 (b) the proof of concept's view stays |
| 26 | `modular_room_mode.gd`'s access binding "C3 may reuse" | 1912 E15 | **(iii)** D2's binding |
| 27 | Retire D1's free proof-of-concept digging of ways down | 2021:263 ("C3 follows D2") | **(iii)** D2 |
| 28 | `docs/underground-integration-status.md` and the queue's UG24 ("Actual demo owner, confirmation and fixed-tick composition") and UG09 ("First playable blueprint to empty Kitchen"), both `queued` | `docs/tasks/underground-build-queue.json:3616-3618, 4408-4410` | **(i)** status updates for what C3 lands; UG09 stays open until D2 |
| 29 | Furnish fitting is free (decision 1921) | 1921:39-46 ("slice E replaces all of it") | **(iv)** slice E |
| 30 | Mound homes in the game (MOUND-REAL); built Surface rooms | BACKLOG MOUND-REAL; P-2002-1 | **(iv)** MOUND-TERRAIN, C3, D, E, G |
| 31 | The stair carry's floor end (stops F, U, F′) | 1972 Phase 3a option (d); 2044 | **(iii)** slice D (M5) |
| 32 | 1911 item 21: authoritative breadth-first scratch over up to 65,536 cells a level | 1880 "Deferred"; 1911 item 21 | Done in C2 (`underground_room_dig_order.gd`, charged in `room_dig_runtime`, 1937 §5) |
| 33 | `qualified-claw-runtime-v1/*` files | coordinator's question, 2026-10-19 | **None pending** from Slice C: no open item edits them |

## 3. What C3 builds now (subject to P-1990-1)

Engineering, recorded and not asked. Each is proved on fixtures (the claw Kitchen of decision 1939, whose access is
bootstrapped as slice D's will be) and, where it shows, in the demo.

- **E1 — The painted Confirm route in core.** One settlement call that takes a confirmed painted room (level, cells,
  type) and a crew, plans it through `RoomOrders.confirm_room` and orders it through the composer, atomically: a
  refused order leaves no claimed Site and no QUEUED record. The way in and the three containers come through one
  seam that D2 fills (`UndergroundRoomComposer.Order`); until then the route is refused in BUILD-REQ-013's words, "No way
  in: needs a way down to level N" (a new word, P-1990-1).
- **E2 — Crew choice in the composer** (item 4): a named list of 1–4 builders, each passing the existing idle-mole test
  (`_builder_into`'s rule, one resident per dig); an empty list keeps P-1936-2 (a)'s first idle mole. Refusals in
  words per builder. Saved through the existing record (the crew is already written, 1937 §4).
- **E3 — Stop and release** (item 5): a settlement stop for a running dig (the foreman's own stop path: open phases
  released, unpaid ones cancelled, BUILD-REQ-019's refunds by ECON-005 per phase) and a release that waits for the crew
  to walk out and then calls `release_room`. Saved: STOPPED is already in the record.
- **E4 — The 1937 leftovers** (items 19–24).
- **E5 — Words and status**: `docs/underground-integration-status.md`, UG24 (`review` when C3 merges; UG09 stays
  `queued` for D2), the demo's guide text and notices.

**Files.** C3's own: `underground_room_composer.gd`, `settlement_system.gd` (the order, stop and release routes only),
`underground_room_parking.gd` (M5), the demo's `build_panel/` files and their tests. **Shared with the retirement
lane** (functions named to the coordinator before editing): `underground_room_runtime.gd` (`reserves_resident` for M7;
a new `stop_room`; `restore`/`_read_state` for M3), `underground_room_foreman.gd` (the stop entry; the actor-Job change
only if item 24 is taken), `underground_room_builder.gd` (none expected beyond item 24). **Not touched:**
`underground_room_world_bindings.gd`, `underground_room_orders.gd` (read only), and every slice D file in the brief and
the coordinator's 2026-10-19 list (`underground_connector_contacts.gd`, the named Locations functions,
`qualified-claw-runtime-v1/*`).

## 4. PROPOSALS for Brendan

**P-1990-1 — What the demo's digging is until slice D's M5 and D2 give level 1 a way in.** (§1: no painted room can be
dug for real before then, anywhere.)

- **(a) Real orders only.** Confirm all creates the real order (Sites claimed, bill shown, crew named) and every room
  then waits, saying "Waiting: no way down to level 1 yet". The free mole is retired. **The demo has no visible digging
  until D2.**
- **(b) Keep the proof of concept as the demo's digging; build the real route behind it.** The demo keeps decision
  1912's mole (free, unsaved, labelled "Proof of concept"), now with the crew choice and Stop of P-1990-4 and -5. C3
  builds E1–E5 in the game's code and proves them on fixtures, including save and load. D2 switches the demo's Confirm
  all to the real route when a level has a way in, and retires the mole then.
- **(c) Close Slice C without C3.** Move C3 whole into slice D's D2. Slice C closes on the retirement lane alone.

**Recommendation: (b).** It keeps the demo playable, builds everything that does not need a way in, and claims nothing
real that is not. (a) takes digging out of the demo for the whole of slice D. (c) leaves crew choice, stop and release
unbuilt. Under (b), Slice C's remaining items after C3 are all (iii): they wait for M5 and D2.

**P-1990-2 — Cost in the demo until the real route pays.** BUILD-REQ-019 stands: nothing is paid at Confirm, each
phase pays when it starts (DEC-061). The real route already pays that way (decisions 1935, 1938).

- **(a) The proof of concept stays free**, as ruled on 2026-10-12 ("Free for now"); the ledger keeps showing each
  cell's bill, labelled "Proof of concept: free".
- **(b) The mole takes each cell's wood and stone from the settlement's stores when it starts the cell**, waiting
  ("Waiting for wood") when they run short. Nothing is hauled, and the earth goes nowhere. It is a stand-in the real
  route replaces.

**Recommendation: (a).** (b) writes settlement stock from demo code by a rule that is not the economy's (no hauling, no
spoil) and is thrown away at D2.

**P-1990-3 — Decision 1880's painted store and its 17.0 MB.** Brendan ruled (Q2) that the bytes fold in when the
columns are first allocated. They are the authoritative painted layout: a 1 m cell grid over five levels, room rows,
their index and directory slots, and edge items (16,957,440 B), saved.

- **(a) Build the whole store now** as a new saved owner; confirmed rooms, ways and edges live in it; fold all
  16,957,440 B; re-pin the pack and its tests; registry and capacity audit; retire the superseded tile rows
  (−1,802,240 B) only if their readers move too. Headroom 44,201,316 → about 27.2 MB. A few days, and in the demo only
  the proof of concept's layout would read it.
- **(b) Build only the cell grid and room rows** that a confirmed room needs (2,949,120 + 2,867,200 + 1,392,640 B), fold
  those, and leave directory slots and edge items held for slice G.
- **(c) Allocate nothing in C3.** The real route keeps RoomOrders' own saved rooms and Sites (already ledgered); the
  fold stays held and moves to slice G, which first needs the painted layout as authoritative state (surface rooms,
  items, edges).

**Recommendation: (c).** Under P-1990-1 (b) nothing would read the store until D2 or G, and Q2's rule ("when first
allocated") then needs no fold. The brief lists the fold as C3's; this is why it is asked rather than built.

**P-1990-4 — How the player chooses the crew** (P-1936-2 (c); up to 4 builders a room, BUILD-REQ-012).

- **(a) The selected moles.** The moles selected when Confirm all is pressed are the crew of every room in that batch,
  1 to 4; with none selected, the first idle mole digs (as today). The panel's footer says "Crew: Bramble, Teasel" or
  "Crew: the first free mole".
- **(b) A crew picker on each confirmed room's card**: a list of idle adult moles, tick up to 4.
- **(c) Both.**

**Recommendation: (a).** No new panel, and the demo already sends the first selected mole (decision 1912 E13). (b) is
slice H's "show who is assigned" polish.

**P-1990-5 — What Stop does to a dig** (`release_room`).

- **(a) One "Stop digging" on a confirmed room's card.** The crew walks out; the dug cells stay dug; the undug cells go
  back to the plan as pending cells, which a later Confirm all orders again (a phase already paid is taken over, never
  paid twice, P-1933-2 (a)); refunds by BUILD-REQ-019.
- **(b) Stop and Cancel as two commands**: Stop keeps the room ordered and idle (it resumes when re-ordered); Cancel
  takes its undug cells out of the plan.

**Recommendation: (a).** One command, nothing lost: the pending cells are the plan, and Undo/Erase already remove them.

## Source

DEC-054, DEC-059, DEC-061 (`docs/setting_decisions.md`); SET-BUILD-001 BUILD-REQ-012, -013, -019; decisions 1871, 1880,
1911, 1912, 1913, 1921, 1931–1941, 1951–1953, 1971, 1972, 2021, 2022, 2041–2044; `docs/handoff/RULINGS.md`;
`docs/handoff/LIVE_WORK.md` and `LIVE_WORK_SLICE_D.md` (2026-10-19); the code cited in §1 and §2 at `8a7d045d`.
