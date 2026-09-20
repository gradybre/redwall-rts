# Astra disposition of the reserved-fauna feasibility review

The source-backed shape, fixed defaults, constructor cost and shared-reader approach are accepted. The nine columns are eight i32 columns (zone slot plus seven zero-default columns, including zone generation) and one zero-default i64 column. There are 384 rows and 15,360 logical packed bytes. No active hunting data or migration is introduced.

Two inspection items are now resolved. The installed Godot engine's `PackedInt64Array.count` passed an actual probe with 384 zeros, a value above exact floating-point integer precision, and both signed extrema. The proposed preload closure has 26 nodes and no cycle involving the new bridge. It includes existing self-preloads in IntMath and SaveCodec, both already compiled by the passing suite. An initial assertion that the entire closure must be acyclic was too strict; the final evidence records the existing cycles. Import of the actual bridge is still required.

Clarifications to the review:

- `_allocate_fauna_columns` is the only writer; public readers do also name the columns. The literal claim that no other function names them is incorrect.
- Seven i32 columns besides zone slot are zero, plus the one i64 column. There are eight zero-default arguments in total, not eight additional i32 columns.
- Reusing or swapping two zero-default arguments can be semantically equivalent for this validator. Do not claim every duplicated argument is detectable. Each required zero-substitution mutant uses a fixture with a nonzero value only in the omitted field. Zone-slot substitution is caught by the valid-empty control.
- A wrong owner index fails at bridge gate 2, not metadata gate 4. Metadata counterfactuals retain owner index 17 and preserve a valid schema and physical frame.
- Separate error codes would be an ordinary diagnostic choice, not a forbidden authority change. A single reserved-data code is sufficient here and will be used.

Use a static nine-argument predicate with complete shape checks, then exact whole-column constant checks. The existing boolean reader delegates to it without changing its public behavior or section 1 diagnostics. No snapshot API is invented. Public empty/ref/capacity readers and existing before/after generation tests provide actual-owner evidence; copied fixture values remain independently pinned to the required constants.

The combined section 1/4 restore transaction, other WorldInit state and full-file publication remain the existing owner-binding task's responsibility. This primitive does not regenerate or repair the world.
