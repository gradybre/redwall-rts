# Parent-owned reserved-fauna test matrix

Aligned with accepted FAUNA-S4-VALIDATE-R01v1. No implementation or test-run claim.

Independent fixture: nine packed columns, each 384 elements. Ordinals 0–7 are i32, ordinal 8 is i64. Fill only zone slot (0) with -1; all remaining values are zero. No live private columns are read and no fixture is represented as a captured WorldInit snapshot.

| Required mutation | Witness | Expected intact result | Result after mutation |
|---|---|---|---|
| Zero-substitute zone slot | Valid empty fixture | success | COLUMN_FAUNA_RESERVED |
| Zero-substitute each other argument (8) | Exactly one nonzero value in that field | COLUMN_FAUNA_RESERVED | success |
| Omit each per-column default check (9) | Slot 0 becomes 0 for field 0; one value becomes 1 for every other field | COLUMN_FAUNA_RESERVED | success |
| Ignore birth-remainder extent | 383 zero i64 values with all other fields valid | COLUMN_FAUNA_SHAPE | COLUMN_FAUNA_RESERVED |

This yields 19 required mutants. Equivalent swaps between zero-default columns are not claimed caught. Canonical accessor mapping remains independently source-reviewed.

Every one of 384 rows in each field receives a single invalid value, then returns to its exact default. Static checks cover all 3,456 positions; bridge checks additionally cover first and last rows for every argument. All nine empty, short and long extents must fail before a value fault in another column. Add wrong owner, null record, missing/extra typed buckets and unexpected byte columns.

Values include signed i32 extrema, signed i64 extrema expressed without overflowing the parser, and ±9007199254740993. Accepted and refused static/bridge calls preserve every packed input. Raw zero frames refuse; the correctly filled empty frame accepts. Details contain the owner identity and raw code, never a row.

An actual WorldInit instance with null collaborators suffices for allocation-only public readers and section 1 local diagnostics; generation is not called on that fixture. Cross-check all 384 public zone refs, exact byte/capacity readers, negative/high address behavior and fauna emptiness. Deliberately establish a section 1 local validation refusal, then ensure static/bridge validation leaves its code/detail, publication flag and published seed unchanged. The existing `test_world_init.gd` test separately verifies canonical fauna emptiness before and after real generation in the full suite. Do not duplicate its entire collaborator fixture or invent a new private snapshot API.

Focused mutation runs cover the new owner/bridge tests. The complete suite includes the existing WorldInit generation tests, section 1 tests and dependency closure. Source review checks that only the shared empty-reader body, new constants and new static predicate alter WorldInit.
