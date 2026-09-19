# 0157 — Persist planner dirty order and membership

Date: 2026-09-19 · Status: Implemented candidate; independently reviewed and locally validated, merge pending

The save registry excludes job_planner's dirty work lists as derived accelerators.
A runtime counterexample shows identical declared canonical columns producing
job IDs [4,3], [3,4] or [3,0] at the same next tick when only dirty order/membership
changes. LIFO order and stagger timing make those lists authoritative.

[SAVE-J2-R01](../planning/planner_dirty_state_contract.md) retains the
three existing list prefixes and counts, canonicalizing unused tails to zero,
and rebuilding only membership bits. Section8 and the planner owner advance to
schema2 with35fields and384203bytes. No permanent array is added, and normal
planner order is preserved. The separate owner bulk API and cross-reference
restore contract remain prerequisites of full save continuation.
