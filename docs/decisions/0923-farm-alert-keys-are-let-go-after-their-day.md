# 0923 — The farm's said-once alert keys are let go after their day
Date: 2026-10-01 · Status: Accepted

## Decision

`farm_alerts.gd` keeps the key of each line it has said, so a line is said once.
- On a new farm day it now lets the older keys go.
- A forecast's keys are kept apart, keyed by event, and are let go when the season changes.
- `said_count()` reports how many are kept.

No line changes. `test_demo_farm_alerts_bound.gd` runs thirty game days hour by hour against an alerts object that
never lets a key go. The two say identical lines every hour, while the kept keys stay within a day's worth.

## Why

Every key but a forecast's names the day it is for: "ripe:bed:day", "frost:day", "spoiled:item:day" and so on. A key
for a day already past can never be asked again. Kept for good, the dictionary grew by a few keys a game day, the one
unbounded store in the demo that a read-through found. A soak test's village runs for hundreds of days at 4x.

The gain is small: about 1 KB a day. The soak's static-memory slope was about 20 KB a game day with or without this
fix, and it flattened by day 12 as the capped logs filled. It is made because it is a clear, bounded, behaviour-
preserving fix of a real unbounded store, not because it moved the measurement.

## Source

The soak test (decision 0921) and the read-through of growth sites made for it.
