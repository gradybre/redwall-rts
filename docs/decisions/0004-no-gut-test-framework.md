# 0004 — Tests use an in-repo framework, not GUT
Date: 2026-09-05 · Status: Accepted

## Decision
`godot/test/framework/test_case.gd` plus `godot/test/run_tests.gd`, rather than
vendoring GUT.

## Why
`CLAUDE.md` originally called for GUT, but adopting it means committing a
third-party addon into the repository. The task's acceptance criterion was a
headless run via `godot --headless --script test/run_tests.gd`, which a
dependency-free runner satisfies directly. Suite layout still matches GUT's
`test_<module>.gd` convention, so switching later is mechanical.

## Consequences
- Suites live in `godot/test/` as `test_<module>.gd` and extend the framework by
  **path**, not `class_name` — the global class cache is editor-generated and
  absent on a fresh clone, so path-based `extends` is the only reliable form.
- The runner **must** fail on a suite that will not parse. It once reported
  success while a broken suite silently contributed zero tests; it now checks
  `can_instantiate()` and counts a load failure as a failure. Verified by fault
  injection.

## Source
Task 01 acceptance criteria; verified 2026-09-05.
