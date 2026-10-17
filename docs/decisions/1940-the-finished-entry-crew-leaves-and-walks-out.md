# 1940 — The finished entry's crew leaves the route roster and walks out to H

Date: 2026-10-17 · Status: Built. Follow-up 3 of the C2 follow-ups (the coordinator, 2026-10-17), from decision
1972's finding "Found while taking the frames".

Branch `feat/room-dig-followups`. Number range 1938–1949.

## The problem

When the entry finishes (G9, `ENTRY_KITCHEN_UNBUILT`, tick 8,348 on the live chain), its crew rests on T5's station
as a registered Routes actor that still holds the last tread's Job. That Job is retired, so the actor's current
profile is `PROFILE_JOB_STALE`. Every other actor's occupancy proof reads each registered actor's current
selection, so any actor whose way passes near it is held `ROUTE_OCCUPANT_PROFILE_STALE` (decision 1972's loaded
carrier stopped at T0). The entry also reserved the crew for good, as a route actor.

Measured on the live chain at the finishing tick: the crew is at rest (on an endpoint, no edge or queue) on its
idle READY source word, Jobs has released it, and its actor still names the retired Job.

## Decision

**Once the entry is done, its crew leaves the roster from rest and walks out to H, as decision 1937's room builders
do (the C2.3 walk-out).** In `underground_entry_runtime.gd`:

- `is_leaving()`: the entry is done, still holds G9, and its crew is still a route actor or on its walk out.
- `advance` gives a leaving entry's tick to `_leave()`:
  - a crew that died or left (`_crew_loss_refusal`) has its actor removed (`unregister_lost_actor`, ADR 1225) and
    walks nowhere;
  - otherwise the crew leaves the roster with DEC-059's resting unregistration (`unregister_resting_actor`). If it
    is not at rest it waits (on the live chain it always is);
  - it then walks to H by ADR 1219's timed walk: `ceil_div(D × 30, v)` ticks, D the exact straight distance rounded
    up and v its size class's ground speed. Its Transform stays where it rested until arrival places it on H's
    point, facing as it stood (no heading is derived). No constant is new.
  - Arrival is a foreign pose change to Routes, so the occupancy roots are rebuilt at once (`refresh_occupancy`),
    as decision 1937's walk-out does.
  - A refused leave stops for good: no walk, its own code kept and raised once (`_end_leave`).
- `reserves_resident` keeps the crew reserved while it walks out; it is released on arrival. It then is an idle
  mole holding no Job, free for any work.
- **Save.** No field is added. The walk out reuses the walk's ticks and H's point; a walk at STEP_DONE is the walk
  out. `_walk_refusal` accepts it only with the resident's own heading (`_arrival_yaw` −1) and the crew off the
  roster; a walk in still needs STEP_RUNNING and the foreman's arrival heading. A crew still on the roster at
  STEP_DONE is derived from Routes, so a save from before this change loads and leaves on its next tick.
- **The host** (`settlement_system.gd` `_advance_underground_entry`, one condition) ticks the entry while it is
  running or leaving. This file is outside the cleared list; the change is that one condition.

Nothing changes before the finishing tick: the chain, its ledger, its finishing tick and every checkpoint are as
before.

## Tests

`godot/test/test_underground_entry_crew_leaves.gd` (slow tier, about 156 s: each test runs the whole entry to its
finish):

- `test_the_finished_crew_leaves_the_roster_and_walks_out_to_h`: at the finish the crew is a route actor holding a
  retired Job whose profile is stale, and the entry is leaving and reserves it. The next tick it is off the roster
  on the exact timed walk, reserved; the walk's record round-trips through the entry's own capture and restore, and
  a walk-out record claiming H's arrival heading is refused `ENTRY_SAVE_SHAPE`. The Transform stays put until
  arrival, which places it on H facing as it stood; the entry is no longer leaving, the crew is released and idle,
  Routes' occupancy is current, and the entry still holds G9.
- `test_a_finished_crew_lost_before_it_leaves_is_removed_from_the_roster`: a crew that dies on its last station is
  removed from the roster where it lies, walks nowhere, and is no longer reserved.
