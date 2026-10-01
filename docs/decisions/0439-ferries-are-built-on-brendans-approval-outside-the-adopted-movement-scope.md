# 0439 — Ferries are built on Brendan's approval, outside the adopted movement scope and despite the review's "Stretch"
Date: 2026-10-01 · Status: Accepted

Water part B, lane 3. Records the authority for decisions 0437 (the ferry) and 0438 (the regatta).

## Decision

The ferry and the regatta are built for the live demo because **Brendan approved all of water part B, ferries and the
regatta feast included** (decision 0493, group K: "Water part B, everything: … ferries, the regatta feast …", approved
2026-09-30; B3 "ferries, the regatta feast" was queued there and is this lane). Two things that would otherwise have
stopped it are recorded, not worked around:

1. **The review rated ECO-041 "Stretch"** and listed "free sailing/ferries" among the scope to defer, saying a ferry needs
   a movement-scope ruling first (review digest, ECO-041 and its conflict flag). Brendan's group-K approval is that
   ruling for the demo. The lane keeps every condition the review set if a ferry were built anyway: **fixed two
   landings, cargo first, no free sailing, and a reason on the far bank** -- and no mandatory ferry: nothing in the
   village needs it; the ford and the bridges stay the land ways round.
2. **SET-MOVE-001** (`docs/movement_direction_amendment.md`) keeps "boat transport [as] a separate mechanism" and does not
   include moving vessels in the adopted movement scope; **MOVE-G01–05 remain open**. The ferry does not close or change
   any of them: it is a demo presentation over integer rules, like the boat core (decision 0432) it extends. Its passenger
   leg is a router crossing row like a bridge's, walked by the ferry's own steps, and it follows MOVE-REQ-007 (a crossing
   entered is finished) and the bank recheck's rule that a refusal ends a leg where it stands. No production movement
   constant is invented by it: every number is a named DEMO value in `ferry_rules.gd` / `regatta_rules.gd`.

## Consequences

- When the movement contracts close (MOVE-G01–05), the ferry's crossing row and its deck walks are to be re-examined
  against them, as every demo crossing is.
- The far copse, the timetable, the threshold, the boat's cargo and the race's pace are demo values awaiting Brendan's
  look; none is a balance figure for the game.

## Shared files this lane touched (for the integrators)

`demo/boats/boat_routes.gd` (the stages, the third berth and route), `boat_fleet.gd` (a pace column; names),
`boat_rescue.gd` (each boat from its own jetty), `demo/fishery/fishery.gd` and `demo_fishery.gd` (fishing boats only),
`demo/water/water_dressing.gd` (the coracle moved), `demo/waterplay/water_crossings.gd` (the ferry row),
`demo/waterplay/water_panel.gd` (the Ferry and Regatta sections; `scroll_to_line`, held for a few frames while a
panel just brought forward grows), `demo/routes/route_kinds.gd`, `route_overlay.gd`,
`route_reasons.gd`, `demo_routes.gd` (a member aboard the ferry boat reads "by ferry" in the panel), `rescue_card.gd`, `demo/work/work_ids.gd` (SOURCE_FERRY; SOURCE_WALK = 9),
`demo_work.gd`, `demo/kitchen/meal_rules.gd` (the fourth dish), `kitchen.gd` (an occasion), `demo/people/people_ledger.gd`,
`people_text.gd`, `demo_people.gd` (also: one held on the water but not in it reads "aboard a boat", not "in difficulty" --
the fishing crews had the same mislabel; `test_demo_people_ui.gd` follows), `demo/songs/demo_songs.gd` (a work-reader hook), `demo/guide/field_guide.gd`,
`help_topics.gd`, `demo/demo_village.gd`, the demo README.

## Source

Decision 0493 (group K, Brendan, 2026-09-30); the external review's ECO-041 and its conflict note; SET-MOVE-001 §1 and the
MOVE-G01–05 gate table; decision 0432.
