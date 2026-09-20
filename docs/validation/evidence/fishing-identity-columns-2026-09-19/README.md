# Full Expedition identity — FISH-ID-R01v2 / ADR0167

Base ccb3da6 (PR157). An older public ownership defect let a new Expedition at a
different Directory slot but the same generation inherit a stale claim on its
reused typed row. Fishing now stores and compares the complete slot/generation
pair. Exact capture/restore preserves that pair, and ordinary cleanup releases
stale effort exactly once; replacements cannot query, overwrite or release it.

Append one canonical int32[512] field at Fishing ordinal7. Fishing owner2,
section7 schema4 and registry6 reject ambiguous old development layouts. No
migration guesses the missing identity; Forage and other owner schemas stay fixed.
New runtime payload2048 bytes; Fishing wire block14947 bytes, section10440015.
Declaration correction223 bytes includes179 of prior ledger drift and44 new.
Current resident budget70005291; live+reserve78393899; headroom21606101. The
shared immutable declaration is excluded wholly from the candidate-world budget.
These are planned payload accounting, not measured peak RSS or full-game acceptance.

Subscription-backed Claude authored one bounded patch and independently reviewed
the integrated result. Astra normalized malformed patch coordinates using unique
exact old snippets, corrected owner refusal order, authored regression tests and
updated registry/budget metadata. Original patch, normalized patch, all input
hashes, terminal worker states and review dispositions are retained.

Pre-repair public regression failed as expected. Final focus258tests/7980assertions
passes; full suite before final two tests4806/189775/0, unchanged553objects/33resources.
All15 static gates and headless editor import pass. Four distinct mutants were
killed and exact source bytes restored. Final exact-head CI and merge pending.

This does not complete section7 assembly, cross-section reconciliation, full save
or a first playable settlement. Those remain explicit queued dependencies.
