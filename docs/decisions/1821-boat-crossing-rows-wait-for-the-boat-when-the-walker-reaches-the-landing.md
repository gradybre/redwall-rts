# 1821 — Boat crossing rows: the route planner waits for the boat at the time the walker reaches the landing
Date: 2026-10-09 · Status: In progress (phase 1 scoping done; phase 2 build under way)

Lane: boat crossings (branch `feat/boat-crossings`, decisions 1821–1829; `docs/handoff/LIVE_WORK.md` §2). It follows
Brendan's ruling on the fishing revamp (decision 1711, 2026-10-07): "**Boats: (a)** -- fishing boats stay task-driven
(0432, 0461); river trade's boats get router crossing rows later, in a lane that owns the router." The digging lane held
the router until 2026-10-09; this lane holds it now. River trade (#37, Q-D17) is **not** scoped and is not built here.

Numbering: 1821 is the first of the range the coordinator gave this lane (LIVE_WORK §2). No branch or remote uses any
`18xx` record (checked with `git ls-tree` over every ref, 2026-10-09).

## Phase 1: how crossings work today

All of it is the live demo's router (decision 0196: presentation over integer rules). The settlement simulation's
pathfinding (`systems_architecture.md` §7) has no water crossings and is not touched.

**The planner** (`demo/tunnel/tunnel_router.gd`). A small dense graph per trip: START, GOAL, the usable tunnel mouths and
both ends of each crossing offered (at most `MAX_CROSSING_PAIRS` = 8 a plan). Edges are SURFACE (planned lazily by
`cast_nav.gd`, cached stop to stop), TUNNEL, and CROSSING: an end to its partner at a **fixed** cost. Costs are
walking time as metres at the walker's pace (float). Ties go to the route with fewer tunnels and crossings. A trip
whose straight line meets no water is offered nothing and plans exactly as before.

**What is offered** (`demo/waterplay/water_crossings.gd offers_for / offer_into`):

| Crossing | Row | Cost | Closed when |
|---|---|---|---|
| Bridge | 0–5 (`MAX_BRIDGES`) | deck walk × the weather's pace | not yet built |
| Swim link | from 6 (`LINK_ROW0`), the 3 nearest | bank walks + swim at the speed made good across the flow | the walker may not swim (load, consent, rest under 4000: HAZ-001), the flow is too strong, the pond is iced |
| Ferry | 3500 (`FERRY_ROW`) | both decks + the row + **the wait for the next boarding from now** | storm, hard freeze, flood, pond ice; unstaffed; held at the far stage; wait over 2 game hours; another passenger booked |
| Preview's proposed bridge | 3000 | as a bridge | (previews only) |
| Swim ashore | 4000 | never offered | (a leg of its own) |

**A leg.** The brain walks a crossing in `State.CROSS`, moved by the water: a bridge deck; a swim link with the bank
recheck (decision 0231); the ferry's passenger state machine (`ferry.gd begin_passenger / step_passenger`: wait at the
stage, board, ride, step off; any refusal ends the leg where it stands and the resident plans again by land).

**Boats that are not crossings.** The boathouse's two rowboats are the fishing boats (`boat_routes.gd FISHING_BOATS`).
Their legs are task-driven fixed routes (0432); a rescue rows a straight leg. `route_kinds.gd` reads a crew member
aboard as BOAT ("by boat"), never a router pair (0461). The regatta's race is a task too (0438).

**The routing desk** (1001). A trip over a crossing is planned whole, never cut across frames; with ≤ 8 pairs the
dense graph stays small.

**What the ferry's offer gets wrong.** Its wait is measured from **now**, not from when the walker reaches the stage.
In the demo a game hour is 25 s (750 ticks) and a resident walks about 0.8 m/s, so a 40 m walk to the stage takes about
two game hours: the ferry's whole timetable interval and its 2-hour wait limit. A resident far from the stage is
priced the wait it would have had if it stood there now. It can arrive after the boat has gone (and give up at the
stage, `passenger_refusal`), or be told the wait is too long when the boat will be there as it arrives. The cost is
also worked in float seconds (`ferry.gd offer_cost_m`, `_ticks_of`).

## Phase 1: what a boat crossing row means in the planner

A **boat crossing row** is a crossing row served by a boat on a fixed route between two landings, with a timetable.
Unlike a bridge's, its cost depends on **when** the walker reaches the landing.

- **Rows.** Boat rows are rows `BOAT_ROW0` = 3500 up to 3507 (`MAX_BOAT_ROWS` = 8). The ferry is boat row 0, so
  `FERRY_ROW` keeps its value 3500 and nothing that reads it changes. 3000 (preview) and 4000 (ashore) stay clear.
- **Data, all integer.** Per row: each landing's land end; the ride (deck walks + the row) in calendar ticks; the
  longest wait a passenger accepts, in ticks; and for each landing up to `MAX_BOARDINGS` = 8 upcoming boardings, in
  ticks from now, ascending, each one with a seat free. A closed or unstaffed row lists none and is not offered.
- **Cost: waiting for the boat.** When the planner settles a landing at label `d` (metres at the walker's pace), it
  works out in integers: the arrival tick `ceil(d → ticks at the walker's pace)`; the first boarding at or after it
  (none within the list, or a wait over the row's limit: no crossing); and the far landing's label
  `max(d, boarding as metres) + ride as metres`. The walker's pace is its walk speed (× `CARRY_WALK_FRACTION` loaded),
  as integer mm/s, the same pace the ferry's offer uses today.
- **Why the search stays exact.** A timetable is FIFO: reaching a landing later never boards earlier. So the far label
  never falls as `d` rises, Dijkstra stays correct, and the router's lazy surface costs stay safe. A surface edge's
  lower bound gives an earlier or equal arrival, hence an earlier or equal boarding: still a lower bound.
- **Capacity.** A boarding is listed only with a seat free for this walker (the ferry: one passenger seat; a boarding
  another passenger has booked at that stage is skipped, and the next one is offered). Plans do not reserve seats. A
  seat taken meanwhile is the leg's refusal, as today.
- **Seasons, ice and weather.** The service lists no boardings while closed: the ferry's storm (REQ-SET-052), hard
  freeze (REQ-SET-144), flood and pond ice. A closure that comes after the plan is met at the landing by the leg's own
  refusal (MOVE-REQ-007: a crossing entered is finished; one not yet boarded is given up and planned again by land).
- **Determinism.** Integer ticks and millimetres; rows offered in row order; boardings kept ascending; the router's
  tie rule unchanged. The same plan inputs (calendar tick, walker, standing residents) give the same route.
- **Performance.** A boat row is one of the ≤ 8 pairs a plan already allows; evaluating it scans at most 8 boardings
  with no allocation, and adds no surface plan. The routing desk is unchanged (crossing trips still plan whole).

## Phase 1: what would use it

| Candidate | Use a boat row? | Why |
|---|---|---|
| **The ferry** | **Yes: the first consumer.** | Approved (0437, 0439, group K). Already a router row. Moving it onto a boat row prices its wait from the walker's arrival at the stage and makes its cost integer. No new player text. |
| The boathouse rowboats | No | They are the fishing boats. Brendan's ruling (1711 (a)): fishing boats stay task-driven, no free sailing. |
| The boat rescue | No | A rescue's straight leg is an emergency task (0432), never a planned route. |
| The regatta | No | A race is an occasion's task (0438). |
| River trade (#37) | Later, if Brendan scopes it | Q-D17 is open; its option (b) "river boats carry goods between the village's own landings only" would be a second service on the same rows. Not built. |

## Phase 2 plan (the build)

1. `demo/routes/boat_rows.gd` (new): the boat rows' table, packed integer columns sized once, and the static integer
   arithmetic (ticks for millimetres at a pace and back, the first boarding, the far label).
2. `demo/boats/boat_service.gd` (new): the base a boat row's service extends (`fill_boat_row`, and the leg:
   `begin_passenger`, `step_passenger`, `abandon_passenger`, `passenger_text`).
3. `tunnel_router.gd` (narrow hook): `add_boat_crossing` marks a pair as timed; `_relax_all` prices its partner edge
   from the table at the settled landing's label. Fixed-cost rows are unchanged.
4. `water_crossings.gd` (narrow hook): boat rows are offered from their services in row order; a boat row's leg is its
   service's. The ferry is row 0.
5. `ferry.gd`: extends the service base; `fill_boat_row` lists its boardings (the next one from today's `wait_ticks`,
   then the timetable's departures, the far stage a row later) and its ride in integer ticks. `offer_cost_m` is
   replaced. Its passenger leg is unchanged.
6. Tests: the arithmetic and its boundaries; the router on a fixture service (waits, FIFO, a missed boat, the wait
   limit, a closed row, a seat booked, ties); the ferry's offer from a far start; the existing ferry suite unchanged; a
   perf check (time per plan with boat rows against without, and no allocation in the timed relax).

## Progress

- 2026-10-09: phase 1 scoping written (this record). Phase 2 not started; it waits for the coordinator's go after the
  phase 1 report.

## Source

Decision 1711 (Brendan's ruling, 2026-10-07); 0432 (the boat core), 0437–0439 (the ferry and its authority), 0461 (route
kinds and previews), 0231 (the bank recheck); 1001–1004 (the planner and its perf); GDD REQ-SET-052, REQ-SET-144;
SET-MOVE-001 ("boat transport is a separate mechanism"; MOVE-REQ-007); `docs/handoff/OPEN_QUESTIONS.md` Q-D17;
`docs/handoff/BACKLOG.md` FISHING (Pitfalls), TRADE and PATHS.
