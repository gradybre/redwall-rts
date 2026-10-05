# 1185 — Complete current contract checks before the timeout

Date: 2026-10-05

Status: implemented; remote execution of the corrected workflow is pending.

## Evidence and decision

The specification-contract job at integration commit `8f6bad86` in GitHub
Actions run `37275141498` was cancelled by its five-minute job timeout. Checkout
took twelve seconds. The complete current-source underground memory pack and
its negative tests passed, taking four minutes and thirty-two seconds. The
registry-capacity check had begun when the timeout cancelled the job; subsequent
contracts were skipped. This is incomplete validation, not a passing run.

Increase only this job's hang guard to fifteen minutes. Keep all steps, their
order, commands, arguments, exit handling and validation thresholds unchanged.
Do not cache successful checks, omit negative tests, tolerate diagnostics, or
accept a cancelled job. The existing eight Godot shards, all-file zero-warning
analyzer, zero-unexpected-diagnostics and zero-leak gates are unchanged. The
no-argument local test runner is unchanged.

The earlier workflow comment promising completion in under a minute predates
the expanded allocation and source-closure checks; replace that stale claim.
Actual remote duration still needs measuring. A fifteen-minute timeout is an
upper bound, not proof of a fifteen-minute wall-clock target.

## Validation

Retain the failed job's step timings and an exact before/after comparison under
`docs/validation/evidence/underground-contract-timeout-2026-10-05/`. The comparison
must prove that removing comments and replacing this single timeout scalar
reconstructs the old workflow exactly. No new engine run is required for this
workflow-only correction; the frozen full integration run continues separately.
