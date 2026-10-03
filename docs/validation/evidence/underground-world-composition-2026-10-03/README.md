# Actual terrain and retained-space observation — decision1085

Date:2026-10-03. Branch:`codex/underground-world-composition`.

This component composes actual finite World terrain with retained sparse
physical state at the real6144-region/2048-source pack. It clips every extent,
subtracts exact retained matter with disjoint integer slabs, preserves claims
and unfinished areas, and cannot turn a preview into excavation, support,
traversal or services. Original substrate/exterior observation is explicitly
separate from fresh Building/resource exclusion checks before productive work.
The player-facing plan remains drawn directly on selected-level dirt.

The operation uses the actual shared Budget before the first snapshot. Its
logical simultaneous packed peak is975488 bytes, with157 reused/provider
logical bytes in the existing bindings reservation. These are source-derived
accounts, not measured native RAM or256-resident timing qualification.

## Independent review and corrections

The first frozen review inspected the provider, Terrain delta, tests, decision
and registry. It found two MEDIUM issues:

1. Terrain looked up World revision per tile. A valid restored source table can
   put World in its last row, multiplying tile work by source capacity. Pin the
   revision once across both survey passes, recheck it at the boundary, and
   charge both complete scans, fixed source lookups and both tile walks. The
   regression uses the real loader to place World at source row2047, then
   surveys512 tiles with at most ten World lookups.
2. A provider callback could expire/reacquire the Budget lease after entry.
   Recheck the exact original token after each allocating provider and final
   source validation before output publication. Six expiry/reacquisition cases
   prove that early expiry never enters output copying; all failures clear
   output. Reentrant calls leave the active outer caller’s output untouched.

Corrected final source pins are in `iteration-3/source-sha256.json`. The narrow
independent re-review accepted all four exact pins with no remaining high or
medium finding. The reviewer inspected the corrected source and regressions
without duplicating the engine run.
The wrapper prerequisite was independently reviewed separately: actual
`snapshot_revision_refusal` revalidates live source/claim truth without a
second copied snapshot; existing typed getter temporaries are not claimed
allocation-free.

## Final focused execution

Each iteration moves this worktree’s demo assets aside if present, deletes its
`.godot`, performs the clean headless editor import, runs exact singleton shards
through the unchanged strict `tools/run_tests.sh`, runs the zero-warning
analyzer, restores assets in `finally`, and proves the four source hashes did
not change during the run. Assets were absent. Exact commands, raw logs and
shard records are retained under each iteration.

```text
19 test(s), 373 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

17 test(s), 340 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

0 GDScript warning(s) in 0 of 4 file(s)
```

These are36 focused tests/713 assertions, not a new full-suite run. Coverage
includes integer slivers/concavity conservation, stacked levels and intervening
earth, unfinished/water/shell state, blocker/support non-excavation, exact floor
metadata, half-open neighbor boundaries, capacity/work ceilings, initial
admission, source/world expiry, geometry changes, callback lease loss, malformed
outputs and reentry.

All34 commands from the current `Specification contracts` CI job passed;
`contracts/invocations.json` and each raw log retain the commands, exit codes
and substantive validator output. Registry capacity self-tests report190
checks/0 failures; all13 joint allocation-pack tests pass. The source-derived
joint allocation remains99955154 bytes including reserves (44846 headroom),
with runtime qualification false. Regenerated sidecars update source locations
and hashes; no threshold or parser was relaxed.

## Earlier attempts and scope

Iteration1 correctly stopped before engine tests because the new module lacked
its required registry section. The logs contain no suite summary and are not
credited as executed tests. An auxiliary invocation initially used the wrong
registry-tool path under `tools/`; the real script lives under
`docs/validation/`, and the strict runner/full contracts above ran it correctly.
Iteration2 passed13 composition tests/241 assertions and17 Terrain tests/340
assertions with zero diagnostics/leaks and analyzer0/4; it predates review fixes.
Stale generated capacity/memory sidecars were rejected before regeneration;
the unchanged validators accepted their regenerated exact-source artifacts.

The full assembled checkpoint at00573c3e separately passed9748 tests/681366
assertions and analyzer0/1094 before these new increments. This component does
not claim the first playable Kitchen, final movement/profile/support/content,
save composition, native visual quality or whole256-resident performance.
