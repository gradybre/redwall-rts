# 1938 — A resumed builder takes a stopped dig's paid phase to the end

Date: 2026-10-17 · Status: Built. Follow-up 1 of the C2 follow-ups (the coordinator, 2026-10-17). Closes decision
1937 §6 gap 1 (P-1933-2 (a)).

Branch `feat/room-dig-followups`, from `4c4fec92`. Number range 1938–1949 (the coordinator, for the follow-ups).

## Decision

**The room bindings admit the Job's newly assigned worker to bind to a started phase that was left vacant.** A dig
that stops releases its builder through Sites, so the phase keeps its paid progress and its Job but has no worker.
When the room is ordered again, the new builder takes that Job and asks Sites to bind it. Sites' `bind_worker` asks
the bindings' `worker_refusal` before it registers the worker, and `_ordinary_needs_worker` (true at STAGE_START
and STAGE_WORK) required the asking worker to be the one already registered. Binding before registration was
therefore impossible, and every resume was refused `ROOM_PHASE_WORKER`.

`underground_room_world_bindings.gd` `worker_refusal` now also accepts a worker for which `_ordinary_vacant` holds:

- the worker is registered to no Site (`_worker_site[resident] == NO_ROW`); and
- nobody is registered to this Site (`_registered_worker_row(site) == NO_ROW`).

Productive work is unchanged: Sites checks the registration itself before it asks the bindings for any later
step, so only the bind is opened, and only onto an empty phase.

**A resumed START re-derives a stale static proof once.** The stopped dig's static proof can be stale by the time
the room is ordered again (`SPACE_STATIC_PROOF_STALE`). `underground_room_builder.gd` `_start` then refreshes the
Site's static proof and retries `resume_phase_work` once, as Work already does for a lost proof (`_proof_lost`).

## Cost-2's memoization

`worker_refusal` keeps no memo of its own; decision 1952's caches (the anchor, edge and endpoint memos) sit below
it. The new branch is reached only when the old registration check has already failed, and it reads two Sites
columns, so every call the old rule admitted takes exactly the same path and the same cached proofs. Every suite
runs with decision 1952's live cache checks on (`CacheChecks.enabled`), and none reports `RUNTIME_CACHE_STALE`.

## Test

`test_underground_room_foreman_crews.gd`: the pinned gap test is renamed
`test_a_paid_phase_left_by_a_lost_builder_is_taken_over_and_the_room_finished`. A builder dies mid-BRACE, the dig
stops and is released, and a second mole is ordered onto the room. It takes the paid phase over at its station
(Sites' resume, no second payment), then digs the room to the end with no refusal: every cube done, no live
Project, the wood stock sized to one bill per Site fully consumed (each BRACE paid once), the record released by
itself, and the taker back where it stood, holding no Job and no longer reserved.

Decision 1937's deferred mutant B9 (a resume beginning the phase instead of resuming it) is now reachable: see
decision 1939 §5.

## Note

The edit is in `worker_refusal`, as cleared. Decision 1939 adds two further edits to the same file, outside
`worker_refusal` (`_ordinary_job_leaf`'s tool gate and `_ordinary_tool_leaf`'s tool-free branch).

**Note (2026-10-19, decision 1991 §3).** The resume here covers a *started* phase only. A dig stopped on the tick a
BRACE hands over to CUT (or CUT to FINISH) leaves the cube BRACED (or open) with no live phase, and a re-order used to
open BRACE on it, which Sites refused (`EXCAVATION_PHYSICAL_PHASE`). Slice C3 found this with the player's Stop and
fixed it in the builder: `_next_operation` opens the phase the cube needs next, by Sites' own record.
