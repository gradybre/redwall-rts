# Original full checkpoint — failed, preserved

Exact commit `9dad696ddb6485e9a8c4b8efd8c8dcee52c9c4c0` completed the unchanged
no-argument `./tools/run_tests.sh` procedure with **11,207 tests, 1,027,804
assertions and two failures**. All 405 discovered singleton suites ran exactly
once. This is a failed full checkpoint, not a passing qualification.

Both failures are stale expectations in
`test_underground_room_frontier_publication.gd`:

- `test_actual_paid_first_cube_preserves_full_geometry_refusal_and_every_live_owner`
- `test_actual_paid_first_cube_adds_lateral_corridor_contact_without_movement_or_free_work`

They expected `MOLE_CATALOG_SOURCE_DRIFT` after the reviewed profile renewal,
but the actual source check returned an empty refusal. The first test still
reached its separate physical `LOCATION_COVERAGE_MISSING` refusal; the second
performed its lateral publication. The test-only correction was independently
reviewed in evidence commit `038471a735aeeaa1ce84c3addb9a33252537d533`.
It was **not** applied to this frozen run.

Unexpected errors, unexpected warnings and object/resource leaks were all zero.
The runner recorded 272 expected and 353 tolerated diagnostics. An independent
raw scan found zero `SCRIPT ERROR`, `ERROR`, `WARNING`, parser or leak lines,
and exactly matched the expected/tolerated counts. The strict parser refused
the two-failure result. The shell exited before its success-only log tally,
and the unchanged full procedure consequently did not attempt its analyzer.
The separate focused same-head run passed 169 tests / 18,457 assertions and
the zero-warning analyzer on 29 owning files; that result does not replace the
missing full analyzer step here.

Clean import took 12.060 seconds with zero raw diagnostics. The full suite took
1,911.074 seconds. The registry gate passed at 153 modules, 730 rows and 1,055
packed columns. All 10,546 tracked source pins were independently rehashed
after cleanup and matched. Original project, assets, sidecars and HEAD were
unchanged/restored. No source, registry or fingerprint overlay was used.
The isolated user directory was `Redwall-ug-room-integration-full-20261005`;
port 6465 and all procedure processes were released after collection.

`invocation.json` retains commands, timings and cleanup results;
`rejected-summary.json` retains independent counts, suite coverage and the
strict-parser refusal. The original logs and complete source manifest remain
beside them. The raw `FRONTIER-LATERAL-PUBLICATION ` line retains its emitted
trailing space; the single `git diff --check` finding is not normalized out of
the captured log. `executed-procedure.py.txt` preserves the evidence-only wrapper
exactly as executed, SHA-256
`c09d40ec7e464c331cc28cd80297fa33a6d0f3ddb8f3baba6cacccf295a9c1d8`.

Reproduce in a fresh worktree at the exact checkpoint, with no concurrent
engine use in that worktree:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B \
  docs/validation/evidence/underground-room-integration-check-2026-10-05/reproduce_full_renewal.py \
  --expected-commit 9dad696ddb6485e9a8c4b8efd8c8dcee52c9c4c0 \
  --out docs/validation/evidence/underground-room-integration-check-2026-10-05/full-replay
```

The evidence wrapper must be supplied from this evidence commit when replaying
the older source checkpoint. Do not move the source checkpoint merely to make
the expected-commit guard pass. This run includes neither the subsequent
frontier expectation correction nor the separately reviewed 1167 route-owner
composition. Whole-room progression, playable Kitchen and native-memory
acceptance remain outside this evidence.
