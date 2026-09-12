# 0089 — Restore, layout and movement follow-up

Date:2026-09-12. Status: Accepted engineering rulings; implementation/evidence
and explicitly gated profile/content work remain incomplete.

## Context and decision

The executor identified four omitted contracts and two smaller ambiguities.
Adopt [the six-answer handoff](../rulings/2026-09-12_executor_followup.md) and its
RESTORE-R01, SAVE-LAYOUT-R01, PATH-R02, MOVE-DEP-R01–05, ALERT-R02 and
STOCK-SEED-R01 definitions. Owning GDD/architecture/balance/UI/task documents
are amended, preserving historical findings in decisions0053/0083.

## Consequences

Restore must not replay operational pause behavior. Packed saves explicitly
choose column-major with fixed-record exceptions and correct unused sentinels.
Exact-start routes trade cross-start cache reuse for optimal flat paths under the
unchanged expansion/storage caps; latency remains measured, never presumed.
Fixed life-stage identity and actual contact identity need budgeted packed fields;
logical rig IDs do not grant render availability authority over simulation.
STANDARD/WIDE full alert content is preferred when it fits. Seed expiry gains an
explicit floor-based yield with deliberate decay remainder and atomic ledgers.

No runtime edits, commits, pushes, paid generation or claimed hardware qualification
are part of this planning change. Full movement/family/content contracts retain
their explicit open gates. See the linked validation for what was actually checked.
