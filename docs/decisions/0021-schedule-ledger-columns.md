# 0021 — The schedule latch is budgeted, not deleted
Date: 2026-09-06 · Status: **Accepted** (Brendan, 2026-09-06)

## Decision
`schedule.gd`'s extra columns are correct and stay. The memory ledger absorbs
them; the latch is **not** removed to match the table.

## Why the latch is required
GDD §5.3: sleep continues only until rest reaches its threshold, after which the
resident uses ANYTHING **until the scheduled sleep window ends**. That is latched
window state. Recomputing it from current rest sends a satisfied resident back to
bed inside the same window — at 375/hour decay, roughly 2.7 hours later.

## The actual columns

| Column | Bytes | Treatment |
|---|---:|---|
| `_sleep_satisfied` | 512 | Save and hash |
| `_resolved` | 512 | Preserves validity of `current_activity`; save and hash |
| `_present` | 512 | Accounts for existing component occupancy storage |
| **Total** | **1,536** | |

Schedule packed payload becomes **17,920 bytes**, up from 16,384.

With this correction alone, the baseline live-world total including its existing
reserve becomes **66,103,398 bytes**. Reservation indexes (decision 0019),
coordinator state (decision 0017) and the expanded movement scope still require
their own additions.

## Consequences
- `docs/systems_architecture.md` §2.2/§2.3 needs amending to match. Until it is,
  this record is the authority for those figures.
- All three columns are saved and hashed, so two logically identical worlds
  serialise identically.

## Critical regression test
Reach 9000 rest during scheduled sleep, wake, let rest fall, **save and load**,
and remain awake until that sleep window ends. The save/load half cannot run
until saves exist; the rest is testable now.

## Source
Implementation flagged the gap 2026-09-06; Brendan ruled the same day and
supplied the exact column set and revised totals.
