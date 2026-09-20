# Review test follow-up R01

Independent review found no production correctness must-fix. Close its reference-loading condition by implementing the existing contract, without a waiver.

1. Load frozen layout-reference.json through res://../docs/validation/evidence/starter-integration-planning-2026-09-20/layout-reference.json, the established repository pattern in test_save_section_component_columns.gd lines141-153. Guard file existence, parsed dictionary, expected shape before indexing so missing/malformed references cause explicit test failure. Compare all31 literal FURNITURE_ORACLE entries (symbol->key,origin,room,footprint,candidates), all edges/door and exit interior against the loaded reference. Verify diagram/walk/reachable data agree with the independent oracle; keep explicit contract building/room/header values. Tests can convert JSON numeric values to ints; no production code changes. Update the suite header so it accurately says the reference is loaded and checked.
2. Add one two-output non-aliasing test using the same producer: prepare A and B, mutate an entry in each of A's ten arrays, verify all ten B arrays unchanged, then mutate B and verify all ten A arrays unchanged.
3. Replace the literal tautology about room ordinals with assertions reading actual plan fields for ordinals1..3.
4. Correct the wall-interior witness to adjacent interior global(64,66), instead of the exit tile itself(64,67); same expected EXIT_WALL code.
5. Add walk_tile_count header drift expecting WALK_DISCONNECTED. Retain all existing cases. Also retain explicit candidate value out-of-range coverage (-1 or2147483647) alongside coherent missing-neighbor coverage.

Return only a bounded unified diff against the current candidate test file; source and metadata harness remain unchanged. New helpers should be typed, documented and small under existing style rules. Preserve the successful lambda syntax pattern. Never claim local execution.
