# 2091 — Stair-leg Delivery on M5's flight: scoping (stopped for rulings)

Date: 2026-10-21 · Status: Accepted. Brendan ruled P-2091-1 to P-2091-8 (a), as recommended, on 2026-10-21 (see
"Brendan's rulings"). Phase 1 is recorded in decision 2092.

**Number.** The coordinator allocated 2091–2099 to this lane, with 2091 for this record. 2091 is free on every local
and remote ref (`git log --all -- 'docs/decisions/209*'` finds nothing), and `decision_numbers.py` passes. Branch
`docs/stair-leg-delivery`, cut from M5's pushed head `ea9c7ed6` (`feat/slice-d-m5-full`).

**Citations.**
- `[M5]` marks a file at `ea9c7ed6`.
- Decisions 2052, 2053 and 2081 are on origin/master `e0e7065a`, and 2082 is on `origin/feat/entry-batched-build`.
  None of the four is on this branch.
- Code paths are under `godot/scripts/core/` unless given in full.

## Brendan's rulings (2026-10-21)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion, saying **"Approve, start phase 1"**.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2091-1 to P-2091-8 | **(a)**, as recommended | Slice D owns stair-leg Delivery; one stair runner per World; a one-pass static leg reach; loaded edges published when the way in binds; down-only, 2b-2 next; derived leg lists on load, the runner's cursor in the room record; D2 phase 2 adds the store's grip stand and its CARRY span; today's rates, with the figures handed to the room-pace study (which starts separately) |

## Decision

Build stair-leg Delivery once, on M5's real flight, as decision 1941 §2 lists. The list changes in five ways:

- **Down-only.** It carries wood and stone **down** from the surface R to the level-1 store beside F′.
  - It carries nothing up.
  - Room spoil goes to the level-1 foot pile (P-2052-2 (a)), and the entry's deep spoil to a foot pile (P-2081-4).
  - Spoil up the stair is 2b-2's earth carry, which follows as its own lane (P-2091-5).
- **A stair runner hauls.** One runner per World stocks the level-1 store. Room builders draw from that store on their
  own level and wait when it is short (P-2091-2).
  - Today's builder haul, extended over the stair, would sweep the whole flight into each cube's claim.
  - It would also overflow the room record's trip bounds (finding F6).
- **Static legs.** Delivery's reach checks each stair leg as one static edge certificate, as Contacts does. The legs
  are resolved in one pass over the live edge table. A graph search is used only where a ground segment has more than
  one edge (P-2091-3).
- **Loaded edges publish late.** The flight's loaded edges are published once, when the way in binds, and not during
  the build. M5's measured build is then untouched (P-2091-4).
- **Today's rates.** Every trip carries one whole unit. The pace is handed to the room-pace study (P-2091-8).

## 1. What changed since 1941

| 1941 (2026-10-17) assumed | Now |
|---|---|
| One floor end (F40, the flight's floor at world −512) | M5: five modules and four intermediate landings. Level 1's floor is module 4's floor (decision 2044:47-49) |
| The stair carry runs H to the sill and back | Still so on M5. `carry_plan` is module 0's only ([M5] `underground_entry_stair_path.gd:245-256`, header :24-25: "until stair-leg Delivery") |
| Rows 71/72 and the floor carry wait for the floor end | Rows 71/72 are published at every landing (P-2044-16 (a)). The floor **carry** was deferred to this work by P-2044-14 (2044:622-629) and was never re-published |
| Staging on another level is the only source | P-2052-2 (a): the level-1 store and pile are beside F′, and staging is the surface R. P-2052-7 (a): a labelled stand-in fills R |
| The room builder hauls (decision 1934) | P-2081-3: the entry crew never hauls, and village haulers keep M stocked. P-2081-8: room rates are unchanged until the room-pace study |
| Spoil up the stair may be needed | P-2081-4: deep spoil goes to the foot pile. One pile holds about 200 cubes, about 50 cells (2042:82-83) |

## 2. Findings (code at `ea9c7ed6` unless marked)

**F1 — What the flight publishes today.**
- WALK edges.
  - Every module's tread WALK edges (`_module_treads`, :206-215).
  - Each landing's floor WALK edges (`_landing`, :225-242). These are the descent onto F, the half-turn F → U, the
    ascent, the walk-off 71 F → F′ and the back-up 72 F′ → F.
  - The landing's joins at F′. Down the flight they run F′ → P′, H′, D on 43. Back they run on 47. U0′ → D/R′ is on 45
    (P-2045-11).
- CARRY edges. There are only module 0's 17: H → A(L0), seven descents to T6, the half-turn on T6, seven ascents and
  U(L0) → H (:245-256).
- **No loaded edge reaches landing 1.** None of these exists:
  - A(sill) → F on 74/80;
  - the loaded walk-off F → F′ on 73/79 (1981 W1/S1 serve both the approach and the walk-off; 1981:110-112);
  - any loaded join from F′ to the next module's H′;
  - any loaded edge on modules 1–4.

**F2 — The empty way up already exists and is used.** Walking up uses these:
- `hops_up`, `hops_up_from_landing` and `hops_up_from_walk_off` (:454-501);
- the turn at R′ on 42 (P-2045-11 (a));
- the M5 crew's climb to X before it hauls (`underground_entry_foreman.gd:276-296`, `_haul_or_climb`);
- decision 1940's walk-out.

**The hauler cannot turn** (2044:900-901; 1935 choice 4). Its empty return must walk the way the foreman's crew does,
turning onto each row. R′ needs a turn on every landing on the way up.

**F3 — Leg counts on M5.**
- **Loaded, down: 54 stair legs.**
  - Module 0 has 10: the approach 73, eight descents 74 (seven treads, then the sill onto F) and the walk-off 73.
  - Modules 1–4 have 11 each. Each adds a loaded join F′(j) → H′(j) before its own approach.
  - Two ground segments come on top: R's stand → H, and F′(5) → the store's stand.
- **Empty, up: 59 legs.**
  - Each of landings 5 to 1 has 10: the back-up 72, the half-turn 55 and eight ascents 54.
  - Landings 4 to 1 add two legs each at R′: 45, then 47 after the turn.
  - One more leg, U(L0) → X on 45, ends the climb.
  - The ground walks X → R's stand and the store's stand → F′(5) come on top.
- The laden walk down takes **2,100 ticks**: 90 + 40 × 30 + 90 + 4 × 180 (2081:49, 187).
- An M5 haul round trip takes **4,425 ticks** at least (2043:222, 231).

**F4 — Delivery checks one CARRY route over the whole way.**
- `_reach_stands` makes two graph reaches: the worker to the source stand, then the source stand to the destination
  stand on the item's CARRY row (`underground_connector_delivery.gd:612-621`).
- A path over stair edges can't pass. The CARRY row the grip certificate names is the ground carry, and the stair
  rows are explicit, rooted rows (1981:501-508).
- Each operation gets the whole bound: `_checks = Space.MAX_CHECKS` (:164).

**F5 — A graph reach is expensive. A static leg is cheap.**
- **A graph reach** (`WorldRoutes.profile_reachability_refusal`) is precharged as follows:
  - `REACH_SCOPE_CHECKS + (4 + REACH_WITNESS_CHECKS) × location capacity` = 1,024 + 68 × 1,024 = **70,656** on entry
    (`underground_world_routes.gd:54-55, 2215`). Location capacity is `Budget.LOCATION_CAPACITY` 1,024
    (`underground_budget.gd:12`; `underground_route_composition.gd:116`).
  - Another 1,024 is charged on exit (:2230).
  - The search's own spend comes on top: one check a heap step in `_find_path` (`underground_routes.gd:1788`), and 16
    a certified edge of the found path in `_path_chain_refusal` (:1751).
  - So one reach costs **at least 71,680**.
- **A static leg in Contacts' form** (`_row_path_refusal`, `underground_connector_contacts.gd:1559-1574`) costs much
  less:
  - It scans the live edge table at one check a row until the matching edge. That is at most `Routes.MAX_EDGES`
    1,536 (`underground_routes.gd:53`).
  - It then reads that edge's published certificate (`static_profile_edge_refusal`, `underground_world_routes.gd:2712`).
    The read is not charged to the caller.
  - `_legs_refusal` (:1454-1464) charges one scope leaf after the last leg (decision 2045:822).
- **Per-leg graph searches are impossible.** 54 graph reaches would cost at least 3.87 M, which is over the bound.

**F6 — The room builder's haul can't take the stair as it is.**
- `_level_refusal` admits only one level (`underground_room_builder.gd:434-448`).
- Its trips are graph searches on the haul rows (`_plan_trips`, `_trip_path`, :499-531).
- The claim keeps at most `MAX_TRIP_EDGES` 32 edges and two carry rows (`underground_room_claim.gd:13-14, 42-45`). It
  sweeps every trip edge into the cube's footprint.
- **A stair trip has about 115 edges and would claim the whole flight for each cube.**
  - That holds every other builder's turn-taking and the foot itself.
  - It also needs the room record's save bounds raised (`underground_room_progress.gd:38-45`).

**F7 — The hauler's carry stage is one automatic route** (`underground_entry_hauler.gd:280-290`):
- `_lift` refreshes onto the automatic CARRY mode;
- it requests one route to the store's stand;
- `write_state` saves the approach legs only (:363-386; `Progress.MAX_LEGS` 24 at
  `underground_entry_progress.gd:39`).

The batched-build lane claims this file (2081:472), but that lane is paused behind the cost lane (P-2082-1 (a)).

**F8 — A loaded mole can't turn on the ground.** A ground CARRY edge has to arrive on the grip heading
(`underground_entry_work_area.gd:352-358`, `_carry_approach`). So each loaded join must arrive already facing the way
its next row runs:
- R's stand → H must arrive facing down the flight;
- F′(j) → H′(j) runs straight down the flight's centre line;
- F′(5) → the store's stand must enter on the grip heading.

The empty rows 43/45/47 at F′ clear the sill only because they face down the flight (P-2044-16 (a)). P-2044-14 (a)
failed because nobody checked the ground rows' bodies against the sill deck: the bodies met it at 69, 352, 369 and 26 u
(2044:740-753). **The loaded rows 73/74/79/80 at a landing, and every loaded ground join, have no clearance test
yet.** P-2044-16's covers rows 53/54/55/71/72 (2044:808).

**F9 — The level-1 store has no grip stand.**
- D2 phase 1 makes the store and pile as STORAGE endpoints at the Foot's points, joined to the access by straight
  spans (2053:50-54).
- The hauler and Delivery both need one live WORK endpoint at `Grip.stock_offset(QUARTER)` from the store
  (`underground_entry_hauler.gd:342-355`; `stand_of`, `underground_connector_delivery.gd:703`).
- They also need a CARRY span from F′ into that stand on the grip heading.

**F10 — Late saves don't load yet.**
- P-2045-14: the Space owner's `_overlap_refusal` is quadratic on load. Saves after about tick 78,000 can't load
  (2045:810-812, 857-881).
- Every level-1 room and every stair trip comes after tick 92,560.
- So nothing in this lane can be measured from a level-1 checkpoint, or save-tested, until the M5 lane's P-2045-14 fix
  lands. **That is why this record estimates the costs instead of measuring them.**

**F11 — Pace.**
- A BRACE takes 250 milli-U of wood and 250 of stone (`excavation_contract.gd:14-15`).
- If every cube takes one BRACE, as the Kitchen's 16 Sites do, a 16-cube room needs 4,000 + 4,000 milli-U. That is
  **8 whole units, so 8 round trips**.
- At 4,425 ticks a trip that comes to **about 35,400 ticks**: about 19.7 minutes at 1x, nearly two game days.
- The room's own dig takes 2,976 ticks (2081:230-232). **Stair hauling is about twelve times the dig.**
- The stair is single-file, and a hauler stops on a held step (`ENTRY_HAUL_ROUTE_HELD`). So at most one loaded mover
  is on it at a time. **Throughput is at most about four units a game day.**

**F12 — 2b-2 and this lane edit the same three files.**
- The files are Delivery, the hauler and the room builder (2042 seams 3 and 8, 2042:322-362).
- 2b-2 also switches the grip certificate's preload to `quantity_of` (earth trips are 5,000 milli-U).
- This lane must read every trip quantity through the grip accessor (1941:13-16), never a literal.

## 3. The build list, updated (1941 §2 item by item)

**1. The leg helper.** New, stateless: `underground_stair_legs.gd`.
- It builds the loaded list down: from R's stand to H, then down every module, then from F′(5) to the store's stand.
- It builds the empty list up: from the store's stand to F′(5), then up every landing through R′, then from X to R's
  stand. It reuses `StairPath.hops_up*` and reads `StairPath.Stops`.
- It picks each row by the grip certificate's item: wood 73/74, stone 79/80.
- It resolves every leg's edge in **one pass** over the live edge table, matching (from, to, mode). Then it reads one
  certificate per leg.
- Changes from 1941:
  - landings and the R′ turn;
  - the loaded joins F′ → H′;
  - down-only (no loaded ascent or half-turn);
  - the one-pass resolution.

**2. The loaded edges.** These are the floor carry that P-2044-14 deferred, now on all five modules.
- `StairPath.carry_plan` grows by these down-only CARRY edges:
  - module 0's A(sill) → F(1) and the walk-off F(1) → F′(1);
  - for modules 1–4: H′ → A0′, seven descents, the sill → F and the walk-off;
  - the joins F′(j) → H′(j).
- That is about 46 new stair and landing edges, plus the two ground joins (R's stand → H if the work area has none, and
  F′(5) → the store's stand).
- They are published once, when the way in binds (P-2091-4).
- At M5's measured rates (2044:883-885) that is roughly:
  - 44 stair edges at about 1,320 checks = **58k**;
  - 4–6 ground edges at about 10,000 = **40–60k**;
  - so **about 100–120k**, added to every later requalification at the foot.
- On M5's finishing WorldRoutes peak of 649,811 (2045:846) that gives **about 770k (73 %)**. This is an estimate, and
  gate G2 measures it.
- 1941 had none of this. The flight only had a floor end.

**3. Delivery's leg reach** (`_reach_stands`).
- It keeps the worker → source stand graph reach as it is today.
- It replaces the source → destination graph reach with the helper's loaded list: static legs, plus the two ground
  joins as one-edge legs where a single published edge joins them.
- The admission estimate is in the cost table below.

**4. The hauler's carry stage as a leg list.**
- `_lift` walks the loaded list, switching rows at rest at each leg's end, as the installer's legs do.
- The empty return walks the up list with turns at R′. It uses the room walk's turning legs, or `WorldRoutes.turn_actor`
  as `_to_source` does (:247-258).
- Save: the lists are derived again on load from the live graph and the actor's Location, as 1941 §2.3 recommended.
  There is no wire change for the lists (P-2091-6).

**5. The room builder.** Changed from 1941 by P-2091-2.
- The builder no longer hauls over the stair.
- When its staging is on another level and a stair runner is bound and has proved its way, a short store **waits**
  ("Waiting for wood and stone from the surface") instead of refusing.
- `ROOM_HAUL_NO_STAIR_CARRY` stays where no runner has proved the whole loaded way and the whole empty way back: levels
  2+, and a broken flight.

**6. New: the stair runner** (P-2091-2). A fixed-tick runtime in a new file.
- It drives one Hauler to stock the level-1 store. The target is the confirmed level-1 rooms' remaining BRACE bill in
  whole units (`Hauler.units_into`), less the store's free stock.
- It checks the whole loaded way and the whole empty way once per stocking run, not once per BRACE.

### Cost of one admission, against `MAX_CHECKS` 1,048,576 (estimated; F10 prevents measuring)

| Part | Today (same level) | Per-leg scan (Contacts' form) | One pass (P-2091-3 (a)) |
|---|---:|---:|---:|
| Worker → R's stand (graph) | ≥ 71,680 | ≥ 71,680 | ≥ 71,680 |
| R's stand → H | — | ≤ 1,536 (one edge) or ≥ 71,680 | ≤ 1,536 or ≥ 71,680 |
| 54 stair legs | — | ≤ 82,944 | ≤ 1,536 + 54 certificate reads |
| F′(5) → store's stand | — | ≤ 1,536 or ≥ 71,680 | ≤ 1,536 or ≥ 71,680 |
| Source → destination (graph) | ≥ 71,680 | — | — |
| **Total** | **≥ 143k (14 %)** | **157k–300k (15–29 %)** | **75k–220k (7–21 %)** |

- **Real time.** M5's ratio is about 1 M checks for 55 ms (2045:908-941). The admission tick would cost **about
  4–16 ms**, once a trip, so about 8 times per Kitchen. That is over REQ-SET-163's 2 ms p99 on that tick, but cheaper
  than today's same-level admission.
- **Handling ticks.** The lift and set-down Work ticks already run Delivery's full final proof on every tick, about
  3.5 ms on the Kitchen (1935 "Performance"). That is the cost lane's, not this lane's.
- **The runner's way check** is the loaded column plus the 59 empty legs: about 77k–230k, once per stocking run.
- **Routes and Contacts.** No Routes file is edited, so Slice C's `perf/routes-cost` lane does not collide. Its
  per-compile-window owner pass lowers every graph reach above. No Contacts code changes either.
- **What gates this.** The estimate rests on M5's per-edge costs and on F5's precharge formula. Gate G2 measures it on
  the level-1 checkpoint once F10 is fixed.

## 4. What it carries, and the earth carry

- **Materials.** Wood and stone, one whole unit a trip (`Grip.QUANTITY_MILLI`, read through the accessor), from the
  surface R down to the level-1 store's stand.
  - R is stocked by P-2052-7's labelled stand-in until HAUL-H3+.
  - The store is stocked by the stair runner (P-2091-2 (a)).
  - Room builders take from the store on their own level.
- **Spoil.** It goes to the level-1 foot pile and is not carried up. That covers rooms (P-2052-2 (a)) and the entry's
  deep spoil (P-2081-4).
  - One pile holds about 200 cubes (2042:82-83).
  - **If the batched build lands P-2081-4 into the same pile,** M5's 100 deep cubes (2043:228) take about half of it.
    That leaves about 100 cubes, about six 16-cube rooms, before the pile is full.
- **The earth carry (content 13, 2b-2).** It is still needed, but only once the pile nears full. It is not needed to dig
  the first level-1 rooms.
  - It is this lane's upward twin: the same helper, the loaded rows reversed (W6/S6, the half-turn, the ascents, the
    retreat; 2042:164-166), with 2042's seams 1–9.
  - When: P-2091-5.

## 5. Who hauls (P-2091-2), multi-heading and one access

- **One access per World** (P-1936-1 (a); `ROOM_DIG_OTHER_ACCESS`; 2052 F11) means **one flight**.
- **The flight is single-file for a loaded mover.** The hauler fails on a held step (F11). So a World needs at most one
  stair hauler at a time. Two would hold each other, which is today's hard stop.
- **Multi-heading** (decision 1943) lets several rooms be dug around the one access, by up to five stations a
  publication.
  - With the builder hauling, each builder would queue for the stair and claim the whole flight for every cube (F6).
  - With a runner, builders contend only for the store's stock. They already do that safely: inputs are reserved at
    set-off (1935 choice 2).
- **2081's rule for the entry** was "the crew never hauls; haulers keep the store stocked". The runner is the same rule
  applied to the level-1 store. It is the underground leg that HAUL-H3+ can later take over.

## 6. Pacing (P-2091-8)

- One unit a trip, and **4,425 ticks a round trip** at least (2043:222).
- A 16-cube room takes **8 trips, about 35,400 ticks**: 19.7 minutes at 1x, against 2,976 ticks of digging.
  - With the builder hauling, the room takes all of it in series.
  - With a runner stocking ahead, digging overlaps the stocking. The room is still bounded by about four units a game
    day.
- **2081's time scale doesn't apply.** P-2081-8 rules it "entry only for now; rooms keep DEC-059's rates", with a
  room-pace study after D2. The batched build's commits and time scale (P-2082-2..7) are the entry's only.
- **Cold transitions per trip:** one admission, one load and one unload transfer (9–13 ms each on the Kitchen, 1935).
  That is about 24 a Kitchen, small next to the dig's own transitions (2082:45-55).
- **This lane hands the room-pace study three figures:** the 35,400-tick haul, the four-units-a-day stair, and the
  per-trip transitions.

## 7. Proposals for Brendan

**P-2091-1 — Who builds stair-leg Delivery.**
- **(a) Slice D.**
  - Slice D owns M5's stair path, work area and bundles, and D2's way-in files. Most of the new edges and stops land in
    those files.
  - Slice C would clear a named function list in Delivery (`_reach_stands`, `_observe_admission`), the hauler (`_lift`,
    `_carry`, the return) and the room builder (`_haul_units` / `_level_refusal`'s wait). This is how the six
    WorldRoutes functions were cleared for M5.
- (b) Slice C. They built Delivery's room branch and the builder's haul (decision 1935). But the stair path, work area
  and Foot are Slice D's, and Slice C is running the Routes cost lane and owes Fix D after M5.
- (c) Split: Slice D builds the helper, edges, stand and runner, and Slice C builds Delivery's reach and the builder's
  wait. Two lanes would then both edit the hauler.

**Recommendation: (a).**

**P-2091-2 — Who carries wood and stone down.**
- **(a) One stair runner per World.**
  - It stocks the level-1 store from R ahead of demand. Room builders draw on their own level and wait, rather than
    stop, while it is short.
  - The runner is one resident taken from the room crews' pool.
  - It shows "Carrying wood and stone down the stair".
- (b) Each room builder hauls its own BRACE's units over the stair (decision 1934's model, extended).
  - It needs the claim's `MAX_TRIP_EDGES` raised from 32 to at least 128 and the room record's save bounds raised.
  - Every trip claims the whole flight, and builders queue at the stair.
- (c) None yet: keep the fixture's direct stocking of the level-1 store until HAUL-H3+ (blocked). P-2052-6 (c) and
  P-1990-2 (b) rejected this kind of stand-in.

**Recommendation: (a).**

**P-2091-3 — How Delivery checks the loaded way.**
- **(a) One static certificate per leg, resolved in one pass over the live edge table.**
  - The ground joins count as one-edge legs where one published edge joins them.
  - The only graph search left is the worker's walk to the source stand.
  - This is exact: the same edges and certificates are checked as Contacts' per-leg form, and only the scan is
    shared.
  - Estimated 75k–220k checks.
- (b) Contacts' per-leg scan form as it stands (`_row_path_refusal` for each leg): up to about 83k more.
- (c) A graph search per leg: at least 3.87 M, over the bound.

**Recommendation: (a).**

**P-2091-4 — When the loaded edges are published.**
- **(a) Once, when the way in binds.** That is at `STEP_DONE`, and again after a load through D2 phase 2's re-bind.
  - M5's build is untouched, and its SHA trace stays byte-identical up to `STEP_DONE`.
  - The cost is one publication of about 50 edges.
- (b) Per module, as each sill is installed. Every M5 landing's measured peaks change and must be measured again.
- (c) On the first stair haul. The publication's cost then falls inside a room's tick.

**Recommendation: (a).**

**P-2091-5 — Spoil, and when 2b-2 (the earth carry) comes.**
- **(a) Down-only now.**
  - Room spoil goes to the foot pile.
  - 2b-2 follows as the next lane, with the same owner, reusing the leg helper reversed.
  - Until it lands, a full pile stops the room with an alert.
- (b) Build 2b-2 in this lane: one pass over Delivery, the hauler and the builder, including the `quantity_of` switch.
  It is longer, and it holds up the first real level-1 rooms.
- (c) Add more level-1 piles beside F′ and defer 2b-2. It needs floor room in the run-out, which is unproved, and only
  postpones the problem.

**Recommendation: (a).**

**P-2091-6 — Saving a stair trip.**
- **(a) The leg lists are derived again on load** from the live graph and the actor's Location (1941 §2.3).
  - The runner's small cursor is saved in the room runtime's record as a fixed tail, with its census and ledger row.
  - ARCH-SAVE-006 next-tick parity is tested mid-trip.
- (b) Save the full lists. That means `MAX_LEGS` of at least 128 and a section-6 and wire bump.
- (c) A new saved owner for the runner: a registry entry, a census row and a capacity audit.

**Recommendation: (a).**

**P-2091-7 — The store's grip stand and the loaded span into it.**
- **(a) D2 phase 2 adds them to the Foot now.**
  - That is one WORK endpoint at `Grip.stock_offset(QUARTER)` from the store, and one CARRY span from F′ entering it
    on the grip heading.
  - D2 is in that file, and it owns P-2052-2's positions.
  - This lane's clearance test checks the shape first.
- (b) This lane adds them later in a new file, beside D2's Foot.

**Recommendation: (a).**

**P-2091-8 — Pace.**
- **(a) Today's rates.** One unit a trip, about 4,425 ticks a round trip, so about 35,400 ticks of hauling per 16-cube
  room. The measured figures go to the room-pace study (P-2081-8).
- (b) Apply an entry-style time scale to stair hauling now. It goes beyond P-2081-8's "entry only".
- (c) Carry more than one unit a trip. That needs new grip and carry content, outside the qualified motion of contents
  12 and 13.

**Recommendation: (a).**

## 8. File plan

| Phase | File | Change | Owner / held by |
|---|---|---|---|
| 1 | `scripts/core/underground_stair_legs.gd` (new) | The leg helper | This lane |
| 1 | `test/test_underground_stair_legs.gd` (new) | Plan shape on the M5 stop set; the empty way up on the live WALK edges from a loadable `underground_flight` checkpoint (before tick 78,000) | This lane |
| 1 | `data/underground/mole-worker/test_loaded_landing_clearance.py` (new) | Loaded decks 73/74/79/80 at every landing; the bodies of the ground joins F′ → H′, F′ → the store's stand and R's stand → H | This lane |
| 2 | `underground_entry_stair_path.gd` | Down-only loaded edges for every module and landing; `publish_loaded` | **M5** (after it merges) |
| 2 | `underground_entry_work_area.gd` | R's stand → H CARRY edge arriving down the flight, if missing | **M5** (after it merges) |
| 2 | `underground_way_in.gd` | The store's stand and its CARRY span (P-2091-7 (a)); call `publish_loaded` at bind | **D2 phase 2** |
| 3 | `underground_connector_delivery.gd` | `_reach_stands` → leg reach | Slice C clears the functions (P-2091-1); 2b-2 later |
| 3 | `underground_entry_hauler.gd` | Leg-list carry stage; turning empty return; derived on load | Batched-build lane's claim (paused); 2b-2 later |
| 4 | `underground_stair_runner.gd` (new) | The runner | This lane |
| 4 | `underground_room_builder.gd`, `underground_room_foreman.gd`, `underground_room_runtime.gd` | Wait on a bound runner; the runner's tail in the room record | Slice C clears the functions |
| 4 | `test/fixtures/checkpoint_recipes.gd` (`underground_level1`) | Remove the fixture's direct stocking of the level-1 store (2052 §2.5) | D2's recipe; this lane edits it |
| 4 | Census, memory pack, ledger, registry audit | Runner bytes | Regenerated |

## 9. Phased build plan and gates

**Phase 0 — rulings.** Brendan rules P-2091-1 to -8, which are recorded here and in `docs/handoff/RULINGS.md`. The
coordinator agrees ownership with Slice C.

**Phase 1 — now, before M5 merges** (new files only; no M5, D2, Delivery, hauler or builder file).
- The leg helper, its test, and the loaded clearance test (§8 phase 1).
- **G0, stop on failure.**
  - Every loaded body clears the sill, the decks and the treads at every landing.
  - Every loaded ground join arrives on its next row's heading without a turn (F8).
  - If a body collides, report options as P-2044-16 did. The cause is either retained floor or a stop moved by M5's
    owner, and nothing is published until it is ruled.
- Plus the focused suites, the analyzer (0 warnings, on the coordinator's port), `decision_numbers.py`, and
  `git diff --name-only` naming no held file.

**Phase 2 — after M5 merges, after its P-2045-14 fix (F10), and with D2 phase 2's bind hook.**
1. Probe at `STEP_DONE`: which stops survive the walk-out (H′, P′, D, R′, F, U and F′ at each landing).
   - If H′ is gone, the join's end moves to A0′, and the clearance is redone first.
2. Publish the loaded edges at bind (P-2091-4 (a)).
- **G1.** M5's SHA trace is byte-identical through `STEP_DONE`, and the checkpoints match.
- **G2.** Measured:
  - the bind publication's WorldRoutes and Locations peaks;
  - a front-station publication after it;
  - one admission's spend.
  - Each must sit under `MAX_CHECKS` within M5's current margins (WorldRoutes ≤ 73 %, the estimate). Stop and report
    if any exceeds 90 %.

**Phase 3 — Delivery and the hauler** (functions cleared by Slice C; sequenced before 2b-2).
- **G3.**
  - One unit carried live from R to the level-1 store on the M5 chain.
  - A mid-trip save loads with next-tick parity.
  - A held step still stops (`ENTRY_HAUL_ROUTE_HELD`).
  - A broken leg refuses with its own code.

**Phase 4 — the runner and the builder's wait.**
- **G4.**
  - A level-1 room is dug end to end from the runner's stock, with the recipe's direct stocking removed.
  - `ROOM_HAUL_NO_STAIR_CARRY` is still raised on a level with no proved way.
  - Two rooms on two headings share the store.

**Phase 5 — the full gates.**
- The full suite CI-style at master's shard count (12), the analyzer, every contract (with the `underground-memory`
  job's three commands), mutation testing, and an independent review.
- Frames at 1280 × 720 and 1920 × 1080 of a loaded mole on every landing and at the store, each one looked at.
- Then D2 phase 3 (the demo switchover) may start.

**What can start before M5 merges: phase 1 only**, about three new files. It doesn't touch M5's held files,
`feat/slice-d2-phase2`'s way-in files, or Slice C's Routes cost lane (`underground_routes.gd` is never edited here).
Phases 2–5 wait for M5's merge and its P-2045-14 fix. Phase 2 also needs D2 phase 2's bind. Phase 3 needs Slice C's
clearance and must be sequenced against 2b-2 and the paused batched-build lane, which all edit the hauler.

## 10. Risks

- **The loaded clearance may fail at a landing**, as the empty rows did (P-2044-14). That is why G0 comes first.
- **The added edges raise every foot publication's cost.** D2's front stations and room digs at the foot all carry
  about 100–120k more. G2 measures this. The fallback is Slice C's stage 2 or the cost lane's index work, not a raised
  `MAX_CHECKS` (P-2044-15: "not raised").
- **H′ and P′ may be retired at `STEP_DONE`.** Phase 2's probe settles this.
- **Throughput.** About four units a game day may make level-1 rooms feel slow. That is for the room-pace study, not
  hidden here.

## Source

- Decisions 1934, 1935, 1936, 1937, 1940, 1941, 1943, 1972, 1981, 2041–2045, 2052, 2053, 2081 and 2082.
- RULINGS P-1941-1 (b), P-2044-14/16, P-2045-11/15, P-2052-2/7, P-2081-3/4/8 and P-2082-1.
- The code at `ea9c7ed6`, as cited.
- The coordinator's working file `docs/handoff/LIVE_WORK_SLICE_D.md` (untracked; read, not edited).
