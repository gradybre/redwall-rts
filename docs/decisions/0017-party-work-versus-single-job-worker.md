# 0017 — Party work contradicts the singular `Job.worker` field
Date: 2026-09-06 · Status: **Open** · Blocks: BUILD and FISH job acceptance

## The contradiction
GDD §4.2 gives `Job.worker` as a **single** `EntityRef`. But §5.3 states
construction, expedition and processing WU are "total work shared by the
declared party, not a requirement repeated per member", and `Construction`
carries `assigned_count`/`max_workers` while `Expedition` carries
`member_ids: int32[3]` with "one job/member".

Neither `game_gdd.md` nor `systems_architecture.md` says how a party member's
`Job.remaining_mwu` relates to the shared `remaining_mwu` on the destination
`Construction` or `Expedition` entity.

## Reading that appears most consistent (NOT adopted)
Each party member holds their own `Job` row — satisfying both "one job/member"
and the one-job-per-resident `JobAgent` rule — all pointing at the same
destination, with the authoritative shared `remaining_mwu` living on that
destination rather than being meaningfully duplicated per member.

**This is a reading, not a decision.** It is recorded so nobody implements a
different one by accident, and so nobody mistakes it for settled.

## Consequences
- Job selection, eligibility, urgency and the sort key do **not** depend on this
  and may proceed.
- The WU accumulator may proceed for single-worker jobs.
- **BUILD and FISH acceptance must not be implemented until this is resolved.**
  Getting it wrong inflates output by the party size, which a test with a known
  party and known per-member work factors would catch — see the acceptance note
  in `docs/tasks/02_settlement_foundation.md`.

## Source
Found by specification audit, 2026-09-06, while parsing §5.3 for task 2.11.
Same class as U4: a capacity relationship implying a layout no document states.
