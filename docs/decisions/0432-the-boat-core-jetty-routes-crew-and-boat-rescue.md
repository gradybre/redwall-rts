# 0432 — The boat core: a jetty outside the boathouse, fixed routes, crews, and a boat as a rescue rank
Date: 2026-10-01 · Status: Accepted

Water part B (0431), its reusable boat core -- written for the ferry and regatta lane that builds on it. Numbered in
this lane's 0431–0439 range.

## Decision

### 1. A jetty outside the boathouse

The boathouse's own landing lies inside its footprint, where nobody can stand (decision 0196, part A's notes). The boats
are worked from a JETTY on the pond's west bank, 1.3 m south of the boathouse's front, outside its footprint
(`boats/boat_routes.gd`): its LAND end (19.7, 28.9) on the bank top, a point the ordinary planner reaches; its deck
running east over the water to its END (23.0, 28.9), 0.04 m above the datum (the staged jetty model's measured deck,
re-placed there by `water_dressing.gd`). The boathouse KEEPS two rowboats (§5.9: "2 stored boats"), each at its own
berth beside the jetty. Boarding and landing walk the deck straight, at its height (presentation): the planner never
routes over water through it.

### 2. Boats are integer rows moved as presentation

`boats/boat_fleet.gd` is structure-of-arrays, a row a boat: phase (MOORED, OUT, ON_STATION, BACK), course (a validated
water polyline from its berth, u), progress along it in whole u (the frame's remainder carried in micro-u), crew (two
seats, the helm first), owner (a trip's or a rescue's serial), durability (§5.4's installed boat gear, 1000, worn 15 a
cycle; none sets out below its wear) and cargo (for the view). Speed is 0.8 m/s (DEMO) on the demo clock. No physics
body, no node per boat: `boats/boat_view.gd` draws every row as the staged rowboat, bobbing on demo time.

### 3. Fixed routes only -- task-driven legs, not router crossings

A fishing boat rows only a FIXED ROUTE (Brendan's ruling for fishing: no free sailing): berth -> a turn -> a fishing
station on the pond, and back the same way (`ROUTES`, checked by `validate`: every leg sampled every 0.25 m is water at
least 0.3 m deep, the jetty's land end dry). **Boat legs are TASK-DRIVEN, not router crossing pairs**: a fishing trip
starts and ends at the same jetty and carries no traveller from bank to bank, so offering it to the router
(`crossing_hook.gd`) would only add a leg no walk wants. The crew walk to the jetty by the planner, board, and the
trip's own steps drive the boat (`fishery.gd` S_JETTY / S_BOARD / S_AFLOAT / S_ALIGHT). A FERRY is the case for router
pairs -- a route from one jetty to another as a crossing row, like a bridge -- and is the next lane's.

### 4. Crew, the jetty recheck and the hold on the water

A boat trip has two seats (§5.4: "2/2"): the HELM (FISH >= 1) and a second (anyone; a learner learns). Both wait at their
own spot by the jetty (four spots, two a boat); with both there the helm RECHECKS standing on the jetty
(`entry_refusal`, decision 0231's bank recheck): a storm (REQ-SET-052: "prevent departure and preserve its queued
order"), a hard freeze (REQ-SET-144), ice on the pond, the species closed, the quota taken, the boat worn below a cycle.
Refused, nobody boards, nothing is taken, the crew stand down for other work and the trip waits on the board saying why
(re-checked every 5 s). From the first plank to the land end again a crew member is HELD on the water (`water_hold`):
the night, the board and the kitchen leave it be and no order takes it off the boat mid-pond (MOVE-REQ-007); a trip
called off afloat rows home first.

### 5. A boat is a rescue rank (decision 0231's note for part B)

`rescue_tasks.gd RESPONSE_BOAT` = 5, reserved and released through `VictimTask.reserve` / `release` like every
rescuer, ranked by `rescue.gd nearest_capable_into` with `NEED_BOAT` (anyone on land free to go who may take a helm;
the cost the walk to the jetty plus the row out at ROW_WEIGHT 1.2 a metre). A victim at the SURFACE of water a free boat
can reach in one straight leg (the pond) is answered by the boat when its way is shorter than the nearest swimmer's,
or no swimmer is free (in place of a line); a victim held BELOW needs a diver, so a diver still takes over. The crew
rows straight out (a rescue is not fishing), hauls the victim aboard (`towed`: in hand, nobody relieves it now), rows
back and lands it at the jetty (`rescue.gd ashore`: REQ-SET-054's landing). A boat that gives up -- the victim drifted
off its straight leg, or no course could be set -- RELEASES the victim at once (`VictimTask.release`) and rows home
empty, so the victim is free for the next rescuer rather than left reserved by a boat that is not coming. Its numeric value is above DIVE so that
`answered` counts it for a surface victim while a below victim still needs `== RESPONSE_DIVE`. The feed says each
dispatch once (`dispatch_line`), never per tick.

### 6. Numbers (DEMO)

Jetty land (19.7, 28.9), end (23.0, 28.9), deck 0.04 m; berths (22.6, 30.65) and (24.8, 28.9); routes to "the pond's
middle" (27.6, 30.4) and "the south reach" (27.4, 33.2); draft 0.3 m; sampling 0.25 m; speed 0.8 m/s; seats 0.75 m aft
and 0.55 m forward of the hull's centre; the deck walked at 0.6 m/s; a rescue's row weight 1.2; the coracle moved to
(32.2, 24.4), off the routes.

## For the ferry and regatta lane

- Add jetties and routes in `boat_routes.gd`'s shapes (`BERTH_U`, `BERTH_STEP_U`, a route from a berth) and run
  `validate`; a course is set with `boat_fleet.gd set_course` (any validated water polyline from a berth) and rowed with
  `set_off` / `row_back`; `step(usec)` returns which boats arrived.
- A ferry offered to the planner is a crossing row in `water_crossings.gd` (bridges are rows 0..3, swim links from
  `LINK_ROW0`): give it its own row range and leg code, its cost the walk to the jetty plus the row; walk it with the
  same deck walk and seat placement (`fishery.gd _deck_walk`, `_afloat_frame`).
- A boat is owned while out (`take`/`give_back` by serial); crew sit in `seat`; `water_hold` is what keeps a rider
  aboard; `boat_rescue.gd` takes only free boats, so a ferry should give its boat back between crossings.
- A catch the driver refuses when the work is done (the cycle no longer open) brings a fishing trip home
  (`fishery.gd _catch_refused`) -- a boat never rows straight back out on a refused catch; a ferry's own legs should
  likewise end on any refusal rather than retry in place.
- `rescue.gd boats` is typed `boat_rescue.gd`; its row cost is computed once per victim per ranking.
- The fleet has two rows (`BERTH_COUNT`); a third boat is a third berth and route.

## Consequences

- Nothing may route walkers over the jetty's deck; it is walked only by a boat's own steps.
- `RESPONSE_*` values are compared numerically (`answered`, `_look_after`): a new rank must keep BOAT >= WATCH and
  DIVE the only answer for a victim held below.


## At the batch 5 integration (2026-10-01)

- **Routes** (0461): `route_kinds.gd` reads a crew member's boat as a BOAT leg ("by boat"), from the fleet rows, never
  as a router crossing.
- **The rescue card** (0461) shows a boat rescue's phase, the jetty as its landing and a time from ROW_SPEED_U_S.
- **Names** (0491): the boat rescue's assistance is logged through `ashore`, so the helm's deed is recorded by name.

## Source

GDD §5.4 (boat: 2/2, 120 party-WU, base 36, wear 15, injury 20; REQ-SET-052/054), §5.9 (Boathouse: 2 stored boats),
§5.10 (REQ-SET-144); SET-MOVE-001 MOVE-REQ-001/007; decision 0231's note for water part B; Brendan's ruling: fixed routes
only for fishing.
