# 0171 — Validate Priorities columns without constructing an owner

Date:2026-09-20
Status: accepted

Section4 owner11 needs a semantic predicate, while Priorities currently has no bulk Columns API. Its four packed byte columns have a complete local domain:512presence and two policy columns,6144job-priority bytes at stride12, values0..4, permanently zero reservedkind3, and allzero inactive rows. The owner has no health/status, so all512physical rows are valid independently of the cross-owner256living cap.

Adopt PRIORITIES-S4-VALIDATE-R01v1 in docs/planning/priorities_component_validation_contract.md. Add one static four-packed-argument predicate on Priorities, with exact ordered COLUMN_* refusals and distinct codes for the two policy flags. Reuse one static free-row definition in the existing inactive-row reader. A framed bridge validates owner/schema/metadata/shape before calling it through four explicit accessors. No live owner, default projection, duplicate buffer or schema change is needed.

The bridge pins contract keys/type/counts because the current owner publishes no metadata tables; independent schema generation still checks actual source declarations. The7680caller-image bytes are already inside the streaming allowance; no new packed allocation or resident row is added. Wrapper/native overhead is unmeasured.

Exact-code substitution and flag-swap mutants, reserved/free-order mutants, real-engine metadata faults, source review, full suite and exact-head CI are required. This does not add bulk capture/apply, rebuild present_count on restore, enforce cross-owner presence, or complete section4/full save-load.
