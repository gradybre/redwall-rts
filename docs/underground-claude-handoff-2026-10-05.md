# Underground implementation handoff for Claude — 2026-10-05

This is the handoff point for the underground modular-building work. The canonical review branch is `codex/underground-modular-integration`; the existing draft PR is [#230](https://github.com/gradybre/redwall-rts/pull/230). This commit keeps the last qualified runtime and records every unmerged lane, exact source pin, failed gate, and next owner in one place.

## Read these first

1. [`docs/design/underground-planning/implementation-status.md`](design/underground-planning/implementation-status.md) — the player-facing status and historical checkpoints.
2. [`docs/tasks/underground-build-queue.json`](tasks/underground-build-queue.json) — the authoritative 24-lane / 107-requirement dependency graph.
3. [`docs/decisions/1051-underground-modular-building.md`](decisions/1051-underground-modular-building.md) — approved scope and boundaries.
4. [`docs/validation/evidence/underground-entry-work-area-2026-10-05/README.md`](validation/evidence/underground-entry-work-area-2026-10-05/README.md) — the latest accepted source-bound work-area evidence.
5. [`docs/validation/evidence/underground-claude-handoff-2026-10-05/`](validation/evidence/underground-claude-handoff-2026-10-05/) — preserved WIP diffs and missing source files from the stopped lanes.

Run from the integration checkout:

```sh
python3 tools/underground_build_queue.py validate
python3 tools/underground_build_queue.py status
python3 tools/underground_build_queue.py ready
```

The queue validates with complete coverage, no cycles, and no active file conflicts. At this handoff the verified lanes are `UG01/02/03/04/05/06/18/19/22/23`; `UG07/08/20/21/24` are running; `UG09/10/11/12/13/14/15/16/17` are queued; `ready` is empty. A lane is not complete merely because its standalone module or source packet exists.

## What is actually qualified

The last green integrated runtime is `4972a96d` and is the baseline to preserve until the next integrated candidate passes all gates:

- Local clean-assets/cache/import/no-argument suite: **11,293 tests, 1,082,720 assertions, 0 failures**.
- Diagnostics: **0 unexpected errors, 0 unexpected warnings, 272 expected, 353 tolerated**.
- Leaks: **0 objects, 0 resources**.
- Analyzer: **0 warnings in 1,267 files**.
- Same-head CI: **14 jobs passed**, **413 test files exactly once**, **15m06s**; CI has 11,293 tests / 1,082,710 assertions. Exact local/CI assertion parity is not claimed because the ten-assertion difference is unattributed.
- Scene acceptance is 30 focused tests / 1,132 assertions, zero failures, zero diagnostics/leaks, analyzer 0/6, plus 74 native checks and five 1280×720 captures.

This proves the actual-world planning surface and source-bound component checks. It does **not** prove the first real worker-built empty Kitchen, paid timber handling, full furniture workflow, persistence, or 256-resident qualification.

## What was merged into this branch

The branch already contains the accepted root history through `40b02435` (including the accepted source/retirement reviews `c2e2a154` and `a296df11` in its ancestry), the source-publication contract, placement-owner retirement, and the original source-bound entry work-area evidence. No new PR was created for this handoff; pushing this branch updates PR #230.

The integration worktree had two unverified tracked edits that referenced missing source files. They were **not** promoted into the qualified runtime. Exact copies are retained under `validation/evidence/underground-claude-handoff-2026-10-05/unmerged-runtime-wip/` so no work is lost.

## Remaining lanes and exact files

### 1. Construction / paid handling (`UG07`, then `UG09`)

Worktree: `/Users/brendan/Developer/redwall-rts-codex-ug-paid-assembly-handling`  
Branch: `codex/underground-paid-assembly-handling`

Unmerged source ownership:

- `godot/scripts/core/underground_entry_contact_retirement_scope.gd` (untracked source snapshot; SHA-256 `c01af023181f029b45b0574b9e7bd74b6021dd44dcbfea8a79764c200fbff6f5`).
- `godot/test/test_underground_paid_assembly_handling.gd` (untracked source snapshot; SHA-256 `93c0f25aecf8af696d3b23475351259fdffb56bf5f2f214a948ac61d2ccd7dee`).
- Modified runtime owners: `modular_project_contract.gd`, `modular_projects.gd`, `underground_connector_work.gd`, `underground_connector_workpieces.gd`, `underground_routes.gd`, and their three tests.
- Decision draft: `docs/decisions/1183-paid-timber-handling-before-fastening.md` (status is **Implementation in progress**, not an accepted production decision).

The latest actual-source paid run is `paid-12`: **6 tests, 107 assertions, 1 failure**. Five adversarial/refusal tests pass, but the real L0 positive still stops after the four paid cuts at `LOCATION_ENVELOPE_BLOCKED`; it has 36,000 excavation mWU and no additional 32,000 fastening mWU or installed prefix. Therefore handling, fastening, completion, cancellation/refund, and worker dispatch are still open. Preserve the failure as a blocker; do not turn the synthetic passes into a positive claim.

### 2. Geometry / endpoint certificate (`UG08`, `UG21`, then `UG24`)

Worktree: `/Users/brendan/Developer/redwall-rts-codex-ug-timber-program-binding`  
Branch: `codex/underground-timber-program-binding`

Unmerged source ownership:

- `godot/data/underground/mole-worker/qualified-assembly-v1/endpoint_certificate.gd` (untracked source snapshot; SHA-256 `5540bb88b0ab92140b3b7ce44fdcad8c82ff8d9dd8523ca6fb2ce810a76c9cc5`).
- Modified source/test owners: `work-step-v1/source_program.gd`, `underground_connector_contacts.gd`, `underground_profiles.gd`, `underground_world_routes.gd`, and their tests.
- Decision draft: `docs/decisions/1178-paid-timber-program-binding.md` (status is **source authoring and live-binding implementation in progress**).

The focused `paired-16` source suites show `test_underground_profiles.gd`: **34 tests, 1,328 assertions, 0 failures**, and `test_underground_world_routes.gd`: **47 tests, 3,006 assertions, 0 failures**, with zero diagnostics/leaks in that focused receipt. This is component evidence only. Endpoint-3 was not integrated into the qualified branch, and there is no full integrated paid-start acceptance yet. The exact runtime patch and receipt are preserved under `validation/evidence/underground-claude-handoff-2026-10-05/source-snapshots/geometry/`.

### 3. Entry-owner composition / furnishing integration (`UG07`, `UG10`, `UG24`)

Worktree: `/Users/brendan/Developer/redwall-rts-codex-ug-entry-owner-composition`  
Branch: `codex/underground-entry-owner-composition`

Current uncommitted files are `underground_connector_assemblies.gd`, `underground_connector_delivery.gd`, `underground_connector_recipes.gd`, `underground_entry_bindings.gd`, `underground_world_retirement.gd`, and the modified decision `1184-original-session-entry-owner-composition.md`. The branch's earlier accepted placement retirement is already represented in the root history; the current full-prefix composition is not integrated. The current decision explicitly says source, lifetime, and actual composition verification remain pending. The exact patch and decision are preserved under `validation/evidence/underground-claude-handoff-2026-10-05/source-snapshots/furnishing/`.

### 4. Root-side contact-retirement WIP

The root integration worktree briefly contained changes to `godot/scripts/core/underground_locations.gd` and `godot/test/test_underground_locations.gd` that added the contact-retirement bracket and hostile-observer tests. Those edits referenced the two missing source files above and were intentionally kept out of the qualified branch. The exact hashes are:

- `underground_locations.gd`: `32064819ff3750c0e7a61bb8327b3eb325e07ae3ea98327c64e8b410f139d2bc`.
- `test_underground_locations.gd`: `1d956d825485cf868ac53550fe0e854f6ee324844f40f53c6449b380017cf27f`.

Use `unmerged-runtime-wip/locations-and-tests.diff` and the `retirement-location-draft-2` source copy to review or reapply them after Scope and Endpoint are accepted. Do not apply this patch alone.

## Required completion order

1. Freeze and independently review the concrete Scope and Endpoint sources with their full runtime consumers. Make the actual paid L0/T0 positive pass: four excavation cuts, handling entry/recovery, fastening, install/commit, worker release, cancellation/refund conservation, stale/reentrant refusals, zero diagnostics/leaks, and zero-warning analyzer.
2. Rebase the root contact-retirement patch onto those exact owners and run its hostile observer and capture/restore tests. Update `UG07/08/20/21/24` only from receipts, not assertions in draft prose.
3. Compose the real demo owner chain and worker dispatch. Deliver the adopted wood-only bill, use the existing settlement goods and actual workers, and finish the first blueprint → excavation → empty Kitchen path (`UG09`).
4. Add the room-purpose furniture grid/services and both player confirmation modes (`UG10`), then deeper levels/connectors (`UG11`) and safe amendments (`UG12`).
5. Complete removal/backfill/replacement, relocation, renovation, deterministic save/resume and all catalog/presentation regression work (`UG13–17`, `UG20/21`).
6. Re-run the exact strict procedure on the final integrated commit: move demo assets aside, delete `godot/.godot`, clean headless editor import, `./tools/run_tests.sh` with no arguments, diagnostics/leak comparison, all-file analyzer `--max 0`, 1280×720 input/render captures, and a measured 256-resident soak. Record local/CI test counts and assertion differences explicitly.

## Do not infer completion from

- A parser-only Scope or Endpoint receipt.
- A source-only/native motion certificate.
- A focused suite that does not include the actual paid positive.
- The old `4972a96d` full-suite receipt after changing source files.
- A queue lane marked `running` or a standalone module without demo integration.
- The generated `.import`, `.godot`, or `__pycache__` files present in the stopped worktrees. They are build artifacts, not source deliverables.

The three implementation agents reached their usage limit while holding the WIP above. Their changes are preserved in the sibling worktrees and this handoff evidence; the next Claude pass should continue from the exact source pins instead of recreating the work.
