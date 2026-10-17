# 1939 — The claw Kitchen, and what it found

Date: 2026-10-17 · Status: Built. Follow-up 2 of the C2 follow-ups (the coordinator, 2026-10-17). Closes decision
1937 §6 gap 3, and decision 1937's deferred mutants B5 and B9 (§5).

Branch `feat/room-dig-followups`. Number range 1938–1949.

## Decision

**The Kitchen loop fixture now runs on the mounted content 12, with the claws.** Content 12 is runtime-admitted
(decision 1972, PR #272), so decision 1937's content-6 fixture is no longer the only one. The claw Kitchen
(`godot/test/test_underground_room_claw_kitchen.gd`, class `ClawKitchen` over the haul Kitchen) keeps the Kitchen's
own geometry and owners and changes only what content 12 changes:

| Fixture item | Content 6 (pick) | Claw Kitchen (content 12) |
|---|---|---|
| Profile wire | content 6's catalog | the mounted bundle `qualified-stairs-v10`'s content 12, loaded by its published digest; no box, flag or policy edited |
| Travel rows | pick READY rows 2–9 | claw READY forward 46 and backward 50 at the Kitchen's heading (yaw 49152); the all-yaw WALK 42 is the canonical ground row |
| Work row | the pick rows | the claw wall row 70 (decision 1972, rows 67–70), the painted 4 quanta of each cell (decision 1971) |
| Tool | the basic pick | none (DEC-052) |
| Haul rows | content 6's | content 12's own grip rows: WALK 31, CARRY 32 (wood) and 37 (stone) |
| First station | the pick's reach | the wall row's own reach: its point 521 u ahead of the face |
| Storage M | the builder's parking | M's own Corridor endpoint (the composer never parks a builder on a storage) |
| Paces | — | the catalog binds the existing Movement rate (`RATE_GROUND_CAP`) to each row; no pace is authored |

No row, price, height or pace is invented: every row is the content's own and every rate the existing one. The
inner class names its constants `CLAW_*`, because a nested class resolves an inherited base constant (`CONTENT`,
content 6) before the outer file's.

## 1. What the fixture found in the production code

Four gaps stood between the claws and a dug room. Each is fixed here.

1. **Room travel was pick-only** (`underground_room_itinerary.gd`). `_compatible` and `_anchor_refusal_live`
   hard-coded source 0's pick rows (2–9 and StepProgram.GROUND, 12), so a claw anchor was refused
   `ROOM_STATION_TRAVEL_SOURCE`. A row of a source that its own program owns (Routes' `_source_owner`, here the
   claws) now anchors its own family when it is a READY forward or backward row passing its owner's source proof
   (`Routes._source_profile_refusal`). In that family the compatible travel rows are the READY and short-step rows at
   the anchor's exact heading, and the source's all-yaw canonical ground WALK, each passing the same source proof
   (`_owned`, `_owned_compatible`). Stair and other rows are not travel legs. The parent's and step program's fixed
   row positions are unchanged. Both functions remain pure over the Profiles bank, so decision 1952's anchor and
   edge memos stay exact (every suite checks them live).
2. **The room bindings required a tool** (`underground_room_world_bindings.gd`, outside `worker_refusal`).
   `_ordinary_job_leaf` required the Job's tool gate to be SATISFIED, and `_ordinary_tool_leaf` required an equipped
   tool claimed for the Job. A claw Job is tool-free (`GATE_NOT_REQUIRED`, DEC-052), so every claw bind was refused
   `ROOM_PHASE_WORKER`. A tool-free Job is now accepted when the worker holds no tool and Work has no tool lot for
   it, as Sites' own rule reads it (`_ordinary_gate`, the early branch of `_ordinary_tool_leaf`). A tooled Job's
   check is unchanged.
3. **A settled builder held a retired Job** (`underground_room_builder.gd`). A cube's last Job retires when its
   phase settles, but the builder's route actor kept it. Every other actor's occupancy proof reads every registered
   actor's current selection, and a retired Job is stale there, so a second builder's turn was refused
   `ROUTE_TURN_ACTOR_STALE`. After a cube's FINISH settles, the builder now stands on the READY travel row of its
   heading with no Job (`_drop_retired_job`). A builder waiting out a rest hour between two phases of a cube drops
   the settled phase's Job the same way (`_holds_a_job`; review M4), and takes the next phase's Job when the hour
   allows work again.
4. **A builder stopped on a span froze** (decision 1937's deferred B5). A dig stopped while its builder walked a leg
   released the builder's Job at once; the actor then held a retired Job, and Routes held it on its span for good.
   `abandon` now defers the release when the actor is on a span or has a route queued (`_on_a_span`) **under the
   phase's own Job**. `leave` releases it once it stands READY under the Job it holds (`_at_source_ready`, the same
   wait as a builder stopped in a work source), and the release and the leave then fall on the same tick. A wait
   that never ends is named once at the stall bound (`ROOM_BUILDER_STUCK_UNDERGROUND`), as decision 1937's M1 rule
   has it. A builder walking home after its cube holds no Job, so it is released at once (review H1: deferring it
   saved the retired Job's freed slot, and the stopped dig's record did not load).

## 2. The four deferred cases, closed

| Decision 1937 §6 case | Test |
|---|---|
| The turn after a haul | `test_a_claw_builder_hauls_every_brace_and_digs_the_kitchen`: every BRACE's inputs come from R in whole units through Delivery's room branch; after each haul the builder turns from the grip heading itself and goes on (asserted every tick: a turn or a leg means it has set off) |
| A column haul | the same test: a cube up a column whose inputs ran out is hauled for from its station (a haul begins from a stage other than IDLE); 8 trips, one BRACE's worth left over |
| Two builders hauling | `test_two_claw_builders_haul_and_dig_the_kitchen_together`: two claw builders each haul what their own BRACE lacks through the one Delivery, take turns, and both haul; every unit is hauled once |
| The composer's claw builder end to end | `test_the_composers_claw_builder_digs_the_kitchen_end_to_end`: the composer keeps the bound contacts, picks the idle toolless mole, parks it and the room is dug |

Also:
- `test_a_claw_crew_digs_the_kitchen_end_to_end`: the claws dig every cube with the wall row and walk back out;
- `test_a_builder_stopped_on_its_way_waits_to_rest_then_walks_out` (B5);
- `test_a_builder_stopped_while_walking_home_is_released_and_its_dig_saved` (review H1): the stopped dig saves and
  restores;
- `test_a_claw_family_takes_only_its_own_ready_rows_at_one_heading`: READY rows 46, 50 and 43 anchor; the ground,
  wall, stair and short rows do not; at anchor 46 only 46, 50 and the ground WALK 42 travel (43 and 51/52 do at
  yaw 0); a row failing its source proof does not;
- `test_a_tool_free_phase_job_refuses_a_worker_holding_a_tool`;
- `test_underground_room_foreman.gd`'s rest test asserts the actor holds no Job while it rests between phases.

Two existing fixtures change with the gaps: the world-phases fixture's worker stands at its own `work_x` (the wall
row's reach on the claw Kitchen), and its retreat row is a field (`retreat_row`); the haul fixture publishes M's
spans from M's own storage point.

## 3. S3

Decision 1937's deferred S3 (`finish` without its overflow check) stays deferred: no fixture writes a room record
near `MAX_WIRE_BYTES`.

## 4. Cost

The claw Kitchen suite runs in about 57 s in a focused run (five tests), under the slow tier's 60 s threshold.

## 5. Mutation testing and review

Decision 1940 §4 holds the lane's mutation run and the independent review for decisions 1938–1940. Decision
1937's deferred B5 and B9 are killed there; S3 stays deferred (§3).

## Note

Files edited beyond the four cleared ones (the coordinator cleared the room builder, foreman and runtime modules and
their tests): `underground_room_itinerary.gd` (gap 1) and, in `underground_room_world_bindings.gd`, functions other
than `worker_refusal` (gap 2).
