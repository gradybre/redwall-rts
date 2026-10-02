# 1001 — One route plan is local and divisible, and the routing desk carries it across frames
Date: 2026-10-02 · Status: Accepted

Numbered 1001: decisions 0995–0999 were being taken by the review-fix lane at the same time, and nothing on any branch
used 1001–1009. `docs/validation/decision_numbers.py` accepts the four digits (`^\d{4}-`).

Brendan approved this work after the scale test (decision 0561; `docs/performance/2026-10-01-scale-test.md`) as
"route planning + bursts" and "smaller fixes". It answers the scale test's hot spot 1 and the 2026-10-02 review's R07:
"the route budget cannot bound one expensive plan". The before-and-after measurements are in
[`docs/performance/2026-10-02-route-planning.md`](../performance/2026-10-02-route-planning.md).

## Decision

1. **A plan is local** (`demo/cast/cast_nav.gd`, LOCAL, NOT EVERYONE):
   - its standing residents are bucketed in a grid when it begins;
   - a standing resident is ringed only when the search first expands a node its ring could link to, so only residents
     in the route's corridor are ever ringed;
   - a static node's edges are tested only against the standing residents within an edge's length of it, found once
     per expansion; any other link is tested by a grid look along it;
   - the plan's own nodes (start, goal, rings) sit in a hashed grid, so an expansion links to the nodes in the 3 x 3
     cells round it, not to all of them;
   - a ring node inside another standing resident's circle (as this plan tests links against it) is not added: every
     link to it would be refused;
   - the obstacle circles are kept a second time, each in every cell it overlaps (`cast_grid.gd` DISKS), for the
     yes-or-no tests. A look no longer pads by the widest circle in the village (7.3 m, sixty-odd cells a look).
2. **A goal shut in is found from its side** (A GOAL SHUT IN). When the goal lies within a circle's reach, or two or
   more residents stand within 1.5 m of it, the plan first marks every node with a link into the goal, then into those,
   for at most 48 expansions. If it runs out of nodes without reaching the start, there is no route. That is the answer
   the full search gave after reading the whole graph.
3. **A plan is divisible** (DIVISIBLE): `begin_plan`, `step_plan(n)` (at most n expansions) and `finish_plan`. `plan`
   runs the three at once, so every other caller is unchanged.
4. **The routing desk carries one plan across frames** (`route_desk.gd` THE JOB). Under a budget, a resident's trip on
   the surface alone is planned by the desk's own planner (`worker`, a second CastNav sharing the space's circles and
   graphs through `share_world`), one expansion at a time, while the window lasts. A plan the window cannot finish is the
   job:
   - its resident stands in ROUTE, "finding a route";
   - the next windows carry the job on first;
   - when it is done, the resident's turn picks the finished route up.

   - If the job's resident is given another goal meanwhile, its job is dropped and it waits its turn like anyone
     (`wait`). Without this, the review found a resident left in ROUTE with no job and no place in the queue.
   - The desk's planner follows its owner's world (`world_revision`, `_follow_world`): a `setup` of the owner's
     rebuilds the shared grids in place, and the worker must never read them against its old circles.
   - A field is used only on the graph it was searched on.

   Only one job runs at a time. While it runs, nobody else starts a plan: the desk cannot tell, before a plan is made,
   whether it could cut it. A trip through a tunnel or
   over a crossing, a goal underground, a formation's search and the planners outside the cast (rescue, ferry, route
   previews) still plan whole, as before. With no budget (the suites), every plan is whole and nothing changes.
5. **The brain waits for a carried plan** (`resident_brain.gd` ROUTING):
   - `_plan_trip` says whether the plan is done;
   - an order, a task's walk or a replan waits in ROUTE, as it already did for a spent window;
   - a wanderer's own departure keeps the spot and slot it picked (`_route_poi`) and goes there when its plan is done.
     If that slot was taken meanwhile, it idles a moment and picks again;
   - a loaded re-plan (HAULING) is never cut.
6. **The scale harness** counts a resident whose plan is the job as waiting, and reports the desk's counts (`desk`:
   served, windows that ended with a job under way, slices, fields, the largest window).

## Why

- **The same routes.** The planner as it was is kept as `test/fixtures/reference_cast_nav.gd`.
  `test_demo_route_planning.gd` plans the real village both ways and compares the waypoints exactly:
  - the village's world, water, woods and weir circles;
  - three body sizes;
  - crowds of 0, 12, 40 and 100 standing residents;
  - 144 trips from a fixed seed.

  This holds by construction:
  - every node an expanded node could link to exists before it links;
  - every edge test gives the answer the full scan gave;
  - pruned ring nodes could never be relaxed;
  - the shut-in look tests each link exactly as the search would test it from its own side.

  Only the order in which candidates of exactly equal cost enter the heap may differ. The 30 slowest plans of a live
  50-resident run, replayed both ways, also give the same routes.
- **Why lazy rings, not a corridor box.** A fixed box round the start-to-goal line would miss a detour and change
  routes. Ringing on first reach rings exactly the residents the search can use.
- **Why the desk owns the job.** The desk already decided when plans start (decision 0361). Cutting a plan needs a
  planner whose scratch nothing else touches between frames, and a resident who knows to wait. ROUTE already meant
  that.
- **Why one expansion a slice.** In a crowd one expansion can cost a millisecond or two: dozens of ring nodes in reach,
  each link tested. With 16 a slice, the largest window of a 50-resident run was 14 ms. With 4, it was 7 ms at 100.
  With 1, it was 5.2 ms at 100, against the 3.5 ms budget. A look at the clock costs far less than an expansion.
- **Rejected:** a time check inside the search (makes the unit nondeterministic in tests); a corridor box (changes
  routes); bidirectional search everywhere (the shut-in look costs a found plan nothing unless its goal is crowded or
  tucked in).

## Consequences

- A window spends at most its budget and one expansion. It never spends one whole plan, however the village grows.
- A plan carried over keeps the standing residents it began with. Someone who stops in its way meanwhile is met on
  the walk, which re-plans as it always has.
- A wanderer may now stand "finding a route" before leaving its spot, as an ordered resident already did. **PROPOSAL
  (presentation)**: the party panel says so for wanderers too. Options: (a) keep it; (b) show a wanderer waiting for
  its plan as idle. Recommendation (a): it is the truth, and it is brief (median wait under 40 ms of virtual time at
  25 and 50 residents).
- Trips through tunnels or over crossings are still planned whole. None was taken in the scale test's day (no tunnels;
  `offers_for` offered no crossing to any surface trip measured), so their cost at scale is unmeasured.
- Most plans at 50 and 100 residents still go to goals no route reaches: the supper table ringed by diners, a seat
  among them, a spot tucked among trees. They now fail in a few milliseconds instead of reading the graph, but they
  are retried. That is the kitchen's and the night's capacity, the scale test's "Limits that are not CPU", and is left
  to those design calls.

## Mutation testing (decisions 1001–1004)

51 single-line mutants, one per run, on a copy of the branch, each restored and sha256-checked. The failure count was
read as an integer from the runner's summary line. They covered:
- the planner: ring reach, near lists, prefilters, the plan's own grid, pruning, the shut-in look's reaches and
  exhaustion, step budget, the field's estimate and slots, world sharing, the request copy, the disk grid;
- the desk: may_plan, the job's drop and its matching, served counts, the standing a carried plan takes;
- the cells: pads, sorting, unlinking, the step's drift hand-back;
- the brain's carried departure, the kitchen's and dusk's counts, the hall's rank, the people's pairs, and the board's
  skip and first promiser.

**47 killed.** One of them was killed by a timeout: a corrupt bucket list loops. Four survive:
- **The "no route" branch of `finish_plan` removed.** This is equivalent: with no route, `_emit_route` walks back from
  a goal that has no parent and writes the goal alone, which is the straight-line fallback.
- **The two fixes for the review's C1, each removed alone.** `wait` dropping a job whose resident now goes elsewhere,
  and `_serve_job` keeping a job its owner's turn has just begun, each prevent the stranded resident on their own.
  `test_a_job_whose_resident_is_sent_elsewhere_meanwhile_is_dropped_and_the_new_trip_planned` fails only with both
  removed. Both are kept: the first also spares the desk windows on a request nobody wants.
- **`constrain`'s fall-back to everyone when a step strays past its span, removed.** It cannot be reached with
  STEP_PUSH_SPAN 8 and real strides. The hand-back it relies on (`_pushed` giving INF) is tested directly.

The first pass left twelve survivors. Eight were closed by new tests:
- the near list's reach;
- the shut-in look's reaches, start and exhaustion, and a stepped look;
- a step of none;
- the field's estimate and its graph;
- the request copy while a field is searched;
- the world followed unasked;
- a job's matching;
- the carried plan's standing.

## Source

Brendan's approval of 2026-10-02; the scale test (decision 0561) and its hot spot 1; the review's R07; decision 0361
(the routing desk) and 0196 (the planner). Measurements: `docs/performance/2026-10-02-route-planning.md`.
