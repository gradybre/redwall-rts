# 0023 — Candidate enumeration visits urgency buckets, not row order
Date: 2026-09-06 · Status: **Accepted** (Brendan, 2026-09-06)
Supersedes the live-row scan shipped in `48998c6`

## The defect
The first implementation examined at most 32 candidates in **ascending live-row
index order**. Sorting that window correctly does nothing for urgency *outside*
it: **thirty-two cosmetic jobs can hide a rescue at position 33.** That is a
gameplay consequence, not a ranking nicety, and selection is not complete until
it is fixed.

## Decision
- A pass examines at most **32 candidates total**.
- Enumeration visits **urgency buckets 0 → 4**.
- Within the highest bucket containing an examined eligible candidate, pick the
  best examined candidate by the specified comparison terms.
- Descend to a lower bucket **only after exhausting higher buckets** without an
  eligible candidate.
- If the budget expires with no candidate, retain the continuation and retry on
  the resident's next scheduled pass.
- **A newly available higher-urgency job invalidates a continuation into lower
  buckets.**
- **Unexamined means not evaluated** — never ineligible, never unreachable.

This deliberately permits **approximate ranking within a bucket** while
preserving **exact urgency between buckets**. That distinction belongs in §5.3.

## Continuation key
Replace the positional cursor with a stable key — `(bucket, job persistent_id)`.
The claim that deleting a job costs "one pass" is not generally true under
repeated insertion and deletion: positions shift, so a positional cursor changes
meaning. Persistent IDs are never reused, so the key does not.

## Gate revalidation
Gate values must be **refreshed or revalidated before reservation commitment**.
A cached "inputs satisfied" cannot authorise acceptance after another job has
reserved those inputs. Equally, a missing subsystem must never silently read as
"requirement satisfied".

## Required tests
- A rescue behind more than 32 cosmetic jobs
- Higher-urgency work appearing during a continued scan
- Deletion before the continuation point
- Save/load mid-scan
- More than 32 higher-urgency candidates that all fail eligibility

## Consequences
- The shipped live-row ordering is a **documented implementation limitation**
  until corrected. It can support the WU benchmark in the meantime.
- Legal-destination checking and the missing `estimated_path_cells` comparison
  remain separate gates, unaffected by this.

## Source
Brendan, 2026-09-06, correcting the bounded-selection contract accepted the
same day.
