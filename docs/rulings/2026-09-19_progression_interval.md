# PROGRESS-C4-R01 — continuous Charter interval

2026-09-19 · Astra · Version 2. Governs REQ-SET-155 / ARCH-CONFLICT-004.

Adopt the exact endpoint interpretation in
[PC-06](../planning/progression_execution_package.md): at midnight starting winter
day12, require every M4 predicate at every committed state from T−54000 through T
inclusive. This is 54001 observations spanning 54000 complete tick intervals.
The existing numeric thresholds and award instant stay unchanged. Reset on any
false predicate or departure from winter. Repeated wall frames while paused do
not observe another tick. The broader progression owner/schema/reward/UI packets
remain gated; this ruling releases only the stateless interval helper below.

## Exact helper contract

New `godot/scripts/core/progression_interval.gd` extends RefCounted and has no
mutable module state, new arrays, catalog registrations or production caller.
Use existing SimClock constants; do not fork the calendar. Int64 authoritative
math only. Accept tick values 0..INT64_MAX−CALENDAR_OFFSET_TICKS (the existing
calendar addition's safe domain). All bad inputs return false with an explicit
IntMath.IntResult refusal; success returns true, sets ok, clears error and writes
value. Hot-path `_into` methods allocate no objects.

`advance_since_into(tick:int, last_observed_tick:int, true_since_tick:int,
all_predicates_true:bool, out:IntMath.IntResult)->bool`:

- The only fresh observation is tick0 with last=−1 and since=−1.
- Otherwise tick=last+1; compare without overflowing. Duplicate, skipped,
  reversed, negative or out-of-domain ticks refuse. No inferred skipped truth.
- Prior since must be −1 or 0≤since≤last, and if set it must be within the
  winter containing last. A corrupt prior tuple refuses without being repaired.
- Derive winter from tick and calendar offset. If not winter or predicates
  false, succeed with −1. Otherwise preserve prior since if in this same winter;
  if unset, start since=tick. Entering a new winter cannot carry an old streak.
- The caller writes both returned since and last=tick only after success.
  This helper cannot write authority and must not mutate caller scalar inputs.

`award_eligible_into(tick:int, last_observed_tick:int, true_since_tick:int,
all_predicates_true:bool, already_awarded:bool, out:IntMath.IntResult)->bool`:

- Validate tick and last=tick (the final observation happened). Since is −1
  or within the current winter and ≤tick. Outside winter, since must be −1.
- During winter, current true predicates require since≥0; false requires since=−1.
  Inconsistent tuples refuse rather than masquerading as ineligible.
- A valid tuple succeeds with value1 exactly when not already awarded, all
  predicates true, year≥3, winter day12 at exact midnight, and tick−since≥54000.
  Otherwise it succeeds with0. It does not award a bit, grant items or pause.
- Current predicates include the year requirement and all authored live facts;
  the helper independently checks the date/year to prevent temporal bypass.

These methods validate a supplied history tuple, not prove it came from real
production observations. Only the future per-tick owner and save continuity
checks can establish that. Missing dependencies cannot be supplied as true.
The result object follows existing IntMath semantics: a refusal changes only
out to ok=false,value=0,error nonempty; it never mutates a world or saved tuple.

## Tests and release boundary

Use the real SimClock calendar at tick2569500 and the exact year3 boundary table.
Test a contiguous54,001-observation pass, start one tick late, single false
between midnights, false at T, initialization and strict observation ordering,
season reset, winter-start since, malformed sentinels/future/past-winter since,
year2, late years, T−1/T/T+1, already-awarded, restore-equivalent scalar handoff,
pause represented by no invocation, and tick overflow limits. Reuse caller result
objects; no large simulation allocations needed. All prior suites must remain
passing. Register the new stateless module as category3 with no save fields;
do not edit the active packed registry/save schema or memory ledger totals.

Independent review checks both code and contract-follow-through. Pure helper
acceptance is not integrated progression, first-playable or release acceptance.
