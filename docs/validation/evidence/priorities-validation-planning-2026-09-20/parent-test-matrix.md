# Parent acceptance matrix for owner11

Planning only; no executed result.

Base fixture: correctly-sized zero columns, with row0 present1 and one active-kind priority2. This separates omission of presence from a valid all-zero empty image.

| Fault | Expected code | Correctly-sized zero substitution outcome |
|---|---|---|
| present[0]=2 | COLUMN_PRESENT_BYTE | COLUMN_FREE_ROW because row0 retains priority2 |
| job_priority[1]=5 | COLUMN_PRIORITY_RANGE | accepted |
| auto_fallback[0]=2 | COLUMN_AUTO_FALLBACK_BYTE | accepted |
| dangerous_work[0]=2 | COLUMN_DANGEROUS_WORK_BYTE | accepted |

Swapping the auto/dangerous arguments changes the auto2 witness from COLUMN_AUTO_FALLBACK_BYTE to COLUMN_DANGEROUS_WORK_BYTE. Neither refusal-only assertions nor a parser failure counts as a mapping kill.

Reserved byte7 is a range error; reserved byte3 on an inactive row is a reserved-column error; inactive auto1 is a free-row error. A fixture containing reserved residue and another free-row policy residue pins reserved-before-free even when the faults are on different rows. Priority5 on any of6144physical bytes must be found, independent of row presence. All values0..4 remain valid on active kinds. Reserve kind3 stays0 for every physical row.

Exercise512present rows; the owner stores policy, not health or living status. Exercise actual public spawn/set_priority/set_auto_fallback/set_dangerous_work/despawn outputs through reader-built images. Compare the existing inactive_row_is_clear reader across invalid addresses, present rows and released rows after its helper refactor. Cover allzero frame, short/long/empty columns, missing/extra u8 bucket, unexpected i32/i64 buckets, null frame and wrongowner. Check each original packed array before/after accepted and refused calls.

Metadata tests must fail the actual engine path, keep prerequisite schema_refusal empty where testing owner metadata, and exclude parse/script errors from kills. Use independent generator/source-capacity checks in addition to pinned bridge literals. Current owner lacks publication tables; do not invent such an assertion. Test schema refusal detail forwarding exactly.
