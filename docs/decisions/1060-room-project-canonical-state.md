# 1060 — Room project revision state belongs in the canonical declaration
Date: 2026-10-02 · Status: Accepted

## Decision

Register the eleven persistent packed columns of `RoomProjects` under section 6,
owner `room_projects`, schema 1. Preserve every existing owner, field, type and
ordering. Advance section 6 to schema 2 and the registry to version 8,
`RWL-CANONICAL-REGISTRY-2026-10-02-UG1`, then regenerate the compiled declaration
and capacity audit sidecar.

The new totals are 53 owners, 615 hashed records, 623 declared fields (including
8 existing exclusions) and 566 packed source fields. Seven new columns have
`PROJECT_CAPACITY = 82944`; four have `JOB_CAPACITY = 8192`. The eleven capacity
equalities are proved against source. New C175–177 contracts describe project
identity, permanent room type, independent pause reasons, revision epochs and
full generation-checked job-to-project identities.

## Why

The PR #230 specification gate exposed eleven source fields classified as
persistent state but absent from the canonical registry. The earlier Godot suite
and packed-column coverage check did not establish canonical membership.
Reclassifying these fields as unresolved would hide a real persistence
obligation: forgetting an editing hold or its epoch can resume unsafe work or
allow a stale Apply/Discard token to act on a replacement project.

## Consequences

The independent field/type/order tests and validator totals grow by exactly the
new state. Strict source membership, capacity proofs, generated-file checks,
zero-warning analysis and diagnostic/leak gates retain their existing behavior.
Historical census data remain unchanged; the capacity audit explains the exact
new delta instead of rewriting the old measurement.

This is a declaration fix, not a save adapter. `release_save_ready` remains
false. UG16 must compose and validate these columns in the real demo save path,
preserve independent pause reasons and safely reconstruct revision tokens.
Unresolved `RoomLayout` state remains explicitly unresolved until its own
persistence work is implemented. No serialization or gameplay permission is
inferred from this declaration.

## Validation

After a clean editor import, the strict focused runner reported:

- `52 test(s), 3678 assertion(s), 0 failure(s)` for canonical state hashing.
- `20 test(s), 301 assertion(s), 0 failure(s)` for room projects.
- Both: `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected,
  0 tolerated; leaked at exit: 0 object(s), 0 resource(s)`.
- Both raw logs: `0 unexpected error(s), 0 unexpected warning(s); leaked at exit:
  0 object(s), 0 resource(s)`.
- Analyzer: `0 GDScript warning(s) in 0 of 2 file(s)`.
- Canonical validator: 31 independent framing fixtures, 566 source fields,
  53 owners and 615 canonical records pass.
- Capacity audit: `190 check(s), 0 failure(s)`; packed-column coverage:
  `96 modules, 449 rows, 771 packed columns checked`.

A separate agent reviewed the old/new registry, live source columns, generated
table, null contracts and capacity proofs before commit; no blocking findings.
This focused evidence does not claim completion of UG16 or the whole building
workflow. Full integration checkpoints record their exact source separately.

## Source

AGENTS.md integer/SoA/EntityRef requirements; decision 1053; the persistent-state
classification in `docs/state_registry.md`; `.github/workflows/tests.yml`
source-to-canonical gate; the user's approved project revision/save behavior.
