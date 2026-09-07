# 0017 — Party work uses a coordinator Job
Date: 2026-09-06 · Status: **Accepted** (Brendan, 2026-09-06)
Requires: an amendment to ARCH-JOB-005

## Decision
Each worker holds their own `Job`. Each shared activity additionally has **one
coordinator Job** that survives worker replacement and owns the shared
reservations, batch identity, lifecycle and completion.

| Record | Owns |
|---|---|
| Coordinator Job | Shared reservations, batch identity, lifecycle, completion |
| Member Job | One worker's assignment, eligibility, contribution |
| `Construction` | Sole authoritative `remaining_mwu` for construction |
| `Expedition` | Sole authoritative `remaining_mwu` for fishing |
| Processing coordinator | Sole authoritative `remaining_mwu` for its batch |

## Why the extra record
The obvious model — members pointing straight at a destination — has a bad
failure case: the original worker leaves, and cancellation releases *everyone's*
ingredients or discards their progress. A coordinator that outlives any
individual worker gives departure and cancellation separate paths.

## Rules
- The coordinator has `worker = null`, cannot be selected by a resident, and
  contributes no work.
- Member Jobs reference the coordinator. Their shared-phase `remaining_mwu`
  stays **zero** — members never hold copies of shared progress.
- Coordinator and member Jobs both count against the existing 8192-row capacity.
- A shared-capable activity keeps its coordinator even when down to one worker.
- **Worker departure** releases that worker's assignment and personal claims
  only. Shared progress, consumed inputs and batch data survive.
- **Only explicit activity cancellation** invokes refund rules.
- Only the coordinator creates outputs, applies cycle wear, rolls the cycle
  result, and records completion.

## Per productive tick
```
potential_i    = each worker's contribution per BAL-WORK-001
accepted_total = min(remaining_mwu, sum(potential_i))
remaining_mwu -= accepted_total
```
On the finishing tick, allocate accepted work proportionally: floor each share,
then distribute leftover milli-WU by **largest fractional remainder**, ties by
**ascending resident persistent ID**. Award XP only from accepted work. Retain
fractional XP progress separately per resident and skill.

## Acceptance
A synthetic 120-WU shared activity with two base-rate workers takes
80 + 80 = 160 milli-WU/tick, finishes after **750 productive ticks**, credits
**60 WU per worker**, and produces **one** completion. Passive waiting never
accelerates with crew size.

## Consequences
- **ARCH-JOB-005 needs amending**: completion belongs to the coordinator, not to
  every member Job.
- BUILD and FISH acceptance are unblocked once the coordinator exists.
- A test with a known party and known per-member work factors must catch
  per-member inflation — the failure this model exists to prevent.

## Source
Specification audit 2026-09-06 found the contradiction; Brendan ruled the same
day, adding the coordinator record beyond the reading originally proposed.
