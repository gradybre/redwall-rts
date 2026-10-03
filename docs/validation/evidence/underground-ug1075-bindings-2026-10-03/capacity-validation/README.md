# Actual-capacity SpaceOwner validation

The exact decision1072 R=6,144/O=2,048 pack now performs bounded actual work
without changing RoomSpace.MAX_CHECKS=1,048,576, packed memory or wire schema.
Two temporary numeric counters add 16 logical control bytes in the bindings reserve.

The validation invocation moved this isolated worktree's demo assets aside,
deleted its `.godot` cache, ran `godot --headless --path godot --editor --quit`,
then invoked the unchanged strict `./tools/run_tests.sh` with the suite's
singleton shard from the complete discovered manifest. Assets were restored
in a finally block. These focused tests do not replace root's full checkpoint.

Final results:

- SpaceOwner: 57 tests, 2,976 assertions, 0 failures.
- Unchanged paid Authority: 24 tests, 3,010 assertions, 0 failures.
- Both strict and raw log footers: 0 unexpected errors/warnings, 0 object/resource leaks.
- Expected/tolerated diagnostics: 0 in both suites.
- Analyzer: `0 GDScript warning(s) in 0 of 2 file(s)` using port 6153 and `--max 0`.

The raw Owner log contains all measured logical check counts: minimal seal 26,632;
minimal restore 40,966; 256 actual living Residents in one batch 655,905; their
restore 112,545; single edit in that populated image 32,934. These are logical
operation checks, not native/frame measurements. Resident IDs and Transforms
are real; containment and body bounds are explicitly synthetic test inputs.
No native source profile or traversal permission is claimed.

Regressions cover failed-seal edit/retry, all borrowed indexes rebuilt, source
and region reuse, corrupt saved revisions refusing without normalization,
callback mutation exclusion and genuine 1,024-static-region pair-work exhaustion.
The latter creates no extra residents. Exact source hashes are in the sidecar.
Independent read-only source review accepted the exact pinned source/test delta
against 71c8741d with no high or medium findings. The reviewer inspected index
locking/reconstruction, sorted full-identity joins, revision propagation/load
refusal and genuine budget exhaustion; no duplicate engine run was performed.
