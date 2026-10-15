# 1931 — Slice C2 scoping: the room foreman is stopped for rulings (no claw stroke reaches a room wall, and the owners it drives are over the tick budget)

Date: 2026-10-12 · Status: Ruled (2026-10-12, 2026-10-13, 2026-10-15; see the two rulings sections). C2.1 is built:
decision 1933. Corrections from decision 1971 are below.

**What the game does today (C2.1, decision 1933).** The foreman follows whatever rows are bound. In the game the
bound rows are the claws, and no claw row qualifies against a room wall until decision 1971's universal stroke
lands. So in the game it is claw-only and digs nothing until then. No production code composes it yet (C2.3); only
tests construct it. Its proof runs on the ADR 1213 content-6 retired-pick fixture, by Brendan's leave ("Yes, tests
only"), and takes no height or price from the pick.

Number range: 1931–1949 was allocated to this lane by the coordinator. It was checked free on every local and remote
ref (`git ls-tree` over `refs/heads` and `refs/remotes`) and with `decision_numbers.py`. It replaces no BACKLOG range.
This is the lane record; later records of the lane take 1932 onwards.

## Decision

Slice C2 (decision 1911, P-C1 (b)) was to build ADR 1202 steps 3–7 for rooms on the fixed tick: one project per
confirmed room, Jobs and workers, approach and phase contacts, BRACE/CUT/FINISH cell by cell in BUILD-REQ-012's
breadth-first order with up to 4 builders (P-C9 (a)), Delivery of wood and stone, and honest spoil.

Before writing code, this lane checked the code at `origin/master` 5977191b against what C2 must prove, and measured
the owners C2 would drive. It found two things that need Brendan's rulings before C2 can be built honestly, and one
pricing ruling (P-C3) that rests on content the game no longer uses. **No production code is written in this lane
until they are ruled.** The work is also larger than one lane; §4 proposes a split.

Brendan's rulings that bind this lane (2026-10-12, relayed by the coordinator): P-C1 (b), P-C3 (a), P-C8 (a),
P-C9 (a). They are quoted in decision 1911 and not repeated here.

## Brendan's rulings (2026-10-12)

Relayed by the coordinator. Brendan gave them in chat on 2026-10-12.

| Proposal | Ruling | What it means here |
|---|---|---|
| P-C2-1 | "keep basic claw strokes". Asked to clarify, he chose **"Dig rooms with the down stroke"**: no M2/M3 authoring and no pick. The room rules change so that M1 digs a room down through its cells. If M1 alone cannot do it, stop and report with options. Never use the retired pick rows to justify a height | **Cannot be built with M1 alone.** Decision 1932 proves that no M1 stroke can open the top layer of any underground room, and gives new options. Stopped for a new ruling |
| P-C2-2 | **(a)**: a separate cost lane, `perf/dig-tick-cost`, decisions 1951–1969. It owns `work.gd` `Work.tick_solo` and the routes module's `Routes.advance_tick` | This lane does not edit those files. Gate 6 is judged after the cost lane lands; the foreman's own share is still measured |
| P-C2-3 | **(a)**: price and plan by the identity of the crew that will dig (the claws), never "any row". `reachable_height_u` requires the face the stroke actually strikes | For M1, a room's height is 0 quanta (decision 1932). The per-cell table for C1 is in 1932 |
| P-C2-4 | **(a)**: one small packed record per room plus the existing per-phase projects. Add the note to SET-BUILD-001 §10 | The note is added to `docs/building_model_amendment.md` §10 in this lane |
| P-C2-5 | **(a)**: three lanes; this lane does C2.1 now (foreman on the fixture, breadth-first order, up to 4 builders, spoil, tick wiring, with M1 rooms under P-C2-1), then C2.2, then C2.3 | C2.1 as ruled depends on M1 rooms, which 1932 finds impossible. It waits on the new P-C2-1 ruling |

## Brendan's rulings (2026-10-13 and 2026-10-15)

Relayed by the coordinator. Brendan gave them in chat; decision 1932 quotes them in full.

| Ruling | Where it lands |
|---|---|
| 2026-10-13, P-C2-1 replaced: **"One basic front stroke"**, rooms one quantum high | Superseded on 2026-10-15 (below) |
| 2026-10-13, add-on: **"Yes, tests only"**. C2.1 tests its dispatch logic on the retired-pick fixture and takes no height or price from it; production stays claw-only | Decision 1933's proof |
| 2026-10-15: **"Real digging, in full"**: C2.1 → C2.2 → C2.3 → slice D → C3 | This lane: C2.1 now |
| 2026-10-15: **"I just want the basic claw stroke that digs anything"**. One stroke for any reachable face. Its rows, the work-face qualification, the planner's face choice and `reachable_height_u` belong to the `feat/claw-front-stroke-m3` lane (decisions 1971–1989) | The foreman binds whatever rows the planner selects. This lane edits none of those files, including the frontier's `_face`, which that lane changes |
| 2026-10-15, room height: **"Painted height"**. Each cell's column is dug to the room's full height (DEC-054 amended); the stroke lane publishes quanta and bill | The foreman schedules a cell as stacked cubes, bottom up, and keeps a column with one builder where it can (decision 1933). It prices nothing |

## Corrections (2026-10-15, from decision 1971)

- **Rows 57/59/61/63 are the paw seating tap, not dig rows.** F1's tables below list "the eight dig rows 56–63".
  The dig rows (M1) are 56/58/60/62 only; 57/59/61/63 are the tap, with its anchor 128 u up.
- **F2's "claw identity 1,024 u" comes from the tap rows.** `reachable_height_u` excludes M1's own rows, because
  their anchor sits on y = 0. Decision 1971 tightens that function (its lane's file).

Both findings stand: no published claw dig row strikes a wall, and the pick's 2 quanta was never the claws'.

## 1. Finding F1: on the active content, no stroke can dig a room wall

The game digs with claws (DEC-052, ADR 1217 step 5). The mounted content is revision 10
(`data/underground/first-entry-prefix-v1/qualified-stairs-v9/mole-worker.ugprof`, the bundle
`underground_route_composition.gd` mounts). Its claw identity (source 4, no tool) has a complete travel family, but
its only dig rows are the downward stroke M1:

| Rows (source 4) | Policy | What they are |
|---|---|---|
| 42 | canonical ground (6), all yaws | claw WALK |
| 43–46 / 47–50 | READY_FORWARD (1) / READY_BACKWARD (2), yaws 0, 16384, 32768, 49152 | narrow approach / retreat |
| 51 / 52 | SHORT_BACKWARD (5) / SHORT_FORWARD (4), yaw 0 only | short steps |
| 53–55 | stair (8), stair turn (9) | stair gaits |
| **56–63** | SOURCE_WORK (3), BUILD, anchor-and-patch, four yaws | **M1 downward claw stroke** |
| 64 | SOURCE_WORK, tread fit | paw tap |

Each of the eight dig rows publishes its CONTACT_PATCH **flat in y**. Read from the loaded rows:

| Row | Anchor (CONTACT_POINT) | Patch (CONTACT_PATCH) |
|---|---|---|
| 56 | (224, 0, −544) | (−225, 0, −545)..(225, 0, −543) |
| 57 | (128, 128, −448) | (−129, 128, −449)..(129, 128, −447) |
| 62 | (544, 0, 224) | (543, 0, −225)..(545, 0, 225) |
| 63 | (448, 128, 128) | (447, 128, −129)..(449, 128, 129) |

(58–61 are the same two strokes at the other yaws.)

Why that rules out every Room cube:

- `underground_work_face.gd` `patch_refusal` requires the whole patch to lie on the struck face: on the face's own
  axis `low == high == plane`, and a positive span on the other two. A y-flat patch can only lie on a y face.
- A Room cube on the room floor has its y faces at 0 and 1,024 u above the stance. The claw patches sit at 0 or
  128 u. And the Room planner refuses faces 2 and 3 outright (`ROOM_STATION_VERTICAL_FACE`, ADR 1213: stations are
  planned on the Room floor only).
- So no claw row can strike any face of any Room cube. The room planner would find a "reach" for rows 57/59/61/63
  (`_reaches` checks only the anchor height, 128 u, inside the band), and the contact proof would then refuse it.

This is what ADR 1217's impact table already says: the Room world bindings and the Room planner "wait" on M2 (claw
high-wall stroke), M3 (claw front stroke) and M6, and M2/M3 are last in its order. Neither has been authored. The only
content whose strokes reach a Room wall is the dormant pick content (rows 13–28: FRONT anchor 707 u, HIGH 1,039 u,
with x-flat patches), which is what every Room test since ADR 1213 runs on (the content-6 `StepFixture`, with a pick).

**Consequence.** A production room foreman, run in the real game on the mounted content, would dig nothing. Every
room would end on a contact refusal. That is not a slice D problem: it holds on any level, with any way in.

## 2. Finding F2: P-C3's "2 quanta" is the pick's height, not the claws'

P-C3 (a) priced "the height that is actually cut: 2 quanta per cell on the current rows". The 2,048 u comes from
`Approach.reachable_height_u(profiles, -1)` (identity −1 = any published dig row). On content 10 that still includes
the dormant pick rows (anchors 128, 707, 1,039 u):

| Identity | `reachable_height_u` | Height a crew can actually cut |
|---|---:|---:|
| −1 (any row, what `modular_runtime.gd _make_plan` and the slice-B ledger use) | 2,048 | — |
| Pick, e.g. row 27 (dormant under DEC-052) | 2,048 | 2,048 |
| Claw, e.g. row 63 (the active crew) | 1,024 | **0** (F1) |

So the ledger prices a crew the game does not field. Two further effects:

- A Room planned at 2,048 u and confirmed with a claw work row is refused by `Approach.input_refusal`
  (`ROOM_APPROACH_HEIGHT_UNREACHABLE`), because the claw identity reaches 1,024 u.
- `reachable_height_u` reads only the anchor height, not the patch's face. For the claw rows its 1,024 u is a height
  no claw stroke can actually cut a wall to.

The principle of P-C3 (a) ("price the height actually cut") stands. Its number needs correcting (P-C2-3).

## 3. Finding F3: the owners C2 would drive cost about 3× the whole tick budget for one builder

REQ-SET-163 (as in CLAUDE.md): simulation tick at 1x p99 < 2 ms. This lane measured the ADR 1213 test loop, which
is the same owner calls a foreman makes: `Routes.advance_tick`, `Work.tick_solo`, and the Sites phase API. It ran
on the content-6 `StepFixture`: 8 cubes, one builder, 3,905 fixed ticks, every cube paid with exact ledgers.

Method: a scratch suite (not committed) subclassed `StepFixture` and wrapped each owner call in
`Time.get_ticks_usec()`. Run with `./tools/run_tests.sh --suite`, on the headless editor binary, on Brendan's Mac
(Apple Silicon), at a load average of 3.4–3.6. This is not the qualification floor (a Ryzen 5 3600) and not a
release export. The numbers are for scale, not a floor measurement.

| Per fixed tick, one builder | n | p50 µs | max µs |
|---|---:|---:|---:|
| Travelling: `Routes.advance_tick` | 1,711 | 1,958 | 2,274 |
| Earning: `Routes.advance_tick` | 400 | 1,771 | 1,989 |
| Earning: `Work.tick_solo` on a Room phase | 400 | 4,612 | 11,867 |
| **Earning tick, total** | 400 | **≈ 6,400** | **13,698** |

| Once per phase or cube (a single tick's work) | n | p50 µs | max µs |
|---|---:|---:|---:|
| `next_contact_into` + station publication (per loop step) | 14 | 26,797 | 43,307 |
| `open_phase` + Job creation and binding | 24 | ≈ 20,000–27,000 | 34,449 |
| START (`begin_phase_work` with claims) | 24 | ≈ 110,000–115,000 | 158,309 |
| `settle_phase` | 24 | ≈ 117,000–126,000 | 191,436 |

What follows:

- One builder alone spends about 3× the whole simulation's 2 ms on every earning tick. Four builders (P-C9 (a)) would
  spend about 12×.
- Each START and each settlement is a 110–190 ms stall, about 7–11 frames at 60 FPS. There are six of them per cube,
  and one starts or settles every few dozen ticks.
- The first-entry foreman makes the same two calls on every earning tick. It was not measured here. No earlier record
  measured either foreman against REQ-SET-163.

Gate 6 of this lane ("the room tick must fit REQ-SET-163's budgets") therefore cannot pass by building a foreman on
these owners. It needs the owners made cheaper first (P-C2-2).

## 4. Finding F4: the C2 work is several lanes

Each piece is listed with what it touches. Pinned files are marked †: a memory-pack census input (ADR 1212). Editing
one trips the pack's digest, and ADR 1212's projection update is then needed.

| # | Piece | Files | Size |
|---|---|---|---|
| A | Room foreman: stage machine per builder (select, publish, travel legs, enter, START, earn, hand-over, settle, retreat, park) on the existing owners, after the entry foreman's pattern | new `scripts/core/underground_room_foreman.gd` (and a runtime holder) | large |
| B | BUILD-REQ-012 breadth-first order from the access face, ties by cell index, in packed scratch; the frontier walks key order today | `underground_room_frontier.gd` † or a new order owner beside it | medium |
| C | Up to 4 builders. ECON-001 allows parallel faces only "where the actual support/contact geometry permits". Routes refuses `ROUTE_OCCUPIED`, and the Room bindings' `_ordinary_occupants_leaf` refuses other residents near a contact. Publication refuses while a worker stands on a new span (ADR 1213 "Parking") | foreman; possibly Routes | large, high risk |
| D | Delivery's room pin. `_pin_project` and `_entry_placement` (`underground_connector_delivery.gd` :245–276) serve only the one entry Placement and its Frontier installation frame. Surface stock reaching the underground is the entry's own open gap `ENTRY_HAUL_NO_STAGED_STOCK` | `underground_connector_delivery.gd`, hauler | medium–large |
| E | Spoil. Each CUT posts 2,000 milli-U to the bound output container (`excavation_inventory.gd` :633–647). One spatial ground pile holds 400,000 g (`inventory.gd` :438), about 200 cubes of `excavated_earth`. Earth has no certified carry (`grip_certificate.gd` :48), so when the pile is full the honest result is `SPOIL_OUTPUT_BLOCKED` (ECON-003) | foreman | small |
| F | Station-chain retirement. About 94 route edges is the cold budget (ADR 1213). The 8-cube Kitchen peaks at 40 edges, so rooms over about 16 cubes need finished chains retired, as ADR 1191 does for entry contacts | Locations/Routes/foreman | large |
| G | Production composition (ADR 1202 steps 3–4): an `Approach.Request` built from live Locations; `bind_room_phase_contacts` composed in the Session with a retreat endpoint and travel row. The provider binds once (`_ordinary_routes != null` refuses a second bind) | `underground_session.gd`, `underground_room_world_bindings.gd` † | medium |
| H | Save and load of a room dig in progress. The entry needed ADR 1218/1228. `settlement_save_owners.gd` keeps RoomProjects canonical-empty and refuses an instance holding state | save adapters | large |
| I | Memory: ledger the per-room state, and fold 1880's 16,957,440 B in if C2 allocates the painted columns first (P-C8 (a)) | pack tool, ARCH-BUILD-001, pinned tests | medium |
| J | Tick wiring: `_advance_underground_rooms(tick)` after `_advance_underground_entry` in `settlement_system.gd` `run_tick` | `settlement_system.gd` | small |

A to J is at least three lanes of the size of ADR 1210 or 1213. Even with all of them built, F1 means nothing is dug
in the game, and F3 means gate 6 fails.

## 5. Finding F5: "one project per room" does not match how Sites pay

SET-BUILD-001 §10 (decision 1880 Q1) makes a room's painted cells one room project that owns one excavation site per
quantum. In the code, nothing owns a room's Sites as one Construction project. Each phase of each Site
(`Sites.open_phase` → `Construction.open_excavation_phase`) is its own short-lived Construction project. It is opened
for one BRACE, CUT or FINISH and retired at settlement. RoomProjects (`room_projects.gd`) is a pause and revision hold
over such a live project identity. It is not a parent of Sites, and production does not compose it.

What follows from that:

- At most one phase project is live per worked face. ECON-001 allows at most 4 builders per project, and the
  population cap is 256. So live room phase projects are bounded by the builders, not by the number of rooms.
- Decision 1880's per-room bound (81,920 rooms × (185 + 99) B = **23,265,280 B**) budgets a project and a container
  row for every room. The underground Site model never allocates those rows.
- The state a room actually needs is a dispatch record: room, access, crew, frontier position and refusal. That is a
  few tens of bytes per row, in packed columns.

P-C2-4 asks which reading holds. It decides whether about 23 MB of the 32.8 MB real headroom (1880; 1911 P-C8) must
be spent.

## 6. Other facts found (for the coordinator)

- The only Room fixtures with a way in are the ADR 1161/1213 ones: a bootstrapped Corridor, the content-6 pick rows
  and a tool. They are the only place a foreman can be proven today. That is honest under "test setups that
  already have a way in", but it is the content DEC-052 retired.
- The Room planner's `IDENTITY_FIELDS` match work rows to the bound retreat row's actor, tool and cargo. A production
  binding of the claw retreat (row 50) can therefore select only claw dig rows (F1).
- `underground_room_frontier.gd` and `underground_room_world_bindings.gd` are pinned census inputs in
  `docs/planning/underground_memory_pack.json` (ADR 1212).
- Neither `docs/underground-integration-status.md` nor `docs/handoff/RULINGS.md` (the C1 lane's files) records F1 or
  F3. Text for the coordinator to merge is under "For the C1 lane's files" below.

## 7. Proposals for Brendan

**P-C2-1 — How room walls get dug, given F1.**

- **(a) Author the claw front stroke M3, and the high-wall stroke M2 for the second metre, first.** This is a motion
  lane under ADR 1217's own process: derived from the claw image's clips, then Brendan's review. C2 then proves the
  foreman on the active claws. Room height follows M3/M2's anchors (DEC-054). It is the only path to rooms dug in the
  game, and it is motion and content work, outside C2's files.
- **(b) Build C2 now as a content-agnostic foreman, proven on the dormant pick content.** The row identity comes from
  the bound retreat row (claws in the game). The Job's tool gate follows the row: `GATE_NOT_REQUIRED` and no claim
  when the row names no tool (the game), and claim the crew's tool when it does (the content-6 fixture only). In the
  game it digs nothing until (a) lands. The cost is a tooled branch in production code that only dormant content
  exercises.
- **(c)** Re-activate the pick for Room digging only. This reverses part of DEC-052.

**Recommendation: (a) and (b) in parallel.** (a) is the critical path. (b) lets the foreman, the breadth-first order
and the builder logic land and be tested meanwhile. (c) reverses a ruling for one feature.

**P-C2-2 — The tick cost (F3).**

- **(a) A measurement-and-fix lane on the excavation owners before any foreman is wired to the tick.** It profiles
  `Work.tick_solo` on Room and entry phases (re-proving each tick looks like most of the 4.6 ms) and
  `Routes.advance_tick`, with no change to any rule. It also measures the first-entry foreman the same way.
  Target: an earning tick well under 2 ms per builder on the floor, and no 100 ms phase stalls.
- **(b)** Build C2 now, measure it, and fix the cost later. Gate 6 stays failed and is declared in the PR.
- **(c)** Spread a START or a settlement over several ticks without making it cheaper. This removes the stalls but
  not the per-tick cost.

**Recommendation: (a).** It runs in parallel with (b) of P-C2-1. Without it no foreman, room or entry, meets
REQ-SET-163.

**P-C2-3 — Correct P-C3's number (F2).**

- **(a) Price, and plan, with the identity of the crew that will dig, the claws, never identity −1.** Until M3 lands
  the claw height is 0, so the panel says rooms cannot be dug yet ("Not yet: no claw stroke reaches a wall"), rather
  than pricing 2 quanta. When M3/M2 land, their anchors set the height and the price follows. `reachable_height_u`
  should also require the patch to lie on a side face, so it never reports a height no stroke can cut.
- **(b)** Keep 2 quanta from the pick rows until M3 lands.

**Recommendation: (a).** It is P-C3 (a)'s own principle. This is the C1 lane's ledger and panel, and C3's order
route, so the change is theirs. The `reachable_height_u` tightening is in `scripts/core/` and can go with C2.

**P-C2-4 — What "one project per room" means underground (F5).**

- **(a) One dispatch record per room, in packed columns, plus the existing short-lived phase projects (at most one
  per worked face, at most 4 per room).** The ledger counts the dispatch columns, not 81,920 × 284 B of project and
  container rows. SET-BUILD-001 §10 gets a note: underground room cells are one dispatch, paid per phase. Surface
  rooms (slice G) keep their own reading.
- **(b)** Build a real room-level Construction project that owns its Sites. That is a data-model and save-format
  change in Construction and Sites, and it spends about 23.3 MB.

**Recommendation: (a).** It is how the adopted per-phase payment (ECON-003, ECON-005) already works, and it keeps
about 23 MB of the 32.8 MB headroom.

**P-C2-5 — How to split C2 (F4).**

- **(a) Three lanes after P-C2-1 to P-C2-4:**
  - **C2.1**, the foreman on the fixture: pieces A, B, C, E and J, a dispatch record (P-C2-4), and the
    `reachable_height_u` tightening.
  - **C2.2**, Delivery's room pin and station-chain retirement: D and F.
  - **C2.3**, production composition, save and load, and the memory ledger: G, H and I.

  Order: M3 (P-C2-1 (a)) ∥ the cost lane (P-C2-2 (a)) ∥ C2.1 → C2.2 → C2.3 → slice D → C3.
- **(b)** One long lane doing all of A to J. That is several times the size of any single underground lane so far,
  and it still cannot pass gate 6 or dig in the game without the other two.

**Recommendation: (a).**

## For the C1 lane's files (the coordinator merges; this lane does not edit them)

- `docs/underground-integration-status.md`, "Next, in order": room digging in the game needs claw M3/M2 (ADR 1217)
  as well as slice D and C2. The excavation owners cost about 6.4 ms per earning tick per builder against
  REQ-SET-163's 2 ms (decision 1931 F3).
- `docs/handoff/RULINGS.md`: P-C3 (a)'s 2 quanta rests on the dormant pick rows; see P-C2-3 (decision 1931).
- The build ledger and `modular_runtime.gd _make_plan` use identity −1 (2,048 u). With a claw work row, that plan is
  refused at confirmation (F2).

## Gates

Documentation only; no GDScript changed and nothing was allocated, so the Godot suite, the analyzer, mutation
testing, the reviewer and the performance gate do not apply to this commit. They apply to the code lanes in §7. The
measurements in §3 and the row tables in §1–2 were made with scratch scripts that are not committed; the method is
stated beside each.

- `python3 docs/validation/decision_numbers.py`: `decision_numbers: PASS -- 548 records, 0 problem(s)`.
- Decision 1911 is cited from the C1 lane's branch (`feat/build-panel-slice-c`, commit 8bca8be9); it is not on this
  branch.

## Source

DEC-052, DEC-054, DEC-059 and DEC-061 (`docs/setting_decisions.md`); SET-BUILD-001 §7.2, §8, §10 and BUILD-REQ-012;
SET-MOVE-ECON-001 ECON-001, ECON-003 and ECON-004; REQ-SET-163; decisions 1161, 1191, 1202, 1205, 1207, 1210, 1212,
1213, 1215, 1217, 1218, 1220, 1228, 1229, 1880 and 1911; code at `origin/master` 5977191b as cited above.
