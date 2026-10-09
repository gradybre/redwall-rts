# 1821 — Boat crossing rows: the route planner waits for the boat at the time the walker reaches the landing
Date: 2026-10-09 · Status: Accepted (built; P1–P5 ruled by Brendan, 2026-10-09)

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
  as integer mm/s, the same pace the ferry's offer uses today. *(Phase 2 changed three things here, after review: the
  wait limit is checked on the found route rather than in this cost; a boarding also has a ready-by tick; and the pace
  is the brain's own, carry clip included. See "Phase 2: what was built".)*
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

## Phase 2: what was built

The phase 1 design was built with two corrections the independent review found (below): the wait limit is checked on
the found route, not inside the search, and a boarding carries a READY-BY tick as well as its boarding tick.

1. **`demo/routes/boat_rows.gd`** (new). The table: packed columns sized once in `_init` for rows 3500–3507 (landings,
   ride ticks, wait limit, and per landing up to 8 boardings, each a READY-BY tick and a BOARD tick, both strictly
   ascending, ready by ≤ board). The arithmetic, all integer: `ticks_to_cover(distance, speed)` (rounded up, on the
   calendar's own 25 s = 750 ticks hour), `distance_in(ticks, speed)` (rounded down), `first_boarding` (the first one
   the walker is ready by), `far_mm` (that boarding plus the ride, as millimetres at the walker's pace; the limit is not
   applied) and `over_limit`.
2. **`demo/boats/boat_service.gd`** (new). The base a boat row's service extends: `fill_boat_row`, `end_point`, and
   the passenger leg (`begin_passenger`, `step_passenger`, `abandon_passenger`, `passenger_text`). The base serves
   nothing.
3. **`demo/tunnel/tunnel_router.gd`** (narrow hook; this lane owns the router). `add_boat_crossing(row, table, r)`
   marks a pair's two landings as timed. `_relax_all` prices a timed landing's partner edge from its settled label
   (`_relax_boat`, label read in whole millimetres rounded up). Once a route is found with every surface edge on it
   real, `_drop_long_waits` checks each boat leg's wait at its landing's exact label against the limit; an over-limit
   landing's boat is taken out of this plan and the search runs again (at most 2 × 8 extra rounds). One plan takes its
   boat rows from one table (`push_error` otherwise). Fixed-cost crossings (bridges, swim links, the preview's bridge)
   are unchanged.
4. **`demo/waterplay/water_crossings.gd`** (narrow hook). Boat rows are offered from their services in row order after
   the bridges and swim links, while a pair is left; each trip's rows are cleared and refilled, at the walker's own pace
   (`resident_brain.gd base_speed(loaded)`, a new four-line read: the carry clip's pace when loaded, else the walk's).
   A boat row's leg (begin, step, abandon, words, ends) is its service's. The ferry is row 0 (`FERRY_ROW` 3500, as
   before); `add_boat_service` serves rows 1–7. Nothing else serves them yet.
5. **`demo/ferry/ferry.gd`** extends the service base. `offer_cost_m` (float) is replaced by `fill_boat_row`: open
   while `boardable()` (open, staffed, not held), its ride (both decks at 600 mm/s and the row: 332 + 380 = 712 ticks)
   and, at each stage, up to eight boardings (a booked seat skips the next one):
   - **the crossing under way**, only where it will still load (`_underway_board`): at home only while setting out
     (posted for its crew, or loading), at the far stage until it leaves it (posted, loading at home, rowing out by the
     fleet's own progress, or there). Homeward it loads nowhere. Ready by its boarding: it comes whatever.
   - **each scheduled departure**, from the first the boat can take (`_first_departure`: the timetable's own
     `next_departure`, and none before the crossing under way is surely home, `_home_again`), the far stage a row later.
     Ready by the departure from home: `_follow_timetable` posts one only for someone already waiting when it is due,
     and skips one due while a crossing is out.
   - `_home_again` errs late: the crew's walk at twice its straight line, its boarding, the rows still to row, and a
     whole STOP at each stage still to call at (two deck walks of 165 ticks and a full boat's 12 U handled at the
     slowest 80 mWU a tick: 480). Erring late hides a departure (a later boat priced); erring early would list one that
     never runs.
   `wait_ticks` (what a waiting passenger is told, `passenger_refusal`) reads the same two sources, so the router and the
   stage agree. The crew's walk and the row are integer ticks now (`_ticks_of` is gone; `MIN_WALK_MM_S` 100 is the old
   0.1 m/s floor); the row and the ride are worked out once.
6. **No player-facing text** changed except the README's developer notes. A generic boat row reads "by boat" through
   `route_kinds.gd`'s existing fallback; the ferry still reads "by ferry". No key, no panel, no "U" amount.

## The ferry's fix (a fix inside an approved feature)

Recorded as the coordinator asked (2026-10-09: "Pricing its wait from the walker's arrival is a fix inside an approved
feature"). Before 1821 the ferry's offer counted the wait for its next boarding **from the moment of planning**, at the
stage nearer the start. A walker 40 m from the stage at 0.8 m/s gets there two game hours later: the boat priced may
have gone, so it walked to the stage only to give up and go round (`passenger_refusal`), or it was told a wait was too
long that would be over by the time it arrived. Now the wait is priced from when the walker reaches each stage, and only
for a boat that will be there. Two smaller fixes came with it:
- **Rowing home, the ferry boards nobody at home** (`wait_ticks`): at home a crossing loads only setting out. A
  passenger waiting at home while the boat rowed back was told "the row" and then found the crossing ended; it now
  waits for the next departure (or gives up after 2 hours, as before).
- **A departure due while a crossing is out is not promised.** The timetable skips it (`_follow_timetable`, unchanged);
  `wait_ticks` used to count it.
- **A far-stage passenger who arrives after the boat has left home** is no longer offered that boat (the READY-BY tick).

Brendan approved the ferry (0437, 0439, group K); its timetable, seat, closures and leg are unchanged.

## The independent review (code-reviewer)

The first review (on ef41427c) found three HIGH, six MEDIUM and several LOW. All HIGH and MEDIUM are fixed (735e3a49,
6eb99f16):
- **HIGH 1: the wait limit broke FIFO.** With the limit inside `far_mm`, an earlier arrival could be refused where a
  later one is accepted, so a boat judged at a straight-line bound was refused for good. Reproduced: by land at 21.4 m
  instead of by boat at 15.9 m. Fixed as above (limit on the found route). Regression test with the review's geometry;
  it fails with the limit put back inside `far_mm`.
- **HIGH 2: far-stage boardings for departures never posted.** Fixed by READY-BY.
- **HIGH 3: the walker's pace reached the table in no test.** Now tested on the fixture boat and through the real
  ferry rig; the pace is the brain's real one (`base_speed`), not `walk × 0.65`.
- **MEDIUM:** a phantom home boarding while rowing home (fixed, tested); a FIFO test that could not reach the limit
  (rewritten, limit tested apart); the pace not the real carry pace (fixed); the offer doing more work than needed
  (`boardable()` once a fill; row and ride ticks worked out once); a stale row could be offered (tested); a test over
  30 lines (split).
- **LOW** fixed: the redundant `turn_back` guard, the dead `maxi` and open checks, the unpinned floor constant and
  label rounding, a lopsided perf test, `_boats` released and checked, `_boat` filled with -1, the services' column
  sized in `_init`. Not changed: only the ferry has a "waiting" reason on the Routes layer (`route_reasons.gd`; a seam
  for a later service), and `_booked` counting a passenger already aboard as booking its stage (unchanged since 0437).

The second look (on 6eb99f16) confirmed HIGH 1 and HIGH 3 fixed and found HIGH 2 fixed only for an idle ferry: with a
crossing under way, the first listed boarding could be a departure the timetable skips, or no departure at all
(reproduced: a far-stage walker refused after the router planned a boarding; phantom boardings while rowing home). Fixed
in 52a6978b by separating the crossing under way from the scheduled departures (above), with both reproductions as
tests. The third look (on 6ea49148) found `_home_again` an early estimate (it left out the calls at each stage), so a
departure due during them was still listed (reproduced: the +900 case). Fixed in f1bda8b4 by making it a late one, with
the case as a test and a table test of every state. **The final look (on f46472ba): no CRITICAL, no HIGH.** It checked
each state's bound against the code (the tightest, loading at home, about 875 ticks against 960).

Its one MEDIUM, answered here: before the crew is on the deck (X_WAITING) the crossing can be delayed without bound --
the crew called away and the job claimed again, standing down while a rescue has the boat, no crew claiming it yet. A
departure listed after `_home_again` can then still be skipped; the passenger waits for the next one or goes by land
from the stage, which is the ferry's behaviour before 1821 too. The robust fix changes the ferry's timetable, so it is
proposed (P5), not built. Its LOW (both stages' decks reckoned at the ferry stage's, under a tick apart) is within the
stop's slack.

## Gates

Run on the branch at 667ec829 (the code as merged; later commits add tests only, run focused) unless said.

- **Full suite, CI-style**, in a fresh art-free worktree (`git worktree add` at 667ec829, no `godot/demo/assets`,
  `.godot` deleted, `godot --headless --path godot --editor --quit`), four shards in parallel:
  - shard 0: `2701 test(s), 263669 assertion(s), 0 failure(s)`
  - shard 1: `2757 test(s), 449511 assertion(s), 0 failure(s)`
  - shard 2: `3508 test(s), 341525 assertion(s), 0 failure(s)`
  - shard 3: `3170 test(s), 185287 assertion(s), 0 failure(s)`
  - every shard: `diagnostics: 0 unexpected error(s), 0 unexpected warning(s) ... leaked at exit: 0 object(s), 0
    resource(s)` and `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
  - `ci_test_shards.py verify --count 4`: `ok: 478 suite files executed exactly once across 4 shards`; 12136 tests,
    0 failures, 0 unexpected errors or warnings, 0 leaks.
  - At the final HEAD (49d4597d), in the same worktree: `test_demo_ferry.gd` + `test_demo_boat_rows.gd`, `63 test(s),
    694 assertion(s), 0 failure(s)`, clean diagnostics and log.
- **Analyzer:** `python3 tools/gdscript_warnings.py --max 0 --port 6327`: `0 GDScript warning(s) in 0 of 1476 file(s)`.
- **Contracts:** every check in CI's contracts group passed (decision_numbers, ready07_arithmetic, the memory budget,
  merge_gate, setting_contract, dispatch_plan, astra_inbox, the save registry and canonical state table, the cycle
  handoffs, registry capacities, component and auxiliary schemas, lane_notes, the movement checks,
  state_registry_coverage and the tool self-tests). `decision_numbers: PASS -- 538 records, 0 problem(s)`.
- **Mutation testing** (one mutant per run on a copy, restored and sha256-checked; failures read from the runner's
  summary line): **101 mutants on the final logic, 98 killed, 3 survivors, each equivalent**:
  - `tunnel_router.gd _relax_boat`'s NONE guard removed: a boat with no boarding from the arrival gets a label for one
    round, and `_drop_long_waits` (no boarding reads as over the limit) takes it out; the same route, one round later.
  - `ferry.gd ride_ticks` and `_row_ticks`' caches bypassed: the miss path gives the same value.
  Earlier passes (on earlier code) left more survivors; each was closed by a test (a later ready-by with the same boarding, a
  negative row, a reused router's marks and table, the pair cap, held/closed/nobody's rows, the far stage's wait, a
  booked seat on the crossing under way, the timetable's own next departure). **SURVIVED_MUTANTS: none** (three
  equivalent, explained above).
- **Live harness, routes** (`demo_routes_live.gd`, staged art): `LIVE-SUMMARY 35 0` at 1280x720 and at 1920x1080, on
  the final HEAD. The frames captured on 13a6d8b2 (`scratchpad/boat_check/`, the public ways, a group's routes and the
  water site at both sizes) were looked at: nothing is drawn differently; the legend still reads "by boat" and "by
  ferry". This lane adds nothing visible.
- **Perf, the scale harness** (`tools/scale_test/scale_test.gd --fixed-fps 60 --residents 25 --plan short`, art-free,
  on a loaded machine, load 6–8): base 0727350a at 1920x1080 against the branch at 1920x1080 and 1280x720. No errors, no
  fallbacks. Frame p95, ms (base / branch 1080 / branch 720): 1x breakfast 6.4 / 6.7 / 5.3; the order 7.0 / 7.5 / 6.2;
  4x day 7.7 / 8.1 / 6.5. Engine-only time moved by the same few percent, so the difference is the machine. The routing
  desk's largest window: 4.1 / 3.7 / 3.9 ms; carried jobs 9 / 7 / 5. No trip in this plan crossed the water, as in
  decision 1001's scale test. Crossing trips still plan whole (1001), so their cost is bounded by
  `test_a_boat_row_costs_a_plan_no_more_than_a_fixed_crossing_and_creates_no_object` (a boat row within 1.3 times a
  fixed crossing over the same landings, and no Object created in 50 plans).

## PROPOSALS (Brendan's ruling needed)

- **P1. What else may use boat rows.** Built and tested with the ferry as the only user. Options: (a) leave rows 1–7
  unused until something needs them (as built); (b) when river trade is scoped (Q-D17 (b)), its boats become services
  on these rows, carrying passengers between the village's own landings on a timetable, with no cargo economy (LORE-T05);
  (c) never use them for anything but the ferry. **Recommendation: (a)**, and (b) only once Brendan scopes trade.
- **P2. The fishing boats stay out.** As ruled in 1711 (a), the two rowboats are never crossing rows. Options: (a) keep
  it so (as built); (b) let a resident borrow a moored rowboat to cross when no fishing trip needs it (free sailing, which
  1711 rules out). **Recommendation: (a).**
- **P3. No margin at the landing.** A walker priced to arrive exactly at the boarding tick is offered it; a slow step on
  the way makes it miss the boat and plan again by land (the leg's refusal). Options: (a) no margin (as built); (b) a
  margin of a few ticks (for example 30, one demo second). **Recommendation: (a)**: the refusal is cheap and the pace is
  the brain's own.
- **P5. The ferry could keep a departure it had to skip.** Today a departure due while a crossing is still out is
  skipped (`_follow_timetable`, 0437), so the planner hides it, and a crew delayed before boarding can still make a
  listed one late. Options: (a) as built (skipped; the planner errs late); (b) keep a skipped departure pending and post
  it when the boat is home if someone waits, so a listed departure is at worst a late boat, never a missing one -- a
  change to the ferry's timetable. **Recommendation: (a)** now; (b) if playtests show passengers turned away at the
  stage.
- **P4. Q-D17 (river trade) is not asked now.** The capability does not need a ruling. Options: (a) keep holding it, as
  Q-D17 recommends; (b) ask Brendan now, with its option (b) as the shape. **Recommendation: (a).**

## Progress

- 2026-10-09: phase 1 scoping written (9dee8b28). The coordinator approved phase 2 with the ferry as row 0.
- 2026-10-09: phase 2 built (13a6d8b2, ef41427c); reviewed four times; fixes 735e3a49, 6eb99f16, 52a6978b, f1bda8b4,
  f46472ba; tests from mutation testing 11cbf947, 6ea49148, 667ec829, 49d4597d. All gates passed (above). Done; not
  pushed (the coordinator pushes).

## Brendan's rulings (2026-10-09)

Relayed by the coordinator on PR #242 (no verbatim wording was passed on): Brendan **approved all five proposals, P1–P5,
as recommended**:
- **P1 (a):** boat rows 1–7 stay unused until something needs them; river trade's boats may become services on them only
  once trade is scoped.
- **P2 (a):** the fishing boats stay task-driven and are never crossing rows (as 1711 (a)).
- **P3 (a):** no margin at the landing; a missed boat is the leg's refusal and a plan by land.
- **P4 (a):** Q-D17 (river trade) keeps being held; it is not asked now.
- **P5 (a):** the ferry keeps skipping a departure due while a crossing is out, and the planner errs late; keeping it
  pending stays an option if playtests show passengers turned away at the stage.

The ferry's fix (pricing the wait from the walker's arrival, "a fix inside an approved feature") stands as built.

## Source

Decision 1711 (Brendan's ruling, 2026-10-07); 0432 (the boat core), 0437–0439 (the ferry and its authority), 0461 (route
kinds and previews), 0231 (the bank recheck); 1001–1004 (the planner and its perf); GDD REQ-SET-052, REQ-SET-144;
SET-MOVE-001 ("boat transport is a separate mechanism"; MOVE-REQ-007); `docs/handoff/OPEN_QUESTIONS.md` Q-D17;
`docs/handoff/BACKLOG.md` FISHING (Pitfalls), TRADE and PATHS.
