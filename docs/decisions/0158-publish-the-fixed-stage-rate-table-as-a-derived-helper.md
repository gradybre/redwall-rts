# 0158 — Publish the fixed-stage rate table as a derived helper

Date: 2026-09-19 · Status: Implemented candidate; source review and final-source tests passed, merge pending

Independent review confirms the family hunger/daily-demand arithmetic and the
exact [FAMILY-RULES-R01](../planning/family_rules_api_contract.md) interface. Publish
two private flat18-value i64 tables,288 bytes total, with checked scalar readers.
The helper imports only IntMath, avoiding a future Needs/Residents preload cycle.
Errors belong to its diagnostic String domain; no new catalog enum is invented.

This prepares the fixed-stage coefficient consumer without enabling an incomplete
family world. Needs/Residents runtime behavior, current rules fingerprints and
save images remain unchanged. The family owner APIs, atomic admission/lifecycle,
Injury two-bit extension, relationship day accounting, profile qualification and
named scenarios retain their own acceptance gates. Do not call the helper's local
tests proof that those systems exist.
