# Review follow-up — S1/S2/S3 disposition and the revised metadata fault harness

Date: 2026-09-20. Scope: the disposition's changes only. Production was re-read and is unchanged;
the settled source review is not reopened, and no gameplay or future semantics are proposed.
I ran nothing. The 19-case result file is treated as parent-supplied evidence.

## Verdict

**No blocker.** One medium operational finding, the rest low. S1, S2 and S3 are answered by
reachable engine assertions rather than by text.

## Confirmed by reading the changed artefacts

- **Assertion count is fail-closed.** `suite()` emits exactly nine assertions and `execute()`
  pins `^1 test\(s\), 9 assertion\(s\), (\d+) failure\(s\)$`. An added or dropped assertion
  breaks every case loudly instead of silently shrinking coverage. `SCRIPT ERROR:` and
  `Parse Error:` are excluded before a kill counts, so no mutant is killed by a parse failure.
- **S1 answered.** Every case asserts both `Bridge.METADATA_DETAIL_PREFIX ==
  "Needs owner9 metadata:"` and the `begins_with` outcome in the correct direction: true for the
  four owner faults and the three publication faults, false for the positive control and for the
  schema-gate case. Rewidening the prefix now fails in-engine.
- **S2 answered, and the four bypasses are discriminating.** Each schema fault perturbs one
  identity only, so bypassing one comparison in a compound `or` leaves the other clause false and
  gate 4 genuinely accepts; the kill is the changed refusal code, not incidental. I re-derived the
  balances: primary 8:511/9:513 keeps the 193184-row total; the child move adds 8 bytes to owner 9
  and removes 8 from owner 10, so `OWNER_OFFSETS[10] = 9336936`, later offsets and `SECTION_BYTES`
  stay valid, and `CHILD_EXTENTS[4]` is positive. Each case asserts `Schema.schema_refusal().code`
  is empty first, so gate 4 is proven separate from gate 3.
- **S3 answered without identity.** The schema-gate case asserts `refusal.detail ==
  Schema.schema_refusal().detail` across two independent calls — forwarding, not object identity.
- **Clone isolation and restore order.** One `copytree`; `docs`/`assets` are read-only symlinks;
  the probe and focus runner are written inside the clone. `needs.gd` is restored after the
  publication loop, the bridge after each bypass, and the final schema mutation derives from
  `originals`, not from the faulted clone text. The `finally` block re-checks all three product
  files byte-for-byte.
- **CI wiring.** The step sits in the `godot` job after `run_tests.sh`, runs on pull_request and
  push, and carries no `continue-on-error`. Placement outside `contracts` is correct: it needs an
  engine.
- **Evidence cross-check.** `metadata-preflights-review.json` reports 19 cases, 171 assertions,
  4 `killed_bypass`, 15 passed, matching the disposition. Its recorded sha256 for
  `save_owner_needs.gd` and the schema equal the inputs supplied here.

## Findings

**F1 — medium, operational. No wall-clock headroom is pinned for 19 engine launches.**
Each case starts headless Godot with a 90 s per-case timeout inside a job capped at
`timeout-minutes: 30` that already pays download, editor import, the full suite and a second
fault-injection tool. The worst case exceeds the job cap. Bounded fix, parent-owned and
CI-only: raise `timeout-minutes`, or record an observed total for this step once CI runs.

**F2 — low. `needs.gd` assumptions are unverifiable from this packet.** `publication_fault`
depends on typed `Array[...]` declarations, exactly twenty tokens, and the identifiers
`RESIDENT_CAPACITY` and `COLUMN_TYPE_I32`. The file was not supplied here; its sha256 appears
only inside the result JSON. Its `assert len(tokens) == 20` fails closed if any of that drifts.

**F3 — low. A failing integrity assert in `finally` would mask the original exception.** Cosmetic;
both paths still fail the step.

## Not reopened

Production source, gate order, projection purity, memory arithmetic, S4/S5/S6, the absence of a
normal-suite gate-4 case that cannot mutate compiled constants, and all deferred Needs semantics.
Full-suite and exact-head CI evidence remain outstanding.
