# 1192 — Single committed branch for underground integration

Date: 2026-10-05 · Status: Accepted

## Context

By the 2026-10-05 handoff, underground work was split across three sibling
worktrees, each on a different base (`c2e2a154`, `db03b1f7`, `a9e45dba`), and
the integration checkout (`40b02435`). Most "accepted" focused receipts were
produced by Python overlay scripts. Those scripts copied uncommitted files from
*other* worktrees by absolute path into a checkout, ran one suite, and restored
the originals. The resulting evidence could not be rebuilt from git:

- `test_underground_entry_work_area.gd`, cited by the accepted work-area
  evidence, was never committed.
- Geometry had three different versions of `underground_world_routes.gd` in
  play (`diagnostic-source-7`, `diagnostic-endpoints-2` and the worktree head).
  Different receipts used different versions.
- When the three lanes were applied together they produced 266 tests and
  153 failures. Each lane was green only against its own private overlay set.

## Decision

1. Underground work continues on **one branch**, starting at
   `claude/ug-paid-start` and later merged into
   `codex/underground-modular-integration`. Each layer of WIP is committed
   before it is tested. Every test result names a commit.
2. **No overlay runners.** A test reads only files tracked at the commit under
   test. A test that reads evidence data (for example the paid fixture's
   `diagnostic-content-1` images) must have that data committed.
3. Focused runs use `./tools/run_tests.sh --suite NAME.gd [...]`. This applies
   the same zero-diagnostic and zero-leak guards as the full run, so no
   bespoke wrapper is needed. A focused pass is never reported as a full-suite
   result.
4. A layer is integrated in this order: commit it, run the focused suites it
   touches, then run the full suite. Failures are fixed on the branch or
   recorded with the commit hash. They are not hidden by rejecting the
   combination.
5. Lane "ownership" of files (ADR 1191 §Ownership) no longer forbids editing.
   It records who designed a contract. One integrator may change any file, and
   review happens on the combined diff.
6. The sibling `codex/underground-*` worktrees are frozen as source material.
   Their WIP is imported by content, with the source worktree and SHA-256
   noted in the commit message.
7. **Source pins are renewed mechanically.** The active profile publication
   (`qualified-step-v4/catalog_source.gd`) pins the SHA-256 of ten runtime
   consumer scripts. At `0c141eb3`, 158 of the 165 full-suite failures were
   `MOLE_CATALOG_SOURCE_DRIFT` cascades caused by five edited consumers. The
   pin catches unreviewed drift, but it was never meant to make every
   ordinary edit fail the suite. Any commit that edits a consumer runs
   `python3 tools/renew_source_pins.py --write`, which renews only the
   current consumer digests and appends a `renewals` record to the manifest.
   It leaves `prerequisite_pins`, the wire and the actor alone.
   `run_tests.sh` runs `--check` before Godot starts. Review of the change
   happens on the commit diff, not through a separate publication ceremony.

## Consequences

- Historical overlay receipts stay as history, but they do not qualify any
  commit.
- Queue lane status (`docs/tasks/underground-build-queue.json`) changes only
  when a full-suite run on a named commit supports it.
