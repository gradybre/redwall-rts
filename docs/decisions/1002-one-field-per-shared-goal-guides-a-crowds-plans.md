# 1002 — One field per shared goal guides a crowd's plans, but only away from the goal
Date: 2026-10-02 · Status: Accepted (its benefit measured small; see Consequences)

Part of Brendan's approved "route planning + bursts": "plan once per shared destination: one shared search per meal,
bed or dawn goal". The scale test's recommendation 2 (decision 0561): "one reverse search per goal (a distance field
over the static graph, refreshed when the obstacles change) serves all of them. Each resident then needs only a short
local plan near its start." Decision 1001 gives the context.

## Decision

1. **A field per goal** (`cast_nav.gd` ONE FIELD PER SHARED GOAL). A goal's field is one search outward from it over
   the static graph, its links and its own pocket, with nobody standing. It is carried in slices like any plan (the
   job's first phase), then kept: per goal and body class's graph, 32 at most, the least lately used dropped first, all
   dropped when the circles change.
2. **A guided plan** is the resident's own search, over its own graph and standing residents, with every link tested as
   usual. The field stands in for the straight line as the estimate of the way left, except within FIELD_NEAR_M = 6 m
   of the goal, where the estimate is the straight line again.
3. **When.** The routing desk guides a job when SHARED_MIN = 3 or more others wait to go to the same spot
   (`route_desk.gd` ONE FIELD PER SHARED GOAL; `wait` now takes the goal).

## Why

- **Not "follow the field from the edge of a local plan".** That was the recommendation's shape. Without standing
  residents a route read off the field walks through anyone standing on it, and every plan to a shared goal is a plan
  into a crowd. A guided search keeps every test a plan makes. Its routes are as clear as any plan's; only its estimate
  is shared.
- **It is not exact.** The field knows the padded graph. A ring at the tight inflation (a standing resident's, the
  start's pocket) can open a shorter way the field does not know, so the estimate can overstate and a guided route can
  be longer than the shortest. The suite bounds it on the village:
  `test_a_guided_plan_is_clear_found_when_a_plan_is_and_nearly_as_short` requires every guided route to be clear, to be
  found exactly when a plain plan is, and to be at most 1.15 times as long.
- **Why not near the goal.** At 100 residents, the first version (the field everywhere) made guided plans dearer than
  plain ones. Guided plans averaged 3.3 ms and 19 expansions; plain plans averaged 1.75 ms and 10. The field ignores the
  crowd round a shared goal, so it led each search into the crowd. The cost per goal was paid again and again, because
  8 slots thrashed between three body classes' goals; 32 slots fixed that.
- **Measured** (both at 100 residents, the same code but this switch, run side by side on the loaded machine). With the
  field used only away from the goal, dusk's bed plans averaged 1.45 ms against 2.23 ms with no field, and dusk's route
  wait p95 was 0.97 s against 1.61 s. Twenty fields were built in the run.

## Consequences

- **The gain is modest, and noisy.** After decision 1001 a plan in this village is already short: 10–30 expansions
  when found, mostly fewer than 10 at 100 residents. Most plans to shared goals fail, because the goal is ringed. The
  shut-in look (decision 1001), not the field, makes those cheap. The kitchen's supper call happened in one run of a
  pair and not the other (the settlement clock runs on real time; decision 0561 §4), so the supper and evening phases
  of the A/B are not comparable. Only dusk is.
- **PROPOSAL (Brendan):** a guided route may be up to 15% longer than the shortest (bounded by the suite on the
  village). Options: (a) keep guidance as it is; (b) switch it off (SHARED_MIN very large), so every route is exactly
  the planner's, at a small cost in dusk's waits; (c) remove it. Recommendation: (a) for the demo, because the bed-time
  wait is the burst a player sees. (b) is a one-constant change if exact routes matter more.
- Dawn is covered by the same rule, though its goals (each resident's parked job) are rarely shared. The measured plan
  ends before dawn.


## Brendan's rulings (2026-10-02)

Brendan approved 1002 as recommended:
- the shared-goal guidance stays, with guided routes up to 15% longer than the shortest (option (a)).

## Source

Brendan's approval of 2026-10-02; decision 0561's recommendation 2; measurements in
`docs/performance/2026-10-02-route-planning.md` (the A/B is listed there).
