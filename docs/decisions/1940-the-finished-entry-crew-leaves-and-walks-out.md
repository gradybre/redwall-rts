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

- `is_leaving()`: the entry is done, still holds G9, and its crew is still a route actor (read in O(1) from its
  Routes row) or on its walk out.
- `advance` gives a leaving entry's tick to `_leave()`:
  - a crew that died or left (`_crew_loss_refusal`) has its actor removed (`unregister_lost_actor`, ADR 1225) and
    walks nowhere;
  - otherwise the crew leaves the roster with DEC-059's resting unregistration (`unregister_resting_actor`). The
    foreman ends the entry with its crew at rest, so a crew not at rest is refused and named once. A busy Routes
    (`ROUTE_TRANSACTION_BUSY`, `ROUTE_SPACE_TRANSACTION`) is retried the next tick (review M3);
  - it then walks to H by ADR 1219's timed walk: `ceil_div(D × 30, v)` ticks, D the exact straight distance rounded
    up and v its size class's ground speed. Its Transform stays where it rested until arrival places it on H's
    point, facing as it stood (no heading is derived). No constant is new.
  - Arrival is a foreign pose change to Routes, so the occupancy roots are rebuilt at once (`refresh_occupancy`),
    as decision 1937's walk-out does.
  - A refused leave stops for good: no walk, its own code kept and raised once (`_end_leave`).
- `reserves_resident` keeps the crew reserved while it walks out; it is released on arrival. It then is an idle
  mole holding no Job, free for any work.
- **Save.** No field is added. The walk out reuses the walk's ticks and H's point; a walk at STEP_DONE is the walk
  out. `_walk_refusal` accepts it only with the resident's own heading (`_arrival_yaw` −1), G9 held, a crew, and the
  crew off the roster (review M1); a walk in still needs STEP_RUNNING and the foreman's arrival heading. A crew still on the roster at
  STEP_DONE is derived from Routes, so a save from before this change loads and leaves on its next tick.
- **The host** (`settlement_system.gd` `_advance_underground_entry`, one condition) ticks the entry while it is
  running or leaving. This file is outside the cleared list; the change is that one condition.

Nothing changes before the finishing tick: the chain, its ledger, its finishing tick and every checkpoint are as
before.

## Tests

`godot/test/test_underground_entry_crew_leaves.gd` (slow tier, about 156 s: each test runs the whole entry to its
finish):

- `test_the_finished_crew_leaves_the_roster_and_walks_out_to_h`:
  - at the finish the crew is a route actor holding a retired Job whose profile is stale, and the entry is leaving
    and reserves it;
  - the next tick it is off the roster on the exact timed walk, reserved, and the walk's record round-trips through
    the entry's own capture and restore;
  - records the leave never writes are refused `ENTRY_SAVE_SHAPE`: a walk out with the crew still on the roster,
    one holding another code than G9, and one facing H's arrival heading;
  - the Transform stays put until arrival, which places it on H facing as it stood; the entry is then no longer
    leaving, the crew is released and idle, Routes' occupancy is current, and the entry still holds G9.
- `test_a_finished_crew_lost_before_it_leaves_is_removed_from_the_roster`: a crew that dies on its last station is
  removed from the roster where it lies, walks nowhere, and is no longer reserved.

## 4. Review and mutation testing (decisions 1938–1940)

**Independent review** (code-reviewer agent, adversarial, on `43c12e25`). No CRITICAL. One HIGH, fixed:

| Finding | Fix |
|---|---|
| H1: a builder stopped while walking home after its cube deferred its release (`_on_a_span`), and the stopped dig saved its retired Job's freed slot, so the save did not load (`ENTRY_SAVE_JOB`, reproduced) | The deferral applies only to an actor walking under the phase's own Job; a builder walking home is released at once. `test_a_builder_stopped_while_walking_home_is_released_and_its_dig_saved` |
| M1: a walk-out record holding another code than G9 restored as a crew reserved for good | `_walk_refusal` requires G9 and a crew |
| M2: untested branches | `_take_job_here` and the two-way release wait are removed (no case reached or told them apart); the claw family, tool-free and walk-out record tests are added |
| M3: a busy Routes ended the leave for good; a crew not at rest waited silently | busy codes are retried; a crew not at rest is refused and named once |
| M4: a builder resting between two phases of a cube held the settled Job | it drops it (decision 1939 §1.3); the rest test asserts it |
| LOW: `is_leaving` scanned 512 rows a tick once a crew was gone | it reads the crew's own Routes row |

Kept LOW: if the walk cannot be timed after the crew has left the roster, the crew is released where it stands
(its size class or speed is unreadable; not reachable on the live chain). `_start`'s proof refresh ignores its own
return, as `_earn`'s does. Fixed with them: the claw Kitchen suite's `.uid` is committed.

**Mutation testing.** A scratch runner applies one mutant at a time and runs its focused suites: 32 mutants over the
room bindings, the itinerary, the builder, the entry runtime and the host. **26 are killed**, including decision
1937's deferred B5 and B9. **4 are equivalent and 2 unreachable:**

| Mutant | Verdict |
|---|---|
| V2, V3: `_ordinary_vacant` without either half | **Equivalent.** Sites' `bind_worker` refuses the same two conditions itself, right after asking the bindings |
| I3: `_owned_compatible` without its source proof | **Equivalent on content 12.** `_compatible` first requires fields 0–9 and the quantities to equal the anchor's, and the anchor's own ownership; the claw proof checks nothing else that can differ |
| I4: the ground row without its WALK check | **Equivalent on content 12.** No owned all-yaw canonical ground row is anything but WALK; the claw proof also requires it |
| E8: the zero-tick walk out without its occupancy rebuild | **Unreachable:** the crew's last station is never H |
| E11: the busy-Routes retry | **Unreachable:** Routes holds no open transaction at a tick boundary |
