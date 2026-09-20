# 0170 — Needs restores reject health/status contradictions

Date: 2026-09-20
Status: accepted

The GDD requires DEAD at zero health. A public restore/tick probe accepted a zero-health ACTIVE row and left living_count at1 after the tick marked it DEAD. Validation must reject the inconsistent image before publishing it.

Adopt NEEDS-S4-VALIDATE-R01 v2 in docs/planning/needs_component_validation_contract.md. Extract one static, argument-only Needs.columns_refusal shared by live restore and a new owner9 framed bridge. Require present rows to satisfy (health ==0)==(status ==DEAD), after free-row validation and before living-cap validation. Preserve all other existing admitted column domains, including nonnegative departure counters and inactive environmental residue. Null columns refuse safely through the shared shape predicate.

The bridge checks compiled metadata and physical shape before explicitly projecting all20 packed fields without constructing a live owner. It returns the exact column refusal and retains no projection. Conditional transient logical arithmetic is135168bytes; no measured RSS or full-world validity claim follows.

Separate source-backed contracts still owe nonfatal status precedence and departure production/domain semantics, all other owners and cross-owner saved consistency. No speculative tick compensation, new departure gameplay, schema change or range-scan optimization is included. Parent-owned exact-code tests and actual mapping/death-rule mutants precede independent source review and exact-head CI acceptance.
