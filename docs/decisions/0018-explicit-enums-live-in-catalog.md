# 0018 — Explicitly numbered enums live in `catalog.gd`
Date: 2026-09-06 · Status: Accepted

## Decision
Every enum GDD §4.3 numbers explicitly belongs in `catalog.gd`'s
`PROTECTED_ENUM_DOMAINS`, where recompiling it is refused. `Activity` and
`JobState` join `Speed`, `JobKind`, `ZoneType`, `Season`, `Quality` and
`Severity`.

## Why
The asymmetry was accidental, not reasoned. `JobKind` is protected; `Activity`
and `JobState` are numbered the same way in the same section and were not.
`needs.gd` set a competing precedent by mirroring `ResidentStatus` as local
constants.

Both approaches are spec-compliant, so this is a consistency call — but the
protected table is the better default, because it is the thing that **refuses**
a recompile. A local mirror is a second copy of a specified number with nothing
detecting drift, which is precisely the class of defect the drift guards added
in the last review exist to catch.

## Consequences
- New explicitly numbered enums go into `PROTECTED_ENUM_DOMAINS`, not into local
  constants.
- `needs.gd`'s local `STATUS_*` mirror of `ResidentStatus` is now the exception.
  It is **not** being changed as part of this — that module is finished and
  reviewed, and a gratuitous edit risks its 54 tests for no behavioural gain.
  Recorded here so the inconsistency is known rather than discovered again.
- Values still come from §4.3 and are never regenerated from sorted keys.

## Source
Specification audit, 2026-09-06, parsing §4.3 for task 2.11.
