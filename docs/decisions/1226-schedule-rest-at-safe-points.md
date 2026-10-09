# 1226 — Every resident rests at a 30-WU safe point when its schedule says so (REQ-SET-034, DEC-056)

Date: 2026-10-07 · Status: Accepted (Brendan's decision, DEC-056); implemented.

## Brendan's decision

> Follow the schedule (REQ-SET-034): implement it for every resident — a resident pauses its Job at a safe point
> when its schedule says rest, then resumes — and for the crew, pause at a resting point (an endpoint, at rest, per
> ADR 1210's switch-at-rest rule) and resume.

REQ-SET-034: "When a schedule changes, the system shall finish at most the current 30-WU safe work segment before
changing activity; emergencies shall interrupt immediately."

## Before

The settlement resolved an activity only for **idle** residents (`Jobs.should_evaluate`). A resident holding a Job
was never re-resolved, so it worked through the night. That was named a gap in `jobs.gd` and in ADR 1223.

## Decision

### 1. Busy residents learn the hour (`settlement_system.gd`, `jobs.gd`)

`_resolve_and_select` now resolves **every** due resident (`Jobs.is_due`: the same persistent-ID-mod-30 stagger)
and offers a job only to an idle one (`should_evaluate`, unchanged). The change is minimal and in the selection
stage, not in save code. The activity a busy resident reads is therefore at most 30 ticks stale, exactly as an idle
resident's is.

### 2. The safe point and the rest (`work.gd`, `schedule.gd`)

- **Safe point.** A safe point is where the progress row's `remaining_mwu` is a whole multiple of
  `SAFE_SEGMENT_MWU` = 30,000 (30 WU, GDD §5.2's milli-WU). This includes 0. Segments are counted from the end of
  the Job, so they are fixed by saved state alone. `Schedule.rests_now(slot)` reads the resolved activity
  allocation-free: true for SLEEP or SOCIAL, false for WORK, ANYTHING or a row never resolved.
- **Finishing the segment.** While any contributor rests, `_commit_into` caps the tick's accepted work at the next
  safe point below the remaining work (`_segment_capped`). The tick that would cross it stops exactly on it. The
  existing proportional split handles the capped tick, as it handles a finishing tick.
- **Resting.** A contributor that rests while its row stands on a safe point refuses with `WORK_SCHEDULE_REST`. The
  refusal comes before any carry is spent, so a resting tick changes nothing.
  - For a party, the code is skippable (decision 0017): the resting member drops out and the others carry on.
  - ProductiveWork treats the refusal as ordinary: the Job stays bound and in WORK.
- **Resuming.** When the next resolution yields WORK or ANYTHING, the same Work tick continues from the safe point.
  Progress belongs to the Job, so nothing is lost.
- **Emergencies** still interrupt immediately through eligibility step 1 (death, incapacity, rest ≤ 500), unchanged.

**No new state.** The rest is derived from the saved `Schedule._current_activity`/`_resolved` (§4) and
`Job.remaining_mwu`. A load restores it exactly.

### 3. The entry crew rests at a resting point (`underground_entry_*`)

- **Paid EARN (cut phases and installations).** When Work refuses `WORK_SCHEDULE_REST`, the foreman (or installer)
  requests source READY and enters a new `STAGE_REST` (11). The source recovers to the canonical idle READY word on
  the station, which is ADR 1210's resting point, and waits there. When the hour permits work again, it re-enters
  WORK through the ordinary entry. The foreman's START finds the phase already WORKING and resumes it through
  ADR 1225's path (`bind_worker` is idempotent; `resume_phase_work`), so nothing is paid twice. The installer goes
  back through `STAGE_INSTALL_ENTER`.
- **Anywhere else.** While the crew holds an entry Job, the runtime advances nothing while the crew's hour forbids
  work **and** the crew stands at a resting point. A resting point is:
  - registered, on an endpoint, with no edge, queue or tail (`Routes._at_rest`);
  - with either the canonical idle READY source word or an idle automatic row.

  Mid-route, mid-lift or mid-handling the crew carries on to its next resting point. That is ADR 1210's switch-at-rest
  rule applied to pausing. While paused, the foreman's stall budget does not run, because it is not advanced.
- An idle crew already waited for a work hour (ADR 1223).

The two new stage values widen the foreman's and installer's stage ranges in the ADR 1218 record. No field is
added.

## Evidence

- `test_work.gd`:
  - a resting worker finishes exactly the current segment (the capped crossing tick), rests at the safe point with
    no state change, and resumes in a work hour;
  - a work hour never rests;
  - a resting party member drops out while the others work on.
- `test_jobs.gd`: `is_due` covers busy agents.
- `test_underground_host.gd`: with the crew's 08:00 hour set to SLEEP, the live chain rests at a resting point
  during that hour (no Work accepted, crew still holding its Job) and resumes at 09:00. It reaches the same next gap
  with the same ledgers (36,000 mWU, six units).

## Cost

- `Schedule.rests_now` is three packed reads.
- Work calls it once per contributor per tick, plus once per contributor in the cap.
- Selection now resolves busy residents too. That is one resolve per resident per 30 ticks, the cost idle
  residents already paid.
- No memory: `work.gd` gains two constants and one function. Its reviewed storage delta is recorded.

## Addendum (2026-10-08, ADR 1229 increment 6b): the hauler rests at its stand

The descent's live chain met a gap. The crew's 22:00 hour turned to SLEEP just as it selected a lift at R's stand.
That stand is a resting point, so the entry paused there (§3). The lift's HAUL Job was already in WORK, and its
2 WU (`HAUL_LOAD_MILLI_WU`) are not a safe point. So the settlement's ProductiveWork, which ticks every Job in WORK,
finished it during the pause. When the hour permitted work again, the hauler's next `tick_solo` refused
`NO_WORK_REMAINING`, and the entry stopped with `ENTRY_HAUL_WORK`.

The hauler now follows this section's rules for handling Work at a stand:

- a `WORK_SCHEDULE_REST` refusal waits at the stand;
- a handling Job the rest left complete is finished, not refused. Work belongs to the Job.

No field, stage or record changes. Evidence:
`test_underground_host.gd::test_a_rest_at_a_haul_stand_lets_the_lift_finish_and_the_haul_carries_on`.

**Recorded, not changed: ProductiveWork also ticks the entry's own HAUL Jobs.** It skips BUILD Jobs only. During a
live day the hauler and the settlement therefore each tick a lift or set-down: 11 ticks for 2 WU instead of about
23. Every measured haul in ADR 1229 includes this. Excluding the dispatcher's Jobs (`Jobs.bind_dispatcher`) from
ProductiveWork would make each lift and set-down about 12 ticks longer and move every live-chain pin. That needs
its own decision.
