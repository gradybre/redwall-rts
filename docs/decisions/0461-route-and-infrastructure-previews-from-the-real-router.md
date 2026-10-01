# 0461 — Route and infrastructure previews from the real router, worked through the routing desk
Date: 2026-10-01 · Status: Accepted

Review group P of the live-demo review (`redwall-review/REVIEW.md`): packet **P5** (bridges, tunnels and water safety
as understandable infrastructure; P1's tunnel, bridge and water-safety rows; the bridge wireframe), **ECO-039** (public
routes and specialist shortcuts) and **ECO-045** (useful stages in a larger dig). Built on feat/demo-day-length c228d90
(the routing desk, 0361; the second level, 0212; H's cards, 0332; I's incidents, 0331; J's layers, 0292; M's work
board, 0411; F's panels, 0391; C's rescue, 0231; the ten-minute day, 0421). Presentation only: nothing here is the
simulation's. MOVE-G01–G05 stay open, and every estimate says so.

Number: the first free in the 0461–0469 range given to this group (0441 and 0442 are water B2's; nothing above 0442
is in use on any branch or worktree).

## Decision

1. **An estimate is the real router's answer, on copies** (`demo/routes/route_estimator.gd`). A trip is planned exactly
   as `cast_space.gd plan_path` plans a resident's own — tunnels when one is open and the walker fits it with its load,
   the water's crossings only when it offers some — through the same `tunnel_router.gd`, `graph_paths.gd` and
   `cast_nav.gd`, and its cost is the router's own figure for the route it found (`tunnel_router.gd last_cost_m`, the
   one read added to the router; nothing of its search changed). "Before" is planned on the LIVE network with the live
   crossings — a resident's own plan, sharing the router's warm cache under the same keys (it adds only what that plan
   would add, drops nothing, changes no state). "After" is planned on a COPY of the network with the proposal in it: a
   dig's segments taken as open, a Dig-tool plan laid on the copy and taken as open, or a bridge offered as an open
   bridge is offered (`preview_crossings.gd`: the live water's offer plus one pair, between the approaches a planned row
   would have, at its walk × the weather's scale). The copy has its own router and paths, so a proposal never reaches
   or throws away the live cache or Dijkstra tables. Two inputs differ from a resident's plan and are said on screen:
   nobody standing about, and the trip from one work place to another.
2. **One footing for "before" and "after".** A trip the water offers nothing is planned live without the water's hook,
   so the router prices no wading on it — and the live route wades the ford. The estimate keeps that route and prices
   its wading exactly as the router does with the hook (`unpriced_wading_m`), so adding a crossing can never read as a
   longer trip. Found by the probe: the store-to-ford trip read 26.6 m "before" and 31.9 m "after" over the same route.
3. **Never synchronously in a burst.** `step(desk)` does one piece — the copy, or one trip's one plan — only when no
   resident waits at the desk and its window can take a plan, and charges its time to the window (`charge(-1, ...)`).
   A plan cannot be cut in two (0361), so after a step longer than the desk's budget the estimate RESTS that many
   windows: its average stays within the budget however long one plan is.
   The controller (`demo_routes.gd`) steps ONE estimate a frame across all of them, and only those on screen (the Water
   panel's, the Tunnels panel's, the Routes layer's with nobody selected). A whole estimate is 1 + 2 × trips steps; the
   panels say "calculating…" until it is done. Stale (the network's revision, the water's crossings or the weather
   moved): it is worked again from new copies.
4. **Bridges as projects** (`bridge_project.gd`, the Water panel). A Build button shows only when its action card
   allows it — "Build appears only when it can commit"; a kind the stores cannot pay for is said ("Plank footbridge:
   missing 4.7 U planks", from the card's own have / need) with a SOURCE button: the saw task on the Work screen when one
   is queued, else the Woods panel where Saw planks is (a log: the woods) — it orders nothing. A planned bridge (paid all
   or nothing when planned) says its materials are reserved at their source, being carried or delivered at the site,
   nothing missing, its stages and its builder, with its task on the Work screen; an open bridge says its route across,
   its condition and the route a work trip takes now — no construction controls.
5. **The benefit** is estimated for up to three work trips that could use the proposal (`work_trips.gd`: for a bridge
   the trips whose straight line meets the water — only those are offered crossings at all — nearest it; for a tunnel
   one end to the other and the trips that might save by it), timed at the walker's pace (a carrier at
   CARRY_WALK_FRACTION of its walk), on the demo calendar, with who can use it (a deck: anyone, carrying or not; a bore:
   by width and height, how many here fit, and for a group each member's own verdict) and its cost from the Build card.
6. **The Routes layer** ("Getting there: Routes", `route_overlay.gd`): the selected residents' own routes, stretch by
   stretch (`route_kinds.gd`, from the routes' leg codes: surface, wading, underground with its level, bridge, swimming,
   the proposed bridge), with each hold-up's words at a post where it applies (`route_reasons.gd`, each from its real
   cause: the desk's wait, a mouth's line, `resident_brain.gd is_stranded` — the one read added to the brain — a
   closure ahead, a fit that fails with the load now carried, a trip given up). A group is drawn and described member by
   member. With nobody selected: each work district's public way from the square for the public walker (the widest
   body, carrying — so never swimming); beside it a narrow body's tunnel shortcut where its route goes below and the
   public way does not, marked optional; and the swim links themselves, drawn as optional crossings for swimmers. The
   legend says public ways never swim.
7. **A dig's stages** (`dig_stages.gd`, ECO-045): junctions where the piece meets another piece's dug bore, then its
   end — a connection (a mouth, or the network) or a spur (a room, a blind end). A stage is reached when every segment to
   it is open; open segments past the last stage are a dead-end heading, said so; the next payoff names what it opens,
   how far the dig to it is, and its benefit (the piece open to that stage only).
8. **The rescue card** (`rescue_card.gd`, through `demo_incident_cards.gd add_details`): the existing per-victim
   incident gains the phase, an approximate time to safety (walk, swim, fetch and tow at the rescuer's speeds; the flow
   left out and said so) or the blockage (nobody answering and when the water brings it ashore; a line that will not
   reach; a swimmer treading above one it cannot fetch), and Victim ▸ / Responder ▸ / Landing ▸ that select and centre.
   Read on real time, so it is the same while paused.

## Why

- The review's acceptance: "a group comparison cannot claim a route fits because only its lead fits", "built travel
  benefits are observable in a repeatable haul fixture", "navigation profiling verifies no synchronous burst". A formula
  beside the router would drift from it; copies make "after" exactly what the live router does once the thing is built
  — the suite builds it and checks the very figure.
- Copies rather than a router swap or a shared cache: the live router's cache is keyed by one revision per body; a
  preview's different crossings would throw it away on every alternate plan. A copy is ~70 small packed columns.
- Rejected: estimating every member of a group (members × trips × 2 plans); the group is answered member by member for
  fit, which is what decides whether each can use the thing, and the trips are planned for one walker, named.
- Rejected: showing a disabled Build with its refusal in the tooltip (0332's way). The review asks for the shortage and
  the action that fixes it in view, and Build only when it can commit.
- Swim shortcuts are the links, not a swimmer's whole trip: a plan offered three swim links costs 13–15 surface plans
  (measured 13–40 ms on the Mac, the same as a resident's own plan of that trip); estimating eight of them for a map
  layer would be a spike every time it is opened. The links are the shortcut; the public way is what is timed.
- The neck bridge's benefit from inside the village is small (≈14% for the hall to the mill's bank): the village's
  east gate is by the ford, so a trip from the hall walks out there anyway. The estimate says so rather than flattering
  the bridge.

## Consequences

- `tunnel_router.gd last_cost_m` and `resident_brain.gd is_stranded` are reads; any change to how the router settles
  its goal must keep `last_cost_m` its cost. A new crossing row kind (water B1's boats) reads "by water" in the overlay
  until `route_kinds.gd` is told its rows.
- `underground_graph.gd` columns are copied by reflection (every script variable but objects); a new helper OBJECT the
  graph writes while planning or laying a piece must be added to the estimator's SHARED list or given its own copy.
- The Water panel's Build buttons are hidden when they cannot commit; the layout harness checks shown actions and that
  each Build is shown exactly when its card allows it.
- Estimates are walking time only — no turns, queues or anyone in the way; the haul fixture measures 10% over the
  estimate before and 5% after the bridge.
- An estimate's longest step is one plan, and costs what a resident's own plan of that trip costs (measured on the
  water rig, the neck bridge open, the widest body carrying: 0.1–1.7 ms to the village's places, 13 ms to the mill's
  far bank — and 13.1 ms for a resident's own plan of the same trip). The rest that follows keeps the average within
  the desk's 3.5 ms.

## Verification

- `test_demo_routes.gd` (26 tests, no scene tree, no staged assets): the estimate equals the live router's cost —
  a tunnel dug, a Dig-tool plan laid and dug, a bridge built — route leg for leg; the live network untouched; the loaded
  haul walked before and after the bridge (53.9 s against 49.2 s estimated; 8.5 s against 8.1 s); the desk's budget
  (refused when spent or a resident waits, one piece a step, charged, five windows for two trips); restarted when stale;
  a group member by member; the stretch kinds; every hold-up from its real cause; the stages, the heading, the payoff and
  a stage's own benefit; the trip words; the work places; a bridge's materials; the rescue card, paused and blocked; the
  overlay redrawn only on change.
- `test_demo_routes_live.gd` runs `test/live/demo_routes_live.gd` on the real scene at 1280x720 and 1920x1080 (30
  checks each). The layout and input harnesses pass with the hidden Builds.

## Source

REVIEW.md P5 (925–946), P1's tunnel, bridge and water-safety rows (798–800), the bridge wireframe (845–861);
review_digest ECO-039 and ECO-045; SET-MOVE-001 (MOVE-REQ-005, -012, -018, -019; MOVE-G01–05 open); decisions 0332,
0361, 0411, 0231, 0331, 0292, 0391, 0421.
